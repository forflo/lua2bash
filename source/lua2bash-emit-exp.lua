local util = require("lua2bash-util")
local scope = require("lua2bash-scope")
local datatypes = require("lua2bash-datatypes")
local serializer = require("lua2bash-serialize-ast")

function emitId(indent, ast, config, stack, lines)
    if ast.tag ~= "Id" then
        print("emitId(): not a Id node")
        os.exit(1)
    end
    local varname = ast[1]
    local binding = scope.getMostCurrentBinding(config, stack, varname)
    local emitVn = binding.symbol:getEmitVarname()
    if binding == nil then
        return "VAR_NIL" -- TODO
    end
    return { emitTempVal(indent, config, lines,
                         derefVarToType(emitVn),
                         derefVarToValue(emitVn)) }
end

function emitNumber(indent, ast, config, stack, lines)
    local value = tostring(ast[1])
    if ast.tag ~= "Number" then
        print("emitNumber(): not a Number node")
        os.exit(1)
    end
    return { emitTempVal(indent, config, lines,
                         b.c("NUM"), b.c(value)) }
end

function emitNil(indent, ast, config, stack, lines)
    if ast.tag ~= "Nil" then
        print("emitNil(): not a Nil node")
        os.exit(1)
    end
    return { emitTempVal(indent, config, lines, b.c("NIL"), b.c("")) }
end

function getEnvVar(config, stack)
    return b.pE(config.environmentPrefix .. stack:top():getEnvironmentId())
end

function getTempValname(config, stack, simple)
    local commonSuffix
    if not simple then
        commonSuffix = b.c(getEnvVar(config, stack)) ..
            b.c("_") ..
            b.c(tostring(util.getUniqueId()))
    else
        commonSuffix = b.c("_") .. b.c(util.getUniqueId())
    end
--    dbg()
    return b.c(config.tempValPrefix) .. commonSuffix
end

function derefVarToValue(varname)
    return b.pE(b.c("!") .. b.c(varname))
end

function derefVarToType(varname)
    return b.pE(b.pE(varname) .. b.c("[1]"))
end

function derefValToEnv(valuename)
    return b.pE(valuename .. b.c("[2]"))
end

function derefValToValue(valuename)
    return b.pE(valuename)
end

function derefValToType(valname)
    return b.pE(valname .. b.c("[1]"))
end

-- typ and content must be values from bash EDSL
function emitTempVal(indent, config, lines, typ, content, simple)
    local tempVal = getTempValname(env, simple)
    local cmdLine = b.e(tempVal .. b.c("=") .. b.p(content .. b.c(" ") .. typ))
    util.addLine(indent, lines, cmdLine())
    return tempVal
end

function emitString(indent, ast, config, stack, lines)
    if ast.tag ~= "String" then
        print("emitString(): not a string node")
        os.exit(1)
    end
    return { emitTempVal(indent, config, lines,
                         b.c("STR"), b.c(ast[1]), false) }
end

function emitFalse(indent, ast, config, stack, lines)
    if ast.tag ~= "False" then
        print("emitFalse(): not a False node!")
        os.exit(1)
    end
    return { emitTempVal(indent, config, lines,
                         b.c("FLS"), b.c("0"), false) }
end

function emitTrue(indent, ast, config, stack, lines)
    if ast.tag ~= "True" then
        print("emitTrue(): not a True node!")
        os.exit(1)
    end
    return { emitTempVal(indent, config, lines,
                         b.c("TRU"), b.c("1"), false) }
end

function emitTableValue(indent, config, stack, lines, tblIdx, value, typ)
    local typeString = b.c("TBL")
    local envVar = getEnvVar(config, stack)
    local valueName = b.c(config.tablePrefix) .. envVar .. tblIdx
    local cmdline = b.e(
        valueName .. b.c("=")
            .. b.p((value or valueName)
                    .. b.c(" ") ..
                    (typ or typeString)))
    util.addLine(indent, lines, cmdline())
    return valueName
end

-- prefixes each table member with env.tablePrefix
function emitTable(indent, ast, config, stack, lines, firstCall)
    if ast.tag ~= "Table" then
        print("emitTable(): not a Table!")
        os.exit(1)
    end
    if firstCall == nil then
        addLine(indent, lines, "# " .. serTbl(ast))
    end
    local tableId = util.getUniqueId(env)
    local tempValues
    emitTableValue(indent, config, stack, lines, tableId)
    for k, v in ipairs(ast) do
        local fieldExp = ast[k]
        if (v.tag == "Pair") then
            print("Associative tables not yet supported")
            os.exit(1)
        elseif v.tag ~= "Table" then
            tempValues = emitExpression(indent, fieldExp, config, stack, lines)
            imap(
                tempValues,
                function(v)
                    emitTableValue(indent, config, stack,
                                   lines, tableId .. k,
                                   derefValToValue(v),
                                   derefValToType(v)) end)
        else
            -- tempValues possibly is a list of tempValue
            tempValues = emitTable(indent, ast[k], config,
                                   stack, lines, false)
            imap(
                tempValues,
                function(v)
                    emitTableValue(indent, config, stack,
                                   lines, tableId .. k,
                                   derefValToValue(v),
                                   derefValToType(v)) end)
        end
    end
    return { b.c(env.tablePrefix) .. getEnvVar(config, stack)
                 .. b.c(tostring(tableId))}
