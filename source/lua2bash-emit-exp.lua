local util = require("lua2bash-util")
local scope = require("lua2bash-scope")
local datatypes = require("lua2bash-datatypes")
local serializer = require("lua2bash-serialize-ast")

local se= require("lua2bash-emit-stmt")
local ee = {}

function ee.emitId(indent, ast, config, stack, lines)
    if ast.tag ~= "Id" then
        print("emitId(): not a Id node")
        os.exit(1)
    end
    local varname = ast[1]
    local binding = scope.getMostCurrentBinding(config, stack, varname)
    if binding == nil then return "NIL" end -- better solution?
    local emitVn = binding.symbol:getEmitVarname()
    return { emitTempVal(indent, config, stack, lines,
                         ee.derefVarToType(emitVn),
                         ee.derefVarToValue(emitVn)) }
end

function ee.emitNumber(indent, ast, config, stack, lines)
    local value = tostring(ast[1])
    if ast.tag ~= "Number" then
        print("emitNumber(): not a Number node")
        os.exit(1)
    end
    return { ee.emitTempVal(indent, config, stack, lines,
                            b.c("NUM"), b.c(value)) }
end

function ee.emitNil(indent, ast, config, stack, lines)
    if ast.tag ~= "Nil" then
        print("emitNil(): not a Nil node")
        os.exit(1)
    end
    return { ee.emitTempVal(indent, config, lines, b.c("NIL"), b.c("")) }
end

function ee.getEnvVar(config, stack)
    return b.pE(config.environmentPrefix .. stack:top():getEnvironmentId())
end

function ee.getTempValname(config, stack, simple)
    local commonSuffix
    if not simple then
        commonSuffix = b.c(ee.getEnvVar(config, stack)) ..
            b.c("_") ..
            b.c(tostring(util.getUniqueId()))
    else
        commonSuffix = b.c("_") .. b.c(util.getUniqueId())
    end
    return b.c(config.tempValPrefix) .. commonSuffix
end

-- typ and content must be values from bash EDSL
function ee.emitTempVal(indent, config, stack, lines, typ, content, simple)
    local tempVal = ee.getTempValname(config, stack, simple)
    local cmdLine = b.e(tempVal .. b.c("=") .. b.p(content .. b.c(" ") .. typ))
    util.addLine(indent, lines, cmdLine())
    return tempVal
end

function ee.derefVarToValue(varname)
    return b.pE(b.c("!") .. b.c(varname))
end

function ee.derefVarToType(varname)
    return b.pE(b.pE(varname) .. b.c("[1]"))
end

function ee.derefValToEnv(valuename)
    return b.pE(valuename .. b.c("[2]"))
end

function ee.derefValToValue(valuename)
    return b.pE(valuename)
end

function ee.derefValToType(valname)
    return b.pE(valname .. b.c("[1]"))
end

function ee.emitString(indent, ast, config, stack, lines)
    if ast.tag ~= "String" then
        print("emitString(): not a string node")
        os.exit(1)
    end
    return { ee.emitTempVal(indent, config, stack, lines,
                            b.c("STR"), b.c(ast[1]), false) }
end

function ee.emitFalse(indent, ast, config, stack, lines)
    if ast.tag ~= "False" then
        print("emitFalse(): not a False node!")
        os.exit(1)
    end
    return { ee.emitTempVal(indent, config, stack, lines,
                            b.c("FLS"), b.c("0"), false) }
end

function ee.emitTrue(indent, ast, config, stack, lines)
    if ast.tag ~= "True" then
        print("emitTrue(): not a True node!")
        os.exit(1)
    end
    return { ee.emitTempVal(indent, config, stack, lines,
                            b.c("TRU"), b.c("1"), false) }
end

function ee.emitTableValue(indent, config, stack, lines, tblIdx, value, typ)
    local typeString = b.c("TBL")
    local envVar = ee.getEnvVar(config, stack)
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
function ee.emitTable(indent, ast, config, stack, lines, firstCall)
    if ast.tag ~= "Table" then
        print("emitTable(): not a Table!")
        os.exit(1)
    end
    if firstCall == nil then
        util.addLine(indent, lines, "# " .. serTbl(ast))
    end
    local tableId = util.getUniqueId(env)
    local tempValues
    ee.emitTableValue(indent, config, stack, lines, tableId)
    for k, v in ipairs(ast) do
        local fieldExp = ast[k]
        if (v.tag == "Pair") then
            print("Associative tables not yet supported")
            os.exit(1)
        elseif v.tag ~= "Table" then
            tempValues = ee.emitExpression(indent, fieldExp, config, stack, lines)
            imap(
                tempValues,
                function(v)
                    ee.emitTableValue(indent, config, stack,
                                      lines, tableId .. k,
                                      derefValToValue(v),
                                      derefValToType(v)) end)
        else
            -- tempValues possibly is a list of tempValue
            tempValues = ee.emitTable(indent, ast[k], config,
                                      stack, lines, false)
            imap(
                tempValues,
                function(v)
                    ee.emitTableValue(indent, config, stack,
                                      lines, tableId .. k,
                                      derefValToValue(v),
                                      derefValToType(v)) end)
        end
    end
    return { b.c(env.tablePrefix)
                 .. ee.getEnvVar(config, stack)
                 .. b.c(tostring(tableId))}
end

-- TODO: argValueList!
-- returns a tempvalue of the result
function ee.emitCallClosure(indent, config, lines, closureValue, argValueList)
    local cmdLine = b.e(ee.derefValToValue(closureValue)
                            .. b.c(" ")
                            .. ee.derefValToType(closureValue))
    util.addLine(indent, lines, cmdLine())
end

-- TODO: return und argumente
function ee.emitCall(indent, ast, config, stack, lines)
    util.addLine(indent, lines, "# " .. serializer.serCall(ast))
    local functionName = ast[1][1]
    local functionExp = ast[1]
    local arguments = ast[2]
    if functionName == "print" then
    --    dbg()
        local tempValues = ee.emitExpression(indent, arguments, config,
                                             stack, lines)
        local dereferenced =
            util.join(
                util.imap(
                    tempValues,
                    ee.derefValToValue), "\t")
        util.addLine(
            indent, lines,
            string.format("eval echo %s", dereferenced))
    elseif functionName == "type" then
        -- TODO: table!
        local value = ee.emitExpression(
            indent, arguments, config, stack, lines)[1]
        local typeStrValue = ee.emitTempVal(
            indent, config, stack, lines, b.c("STR"), ee.derefValToType(value))
        return typeStrValue
    else
        -- TODO: table
        local c = ee.emitExpression(indent, functionExp, config, stack, lines)[1]
        return ee.emitCallClosure(indent, config, lines, c)
    end
end

-- we can do ((Ex = Ex + 1)) even as first comman line because
-- bash will use 0 as value for Ex if the variable is not declared.
function ee.emitEnvCounter(indent, config, lines, envId)
    util.addLine(
        indent, lines,
        string.format("((%s = %s + 1))",
                      config.environmentPrefix .. envId,
                      config.environmentPrefix .. envId),
        "Environment counter")
end

function ee.snapshotEnvironment(indent, ast, config, stack, lines)
    local usedSyms = util.getUsedSymbols(ast)
    return util.imap(
        usedSyms,
        function(sym)
            local assignmentAst = parser.parse(
                string.format("local %s = %s;", sym, sym))
            -- we only need the local ast not the block surrounding it
            return ee.emitLocal(indent, assignmentAst[1], config, stack, lines)
    end)
end