end

-- TODO: argValueList!
-- returns a tempvalue of the result
function emitCallClosure(indent, config, lines, closureValue, argValueList)
    local cmdLine = b.e(derefValToValue(closureValue) .. b.c(" ")
                            .. derefValToType(closureValue))
    util.addLine(indent, lines, cmdLine())
end

-- TODO: return und argumente
function emitCall(indent, ast, config, stack, lines)
    util.addLine(indent, lines, "# " .. serializer.serCall(ast))
    local functionName = ast[1][1]
    local functionExp = ast[1]
    local arguments = ast[2]
    if functionName == "print" then
    --    dbg()
        local tempValues = emitExpression(indent, arguments, config, stack, lines)
        local dereferenced =
            util.join(
                util.imap(
                    tempValues,
                    derefValToValue), "\t")
        util.addLine(
            indent, lines,
            string.format("eval echo %s", dereferenced))
    elseif functionName == "type" then
        -- TODO: table!
        local value = emitExpression(indent, arguments, config, stack, lines)[1]
        local typeStrValue = emitTempVal(indent, config, lines,
                                         b.c("STR"), derefValToType(value))

        return typeStrValue
    else
        -- TODO: table
        local c = emitExpression(indent, functionExp, config, stack, lines)[1]
        return emitCallClosure(indent, config, lines, c)
    end
end

-- we can do ((Ex = Ex + 1)) even as first comman line because
-- bash will use 0 as value for Ex if the variable is not declared.
function emitEnvCounter(indent, config, lines, envId)
    util.addLine(
        indent, lines,
        string.format("((%s = %s + 1))",
                      config.environmentPrefix .. envId,
                      config.environmentPrefix .. envId),
        "Environment counter")
end

function snapshotEnvironment(indent, ast, config, stack, lines)
    local usedSyms = util.getUsedSymbols(ast)
    return util.imap(
        usedSyms,
        function(sym)
            local assignmentAst = parser.parse(
                string.format("local %s = %s;", sym, sym))
            -- we only need the local ast not the block surrounding it
            return emitLocal(indent, assignmentAst[1], config, stack, lines)
    end)
end

function emitFunction(indent, ast, config, stack, lines)
    local namelist = ast[1]
    local block = ast[2]
    local functionId = util.getUniqueId()
    local oldEnv = stack:top():getEnvironmentId()
    local scopeName = "F" .. functionId()
    local newScope = compiler.Scope(
        compiler.occasions.FUNCTION, scopeName,
        util.getUniqueId(), scope.getPathPrefix(stack) .. scopeName)
    stack:push(newScope)
    local newEnv = stack:top():getEnvironmentId()
    -- temporary set to old for snapshotting
    stack:top():setEnvironmentId(oldEnv)
    util.addLine(indent, lines, "# Closure defintion")
    local tempVal =
        emitTempVal(indent, config, lines,
                    b.pE("E" .. stack:top():getEnvironmentId()),
                    -- adjust symbol string?
                    b.c("BF") .. b.c(tostring(functionId)))
    util.addLine(indent, lines, "# Environment Snapshotting")
    snapshotEnvironment(indent, ast, config, stack, lines)
    -- set again to new envid
    stack:top():setEnvironmentId(newEnv)
    -- translate to bash function including environment set code
    util.addLine(indent, lines, string.format("function BF%s {", functionId))
    util.addLine(indent, lines, (b.c(oldEnv) .. b.c("=") .. b.pE("1"))())
    -- recurse into block
    emitBlock(indent, block, config, stack, lines)
    util.addLine(
        indent, lines,
        string.format("%s=$1", "E" .. scope:top():getEnvironmentId()))
    -- end of function definition
    util.addLine(indent, lines, "}")
    scope:pop()
    return { tempVal }
end

function emitParen(indent, ast, config, stack, lines)
    return emitExpression(indent, ast[1], config, stack, lines)
end