function ee.emitFunction(indent, ast, config, stack, lines)
    local namelist = ast[1]
    local block = ast[2]
    local functionId = util.getUniqueId()
    local oldEnv = stack:top():getEnvironmentId()
    local scopeName = "F" .. functionId()
    local newScope = datatypes.Scope(
        datatypes.occasions.FUNCTION, scopeName,
        util.getUniqueId(), scope.getPathPrefix(stack) .. scopeName)
    stack:push(newScope)
    local newEnv = stack:top():getEnvironmentId()
    -- temporary set to old for snapshotting
    stack:top():setEnvironmentId(oldEnv)
    util.addLine(indent, lines, "# Closure defintion")
    local tempVal =
        emitTempVal(indent, config, stack, lines,
                    b.pE("E" .. stack:top():getEnvironmentId()),
                    -- adjust symbol string?
                    b.c("BF") .. b.c(tostring(functionId)))
    util.addLine(indent, lines, "# Environment Snapshotting")
    ee.snapshotEnvironment(indent, ast, config, stack, lines)
    -- set again to new envid
    stack:top():setEnvironmentId(newEnv)
    -- translate to bash function including environment set code
    util.addLine(indent, lines, string.format("function BF%s {", functionId))
    util.addLine(indent, lines, (b.c(oldEnv) .. b.c("=") .. b.pE("1"))())
    -- recurse into block
    se.emitBlock(indent, block, config, stack, lines)
    util.addLine(
        indent, lines,
        string.format("%s=$1", "E" .. scope:top():getEnvironmentId()))
    -- end of function definition
    util.addLine(indent, lines, "}")
    scope:pop()
    return { tempVal }
end

function ee.emitParen(indent, ast, config, stack, lines)
    return ee.emitExpression(indent, ast[1], config, stack, lines)
end

-- always returns a table of location "strings" and the lines table
function ee.emitExpression(indent, ast, config, stack, lines)
    if ast.tag == "Op" then
        return ee.emitOp(indent, ast, config, stack, lines)
    elseif ast.tag == "Id" then
        return ee.emitId(indent, ast, config, stack, lines)
    elseif ast.tag == "True" then
        return ee.emitTrue(indent, ast, config, stack, lines)
    elseif ast.tag == "False" then
        return ee.emitFalse(indent, ast, config, stack, lines)
    elseif ast.tag == "Nil" then
        return ee.emitNil(indent, ast, config, stack, lines)
    elseif ast.tag == "Number" then
        return ee.emitNumber(indent, ast, config, stack, lines)
    elseif ast.tag == "String" then
        return ee.emitString(indent, ast, config, stack, lines)
    elseif ast.tag == "Table" then
        return ee.emitTable(indent, ast, config, stack, lines)
    elseif ast.tag == "Function" then
        return ee.emitFunction(indent, ast, config, stack, lines)
    elseif ast.tag == "Call" then
        return ee.emitCall(indent, ast, config, stack, lines)
    elseif ast.tag == "Paren" then
        return ee.emitParen(indent, ast, config, stack, lines)
    elseif ast.tag == "Index" then
        return ee.emitPrefixexp(indent, ast, config, stack, lines)
    else
        print("emitExpresison(): error!")
        os.exit(1)
    end
end

function ee.emitOp(indent, ast, config, stack, lines)
    if #ast == 3 then return ee.emitBinop(indent, ast, config, stack, lines)
    elseif #ast == 2 then return ee.emitUnop(indent, ast, config, stack, lines)
    else
        print("Not supported!")
        os.exit(1)
    end
end

function ee.emitUnop(indent, ast, config, stack, lines)
    local operand2, lines =
        ee.emitExpression(indent, ast[2], config, stack, lines)[1]
    local tempVal = ee.getTempValname(config, stack, false)
    util.addLine(
        indent, lines,
        b.e(tempVal
                .. b.c("=")
                .. b.p(
                    b.dQ(
                        b.aE(
                            b.c(util.strToOpstring(ast[1])) ..
                                ee.derefValToValue(operand2))) ..
                        b.c(" ") ..
                        ee.derefValToType(operand2)))())
    return { tempVal }
end

function ee.emitBinop(indent, ast, config, stack, lines)
    local ergId1 = util.getUniqueId()
    local tempVal = ee.getTempValname(env)
    local left = ee.emitExpression(ast[2], env, lines)[1]
    local right = ee.emitExpression(ast[3], env, lines)[1]
    util.addLine(
        indent, lines
        (b.e(
             tempVal
                 .. b.c("=")
                 .. b.p(
                     b.dQ(
                         b.aE(
                             ee.derefValToValue(left) ..
                                 b.c(util.strToOpstring(ast[1])) ..
                                 ee.derefValToValue(right)) ..
                             b.c(" ") ..
                             ee.derefValToType(right)))))())
    return { tempVal }
end

function ee.emitExplist(indent, ast, config, stack, lines)
    local locations = {}
    if ast.tag ~= "ExpList" then
        print("emitExplist(): not an explist node!")
        os.exit(1)
    end
    for k, expression in ipairs(ast) do
        local tempValues = ee.emitExpression(
            indent, expression, config, stack, lines)
        local tempVnRhs =
            util.imap(tempValues,
                 function(v)
                     return ee.emitTempVal(
                         indent, config, stack, lines,
                         ee.derefValToType(v),
                         ee.derefValToValue(v)) end)
        util.tableIAddInplace(locations, tempVnRhs)
    end
    return locations
end