-- always returns a table of location "strings" and the lines table
function emitExpression(indent, ast, config, stack, lines)
    if ast.tag == "Op" then
        return emitOp(indent, ast, config, stack, lines)
    elseif ast.tag == "Id" then
        return emitId(indent, ast, config, stack, lines)
    elseif ast.tag == "True" then
        return emitTrue(indent, ast, config, stack, lines)
    elseif ast.tag == "False" then
        return emitFalse(indent, ast, config, stack, lines)
    elseif ast.tag == "Nil" then
        return emitNil(indent, ast, config, stack, lines)
    elseif ast.tag == "Number" then
        return emitNumber(indent, ast, config, stack, lines)
    elseif ast.tag == "String" then
        return emitString(indent, ast, config, stack, lines)
    elseif ast.tag == "Table" then
        return emitTable(indent, ast, config, stack, lines)
    elseif ast.tag == "Function" then
        return emitFunction(indent, ast, config, stack, lines)
    elseif ast.tag == "Call" then
        return emitCall(indent, ast, config, stack, lines)
    elseif ast.tag == "Paren" then
        return emitParen(indent, ast, config, stack, lines)
    elseif ast.tag == "Index" then
        return emitPrefixexp(indent, ast, config, stack, lines)
    else
        print("emitExpresison(): error!")
        os.exit(1)
    end
end

function emitOp(indent, ast, config, stack, lines)
    if #ast == 3 then return emitBinop(indent, ast, config, stack, lines)
    elseif #ast == 2 then return emitUnop(indent, ast, config, stack, lines)
    else
        print("Not supported!")
        os.exit(1)
    end
end

function emitUnop(indent, ast, config, stack, lines)
    local operand2, lines =
        emitExpression(indent, ast[2], config, stack, lines)[1]
    local tempVal = getTempValname(config, stack, false)
    util.addLine(
        indent, lines,
        b.e(tempVal
                .. b.c("=")
                .. b.p(
                    b.dQ(
                        b.aE(
                            b.c(util.strToOpstring(ast[1])) ..
                                derefValToValue(operand2))) ..
                        b.c(" ") ..
                        derefValToType(operand2)))())

    return { tempVal }
end

function emitBinop(indent, ast, config, stack, lines)
    local ergId1 = getUniqueId(env)
    local tempVal = getTempValname(env)
    local left = emitExpression(ast[2], env, lines)[1]
    local right = emitExpression(ast[3], env, lines)[1]
    util.addLine(
        indent, lines
        (b.e(
             tempVal
                 .. b.c("=")
                 .. b.p(
                     b.dQ(
                         b.aE(
                             derefValToValue(left) ..
                                 b.c(util.strToOpstring(ast[1])) ..
                                 derefValToValue(right)) ..
                             b.c(" ") ..
                             derefValToType(right)))))())
    return { tempVal }
end

function emitExplist(indent, ast, config, stack, lines)
    local locations = {}
    if ast.tag ~= "ExpList" then
        print("emitExplist(): not an explist node!")
        os.exit(1)
    end
    for k, expression in ipairs(ast) do
        local tempValues = emitExpression(indent, expression,
                                          config, stack, lines)
        local tempVnRhs =
            util.imap(tempValues,
                 function(v)
                     return emitTempVal(
                         indent, config, lines,
                         derefValToType(v),
                         derefValToValue(v)) end)
        util.tableIAddInplace(locations, tempVnRhs)
    end
    return locations
end

-- TODO: really blongs not here but in lua2bash-emit-stmt
function emitLocal(indent, ast, config, stack, lines)
    local topScope = stack:top()
    local varNames = {}
    for i = 1, #ast[1] do
        varNames[i] = ast[1][i][1]
    end
    local locations = emitExplist(indent, ast[2], config, stack, lines)
    local memNumDiff = util.tblCountAll(varNames) - tblCountAll(locations)
    if memNumDiff > 0 then -- extend number of expressions to fit varNamelist
        locations[#locations + 1] = "DUMMY"
    end
    local iter = util.statefulIIterator(locations)
    for _, varName in pairs(varNames) do
        local bindingQuery = scope.getMostCurrentBinding(stack, idString)
        local someWhereDefined = bindingQuery ~= nil
        local scope, symbol
        if someWhereDefined then
            scope = bindingQuery.scope
            symbol = bindingQuery.symbol
        end
        if someWhereDefined and (scope ~= stack:top()) then
            local t = iter()
            local newsym = scope.updateSymbol(config, stack, symbol, varName)
            emitVarUpdate(indent, lines,
                          newsym:getEmitVarname(),
                          newsym:getCurSlot(),
                          derefValToValue(t),
                          derefValToType(t))
        elseif someWhereDefined and (scope == stack:top()) then
            local t = iter()
            -- in both cases, define in top scope
            local newsym = scope.setLocalFirstTime(config, stack, varName)
            emitVarUpdate(indent, lines,
                          newsym:getEmitVarname(),
                          newSym:getCurSlot(),
                          derefValToValue(t),
                          derefValToType(t))
        else
            local newsym = scope.setLocalFirstTime(config, stack, varName)
        end
    end
end

function emitVarUpdate(indent, lines, varname, valuename, value, typ)
    util.addLine(indent, lines, b.e(varname, valuename)())
    util.addLine(indent, lines, b.e(valuename .. b.p(b.dQ(value) .. typ))())
end

function emitGlobalVar(indent, varname, valuename, lines, env)
    util.addLine(indent, lines, b.e(varname .. b.c("=") .. valuename)())
end

function emitUpdateGlobVar(indent, valuename, value, lines, env, typ)
    util.addLine(indent, lines, b.e(valuename .. b.c("=") .. b.p(value .. typ))())
end

function emitSet(indent, ast, config, stack, lines)
    util.addLine(indent, lines, "# " .. serSet(ast))
    local explist, varlist = ast[2], ast[1]
    local rhsTempresults = emitExplist(indent, explist, config, stack, lines)
    local iterator = statefulIIterator(rhsTempresults)
    for k, lhs in ipairs(varlist) do
        if lhs.tag == "Id" then
            emitSimpleAssign(indent, lhs, config,
                             stack, lines, iterator())
        else
            emitComplexAssign(indent, lhs, config,
                              stack, lines, iterator())
        end
    end
end

--TODO:
function emitSimpleAssign(indent, ast, config, stack, lines, rhs)
    local varName = ast[1]
    local scopeQuery = scope.getMostCurrentBinding(stack, varName)
    local inSome, coordinate = isInSomeScope(env, idString)
    if scopeQuery == nil then -- make var in global
        local symbol = scope.setGlobal(config, stack, varName)
        inSome, coordinate = isInSomeScope(env, idString)
        emitGlobalVar(coordinate[2].emitVarname,
                      coordinate[2].emitCurSlot,
                      lines, env)
    end
    emitUpdateGlobVar(coordinate[2].emitCurSlot,
                      derefValToValue(rhs),
                      lines, env,
                      derefValToType(rhs))
end

-- TODO:
function emitComplexAssign(lhs, env, lines, rhs)
    local setValue = emitExecutePrefixexp(lhs, env, lines, true)[1]
    emitUpdateGlobVar(string.format([[$(eval echo %s)]], setValue),
                      derefValToValue(rhs),
                      lines, env,
                      derefValToType(rhs))
end

function emitPrefixexp(indent, ast, config, stack, lines)
    return emitExecutePrefixexp(ast, env, lines)
end

--
-- dereferences expressions like getTable()[1]
-- and returns the values to be written to
function emitExecutePrefixexp(indent, prefixExp, config, stack, lines, asLval)
    local indirections = linearizePrefixTree(prefixExp, env)
    local temp = {}
    for i = 1, #indirections do
        local indirection = indirections[i]
        -- Id and Paren nodes are both terminal in this production tree
        -- in prefix expressions a paren or id node can only occur once
        -- on the left
        if indirection.typ == "Id" then
            local inSome, coordinate = isInSomeScope(env, indirection.id)
            if not inSome then
                print("Must be in one scope!");
                os.exit(1);
            end
            temp[i] = emitId(indirection.ast, env, lines)[1]
        elseif indirection.typ == "Paren" then
            temp[i] = emitExpression(indirection.exp, env, lines)[1]
        elseif indirection.typ == "Call"  then
            -- TODO function arguments!
            local funArgs
            temp[i] = emitCallClosure(env, lines, temp[i - 1], funArgs)[1]
        elseif indirection.typ == "Index" then
            local index = emitExpression(indirection.exp, config, lines)[1]
            index =  derefValToValue(temp[i-1]) .. derefValToValue(index)
            if i == #indirections and asLval then
                temp[i] = index
            else
                temp[i] = emitTempVal(
                    ast, config, lines,
                    b.pE(index .. b.c("[1]")),
                    b.pE(index))
            end
        end
    end
    return { temp[#temp] }
end

function linearizePrefixTree(indent, ast, config, stack, result)
    local result = result or {}
    if type(ast) ~= "table" then return result end
    if ast.tag == "Id" then
        result[#result + 1] =
            { id = ast[1],
              typ = ast.tag,
              ast = ast,
              exp = nil}
    elseif ast.tag == "Paren" then
        result[#result + 1] =
            { exp = ast[1],
              typ = ast.tag,
              ast = ast}
    elseif ast.tag == "Call"  then
        result[#result + 1] =
            { callee = ast[1],
              typ = ast.tag,
              ast = ast,
              exp = util.tableSlice(ast, 2, #ast, 1)}
    elseif ast.tag == "Index" then
        result[#result + 1] =
            { indexee = ast[1],
              typ = ast.tag,
              ast = ast,
              exp = ast[2]}
    end
    if ast.tag ~= "Id" then
        linearizePrefixTree(ast[1], config, result)
    end
    return util.tableReverse(result)
end