-- TODO: really blongs not here but in lua2bash-emit-stmt
function emitLocal(indent, ast, config, stack, lines)
    -- functions
    -- local vars
    local topScope = stack:top()
    local varNames = {}
    for i = 1, #ast[1] do
        varNames[i] = ast[1][i][1]
    end
    local locations = ee.emitExplist(indent, ast[2], config, stack, lines)
    local memNumDiff = util.tblCountAll(varNames) - util.tblCountAll(locations)
    if memNumDiff > 0 then -- extend number of expressions to fit varNamelist
        for i = 1, memNumDiff do
            locations[#locations + 1] = { b.c("VAR_NIL") }
        end
    end
    local iter = util.statefulIIterator(locations)
    for _, varName in pairs(varNames) do
        local bindingQuery = scope.getMostCurrentBinding(stack, varName)
        local someWhereDefined = bindingQuery ~= nil
        local s, symbol
        local location = iter()
        if someWhereDefined then
            symScope, symbol = bindingQuery.scope, bindingQuery.symbol
        end
        if someWhereDefined and (symScope ~= stack:top()) then
            symbol:replaceBy(
                scope.getUpdatedSymbol(
                    config, stack, symbol, varName))
            emitVarUpdate(indent, lines,
                          symbol:getEmitVarname(),
                          symbol:getCurSlot(),
                          ee.derefValToValue(location),
                          ee.derefValToType(location))
        elseif someWhereDefined and (symScope == stack:top()) then
            symbol:replaceBy(
                scope.getNewLocalSymbol(
                    config, stack, varName))
            emitVarUpdate(indent, lines,
                          symbol:getEmitVarname(),
                          symbol:getCurSlot(),
                          ee.derefValToValue(location),
                          ee.derefValToType(location))
        else
            symbol = scope.getNewLocalSymbol(config, stack, varName)
            stack:top():getSymbolTable():addNewSymbol(symbol, varName)
            emitVarUpdate(indent, lines,
                          symbol:getEmitVarname(),
                          symbol:getCurSlot(),
                          ee.derefValToValue(location),
                          ee.derefValToType(location))
        end
    end
end

function ee.emitVarUpdate(indent, lines, varname, valuename, value, typ)
    util.addLine(indent, lines, b.e(varname .. valuename)())
    util.addLine(indent, lines, b.e(valuename .. b.p(b.dQ(value) .. typ))())
end

function ee.emitGlobalVar(indent, varname, valuename, lines)
    util.addLine(indent, lines, b.e(varname .. b.c("=") .. valuename)())
end

function ee.emitUpdateGlobVar(indent, valuename, value, lines, typ)
    util.addLine(indent, lines, b.e(valuename .. b.c("=") .. b.p(value .. typ))())
end

function ee.emitSet(indent, ast, config, stack, lines)
    util.addLine(indent, lines, "# " .. serializer.serSet(ast))
    local explist, varlist = ast[2], ast[1]
    local rhsTempresults = ee.emitExplist(indent, explist, config, stack, lines)
    local iterator = util.statefulIIterator(rhsTempresults)
    for k, lhs in ipairs(varlist) do
        if lhs.tag == "Id" then
            ee.emitSimpleAssign(
                indent, lhs, config, stack, lines, iterator())
        else
            ee.emitComplexAssign(
                indent, lhs, config, stack, lines, iterator())
        end
    end
end

function ee.emitSimpleAssign(indent, ast, config, stack, lines, rhs)
    local varName = ast[1]
    local bindingQuery = scope.getMostCurrentBinding(stack, varName)
    local someWhereDefined = bindingQuery ~= nil
    local symbol
    if someWhereDefined then
        symbol = bindingQuery.scope
    else
        symbol = scope.getGlobalSymbol(config, stack, varName)
        stack:bottom():getSymbolTable():addNewSymbol(varName, symbol)
    end
    if someWhereDefined then -- make new var in global
        ee.emitGlobalVar(
            indent, symbol:getEmitVarname(), symbol:getCurSlot(), lines)
    end
    ee.emitUpdateGlobVar(indent, symbol:getCurSlot(),
                         derefValToValue(rhs),
                         lines, derefValToType(rhs))
end

-- TODO:
function ee.emitComplexAssign(lhs, env, lines, rhs)
    local setValue = ee.emitExecutePrefixexp(lhs, env, lines, true)[1]
    ee.emitUpdateGlobVar(
        indent, setValue, derefValToValue(rhs), lines, derefValToType(rhs))
end

function ee.emitPrefixexp(indent, ast, config, stack, lines)
    return ee.emitExecutePrefixexp(ast, env, lines)
end

--
-- dereferences expressions like getTable()[1]
-- and returns the values to be written to
function ee.emitExecutePrefixexp(indent, prefixExp, config, stack, lines, asLval)
    local indirections = linearizePrefixTree(prefixExp, env)
    local temp = {}
    for i = 1, #indirections do
        local indirection = indirections[i]
        -- Id and Paren nodes are both terminal in this production tree
        -- in prefix expressions a paren or id node can only occur once
        -- on the left
        if indirection.typ == "Id" then
            local bindingQuery =
                scope.getMostCurrentBinding(env, indirection.id)
            if not bindingQuery then
                print("Must be in one scope!");
                os.exit(1);
            end
            temp[i] = ee.emitId(indent, indirection.ast, config, stack, lines)[1]
        elseif indirection.typ == "Paren" then
            temp[i] = ee.emitExpression(
                indent, indirection.exp, config, stack, lines)[1]
        elseif indirection.typ == "Call"  then
            -- TODO function arguments!
            local funArgs
            temp[i] = ee.emitCallClosure(
                indent, env, lines, temp[i - 1], funArgs)[1]
        elseif indirection.typ == "Index" then
            local index = ee.emitExpression(
                indent, indirection.exp, config, stack, lines)[1]
            index =  ee.derefValToValue(temp[i-1]) .. ee.derefValToValue(index)
            if i == #indirections and asLval then
                temp[i] = index
            else
                temp[i] = ee.emitTempVal(
                    ast, config, stack, lines,
                    b.pE(index .. b.c("[1]")),
                    b.pE(index))
            end
        end
    end
    return { temp[#temp] }
end

local function linearizePrefixTree(indent, ast, config, stack, result)
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

return ee
