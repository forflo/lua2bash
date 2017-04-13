local datatypes = require("lua2bash-datatypes")
local util = require("lua2bash-util")
local scope = require("lua2bash-scope")
local serializer = require("lua2bash-serialize-ast")

local emitter = {}
local emitUtil = require("lua2bash-emit-util")

function emitter.getEnvVar(config, stack)
    return b.pE(config.environmentPrefix .. stack:top():getEnvironmentId())
end

function emitter.getTempValname(config, stack, simple)
    local commonSuffix
    if not simple then
        commonSuffix = b.c(emitter.getEnvVar(config, stack)) ..
            b.c("_") ..
            b.c(tostring(util.getUniqueId()))
    else
        commonSuffix = b.c("_") .. b.c(util.getUniqueId())
    end
    return b.c(config.tempValPrefix) .. commonSuffix
end

-- typ and content must be values from bash EDSL
function emitter.emitTempVal(indent, config, stack, lines, typ, content, simple)
    local tempVal = emitter.getTempValname(config, stack, simple)
    local cmdLine = b.e(tempVal .. b.c("=") .. b.p(content .. b.c(" ") .. typ))
    util.addLine(indent, lines, cmdLine())
    return tempVal
end

function emitter.emitId(indent, ast, config, stack, lines)
    if ast.tag ~= "Id" then
        print("emitId(): not a Id node")
        os.exit(1)
    end
    local varname = ast[1]
    local binding = scope.getMostCurrentBinding(stack, varname)
    if binding == nil then return "NIL" end -- better solution?
    local emitVn = binding.symbol:getEmitVarname()
    return {
        emitter.emitTempVal(
            indent, config, stack, lines,
            emitUtil.derefVarToType(emitVn),
            emitUtil.derefVarToValue(emitVn)) }
end

function emitter.emitNumber(indent, ast, config, stack, lines)
    local value = tostring(ast[1])
    if ast.tag ~= "Number" then
        print("emitNumber(): not a Number node")
        os.exit(1)
    end
    return {
        emitter.emitTempVal(
            indent, config, stack, lines,
            b.c("NUM"), b.c(value))}
end

function emitter.emitNil(indent, ast, config, stack, lines)
    if ast.tag ~= "Nil" then
        print("emitNil(): not a Nil node")
        os.exit(1)
    end
    return {
        emitter.emitTempVal(
            indent, config, lines,
            b.c("NIL"), b.c("")) }
end

function emitter.emitString(indent, ast, config, stack, lines)
    if ast.tag ~= "String" then
        print("emitString(): not a string node")
        os.exit(1)
    end
    return {
        emitter.emitTempVal(
            indent, config, stack, lines,
            b.c("STR"), b.c(ast[1]), false) }
end

function emitter.emitFalse(indent, ast, config, stack, lines)
    if ast.tag ~= "False" then
        print("emitFalse(): not a False node!")
        os.exit(1)
    end
    return {
        emitter.emitTempVal(
            indent, config, stack, lines,
            b.c("FLS"), b.c("0"), false) }
end

function emitter.emitTrue(indent, ast, config, stack, lines)
    if ast.tag ~= "True" then
        print("emitTrue(): not a True node!")
        os.exit(1)
    end
    return {
        emitter.emitTempVal(
            indent, config, stack, lines,
            b.c("TRU"), b.c("1"), false) }
end

function emitter.emitTableValue(indent, config, stack, lines, tblIdx, value, typ)
    local typeString = b.c("TBL")
    local envVar = emitter.getEnvVar(config, stack)
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
function emitter.emitTable(indent, ast, config, stack, lines, firstCall)
    if ast.tag ~= "Table" then
        print("emitTable(): not a Table!")
        os.exit(1)
    end
    if firstCall == nil then
        util.addLine(indent, lines, "# " .. serTbl(ast))
    end
    local tableId = util.getUniqueId(env)
    local tempValues
    emitter.emitTableValue(indent, config, stack, lines, tableId)
    for k, v in ipairs(ast) do
        local fieldExp = ast[k]
        if (v.tag == "Pair") then
            print("Associative tables not yet supported")
            os.exit(1)
        elseif v.tag ~= "Table" then
            tempValues = emitter.emitExpression(
                indent, fieldExp, config, stack, lines)
            imap(
                tempValues,
                function(v)
                    emitter.emitTableValue(
                        indent, config, stack,
                        lines, tableId .. k,
                        derefValToValue(v),
                        derefValToType(v)) end)
        else
            -- tempValues possibly is a list of tempValue
            tempValues = emitter.emitTable(
                indent, ast[k],
                config, stack,
                lines, false)
            imap(
                tempValues,
                function(v)
                    emitter.emitTableValue(
                        indent, config, stack,
                        lines, tableId .. k,
                        derefValToValue(v),
                        derefValToType(v)) end)
        end
    end
    return { b.c(env.tablePrefix)
                 .. emitter.getEnvVar(config, stack)
                 .. b.c(tostring(tableId))}
end

-- TODO: argValueList!
-- returns a tempvalue of the result
function emitter.emitCallClosure(indent, config, lines,
                                 closureValue, argValueList)
    local cmdLine = b.e(emitUtil.derefValToValue(closureValue)
                            .. b.c(" ")
                            .. emitUtil.derefValToType(closureValue))
    util.addLine(indent, lines, cmdLine())
end

-- TODO: return und argumente
function emitter.emitCall(indent, ast, config, stack, lines)
    util.addLine(indent, lines, "# " .. serializer.serCall(ast))
    local functionName = ast[1][1]
    local functionExp = ast[1]
    local arguments = util.tableSlice(ast, 2, #ast, 1)
    local tempValues =
        util.tableIConcat(
            util.imap(
                arguments,
                function(exp)
                    return emitter.emitExpression(
                        indent, exp, config, stack, lines)
            end), {})
    if functionName == "print" then
        local dereferenced =
            util.join(
                util.imap(
                    tempValues,
                    util.composeV(
                        util.call,
                        emitUtil.derefValToValue)),
                [[\\\\\\\t]])
        util.addLine(
            indent, lines,
            string.format("eval echo -e %s", dereferenced))
    elseif functionName == "type" then
        -- TODO: table!
        local value = emitter.emitExpression(
            indent, arguments, config, stack, lines)[1]
        local typeStrValue = emitter.emitTempVal(
            indent, config, stack, lines, b.c("STR"),
            emitUtil.derefValToType(value))
        return typeStrValue
    else
        -- TODO: table
        local c = emitter.emitExpression(
            indent, functionExp, config, stack, lines)[1]
        return emitter.emitCallClosure(indent, config, lines, c)
    end
end

function emitter.snapshotEnvironment(indent, ast, config, stack, lines)
    local usedSyms = util.getUsedSymbols(ast)
    return util.imap(
        usedSyms,
        function(sym)
            local assignmentAst = parser.parse(
                string.format("local %s = %s;", sym, sym))
            -- we only need the local ast not the block surrounding it
            return se.emitLocal(indent, assignmentAst[1], config, stack, lines)
    end)
end

function emitter.emitFunction(indent, ast, config, stack, lines)
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
    emitter.snapshotEnvironment(indent, ast, config, stack, lines)
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

function emitter.emitParen(indent, ast, config, stack, lines)
    return emitter.emitExpression(indent, ast[1], config, stack, lines)
end

-- always returns a table of location "strings" and the lines table
function emitter.emitExpression(indent, ast, config, stack, lines)
    if ast.tag == "Op" then
        return emitter.emitOp(indent, ast, config, stack, lines)
    elseif ast.tag == "Id" then
        return emitter.emitId(indent, ast, config, stack, lines)
    elseif ast.tag == "True" then
        return emitter.emitTrue(indent, ast, config, stack, lines)
    elseif ast.tag == "False" then
        return emitter.emitFalse(indent, ast, config, stack, lines)
    elseif ast.tag == "Nil" then
        return emitter.emitNil(indent, ast, config, stack, lines)
    elseif ast.tag == "Number" then
        return emitter.emitNumber(indent, ast, config, stack, lines)
    elseif ast.tag == "String" then
        return emitter.emitString(indent, ast, config, stack, lines)
    elseif ast.tag == "Table" then
        return emitter.emitTable(indent, ast, config, stack, lines)
    elseif ast.tag == "Function" then
        return emitter.emitFunction(indent, ast, config, stack, lines)
    elseif ast.tag == "Call" then
        return emitter.emitCall(indent, ast, config, stack, lines)
    elseif ast.tag == "Paren" then
        return emitter.emitParen(indent, ast, config, stack, lines)
    elseif ast.tag == "Index" then
        return emitter.emitPrefixexp(indent, ast, config, stack, lines)
    else
        print("emitExpresison(): error!")
        os.exit(1)
    end
end

function emitter.emitOp(indent, ast, config, stack, lines)
    if #ast == 3 then return emitter.emitBinop(indent, ast, config, stack, lines)
    elseif #ast == 2 then return emitter.emitUnop(indent, ast, config, stack, lines)
    else
        print("Not supported!")
        os.exit(1)
    end
end

function emitter.emitUnop(indent, ast, config, stack, lines)
    local operand2, lines =
        emitter.emitExpression(indent, ast[2], config, stack, lines)[1]
    local tempVal = emitter.getTempValname(config, stack, false)
    util.addLine(
        indent, lines,
        b.e(tempVal
                .. b.c("=")
                .. b.p(
                    b.dQ(
                        b.aE(
                            b.c(util.strToOpstr(ast[1])) ..
                                emitUtil.derefValToValue(operand2))) ..
                        b.c(" ") ..
                        emitUtil.derefValToType(operand2)))())
    return { tempVal }
end

function emitter.emitBinop(indent, ast, config, stack, lines)
    local ergId1 = util.getUniqueId()
    local tempVal = emitter.getTempValname(config, stack)
    local left = emitter.emitExpression(indent, ast[2], config, stack, lines)[1]
    local right = emitter.emitExpression(indent, ast[3], config, stack, lines)[1]
    util.addLine(
        indent, lines,
        b.e(
             tempVal
                 .. b.c("=")
                 .. b.c("\\(")
                 .. b.dQ(
                     b.aE(
                         emitUtil.derefValToValue(left) ..
                             b.c(util.strToOpstr(ast[1])) ..
                             emitUtil.derefValToValue(right)) ..
                         b.c(" ") ..
                         emitUtil.derefValToType(right))
                 .. b.c("\\)"))())
    return { tempVal }
end

function emitter.emitExplist(indent, ast, config, stack, lines)
    local locations = {}
    if ast.tag ~= "ExpList" then
        print("emitExplist(): not an explist node!")
        os.exit(1)
    end
    for k, expression in ipairs(ast) do
        local tempValues = emitter.emitExpression(
            indent, expression, config, stack, lines)
        local tempVnRhs =
            util.imap(tempValues,
                 function(v)
                     return emitter.emitTempVal(
                         indent, config, stack, lines,
                         emitUtil.derefValToType(v),
                         emitUtil.derefValToValue(v)) end)
        util.tableIAddInplace(locations, tempVnRhs)
    end
    return locations
end

function emitter.emitPrefixexp(indent, ast, config, stack, lines)
    return emitter.emitExecutePrefixexp(ast, env, lines)
end

--
-- dereferences expressions like getTable()[1]
-- and returns the values to be written to
function emitter.emitExecutePrefixexp(indent, prefixExp, config,
                                      stack, lines, asLval)
    local indirections = emitUtil.linearizePrefixTree(prefixExp, env)
    local temp = {}
    for i = 1, #indirections do
        local indirection = indirections[i]
        -- Id and Paren nodes are both terminal in this production tree
        -- in prefix expressions a paren or id node can only occur once
        -- on the left
        if indirection.typ == "Id" then
            local bindingQuery =
                scope.getMostCurrentBinding(stack, indirection.id)
            if not bindingQuery then
                print("Must be in one scope!");
                os.exit(1);
            end
            temp[i] = emitter.emitId(
                indent, indirection.ast, config, stack, lines)[1]
        elseif indirection.typ == "Paren" then
            temp[i] = emitter.emitExpression(
                indent, indirection.exp, config, stack, lines)[1]
        elseif indirection.typ == "Call"  then
            -- TODO function arguments!
            local funArgs
            temp[i] = emitter.emitCallClosure(
                indent, env, lines, temp[i - 1], funArgs)[1]
        elseif indirection.typ == "Index" then
            local index = emitter.emitExpression(
                indent, indirection.exp, config, stack, lines)[1]
            index =  emitUtil.derefValToValue(temp[i-1])
                .. emitUtil.derefValToValue(index)
            if i == #indirections and asLval then
                temp[i] = index
            else
                temp[i] = emitter.emitTempVal(
                    ast, config, stack, lines,
                    b.pE(index .. b.c("[1]")),
                    b.pE(index))
            end
        end
    end
    return { temp[#temp] }
end

-- occasion is the reason for the block
-- can be "do", "function", "for", "while", ...
function emitter.emitBlock(indent, ast, config, stack, lines, occasion)
    local scopeNumber = util.getUniqueId()
    local envId = util.getUniqueId()
    local occasion = occasion or datatypes.occasions.BLOCK
    local scopeName = "S" .. scopeNumber
    -- push new scope on top
    local newScope = datatypes.Scope(
        occasion, scopeName, envId,
        scope.getPathPrefix(stack) .. scopeName)
    stack:push(newScope)
    util.addLine(
        indent, lines,
        "# Begin of Scope: " .. stack:top():getPath())
    emitUtil.emitEnvCounter(indent + config.indentSize, config,
                   lines, stack:top():getEnvironmentId())
    -- emit all enclosed statements
    for k, v in ipairs(ast) do
        if type(v) == "table" then
            emitter.emitStatement(indent, v, config, stack, lines)
        else
            print("emitBlock error!??")
            os.exit(1)
        end
    end
    -- pop the scope
    stack:pop()
end

-- TODO: komplett neu schreiben
function emitter.emitFornum(indent, ast, config, stack, lines)
    -- push new scope only for the loop counter
    pushScope(env,
              "for",
              "L" .. util.getUniqueId(env))

    local block = ast[5] or ast[4]
    local existsIncrement = ast[4].tag ~= "Block"

    -- build syntax tree for set instruction
    local tempAST = {
        tag = "Set",
        pos = -1,
        {
            tag = "VarList",
            pos = -1,
            {
                tag = "Id",
                pos = -1,
                ast[1][1]
            }
        },
        {
            tag = "ExpList",
            pos = -1,
            ast[2]
        }
    }

    emitSet(tempAST, env, lines, true)

    lines[#lines + 1] = augmentLine(config, "for ((;;)); do")

    local tempASTIf = {
        tag = "If",
        pos = -1,
        {
            tag = "Op",
            pos = -1,
            "le",
            ast[1],
            ast[3],
        },
        block,
        {
            tag = "Block",
            pos = -1,
            {
                tag = "SPECIAL",
                pos = -420,
                special = "break;"
            }
        }
    }

    -- extend forblock so that it increments the loop counter
    local incrementor, errormsg = -- TODO: only increments by 1. The
        -- increment needs to be calculated before
        parser.parse(string.format("%s=%s+(%s)",
                                   ast[1][1],
                                   ast[1][1],
                                   serExp(ast[4])))
    if not ast then
        print(errormsg)
        os.exit(1)
    end
    block[#block + 1] = incrementor[1]

    -- pp.dump(tempASTIf)
    emitIf(tempASTIf, env, lines)

    lines[#lines + 1] = augmentLine(env, "true", "Dummy command for BASH")

    decCC(env)
    lines[#lines + 1] = augmentLine(env, "done")

    -- pop the loop counter scope
    popScope(env)
end

function emitter.emitIf(indent, ast, config, stack, lines)
    if #ast == 1 then
        -- make else
        emitBlock(indent + config.indentSize,
                  ast[1], config, stack, lines,
                  datatypes.occasion.IF)
    elseif #ast > 1 then
        -- calculate expression
        local location = emitExpression(indent, ast[1], config, stack, lines)
        util.addLine(
            indent, lines,
            string.format("if [ \"%s\" = 1 ]; then",
                          emitUtil.derefLocation(location)))
        emitBlock(indent, ast[2], config, stack, lines)
        util.addLine(indent, lines, "else")
        emitIf(indent, tableSlice(ast, 3, nil, 1), config, stack, lines)
        util.addLine(indent, lines, "true", "to prevent empty stmt block")
        util.addLine(indent, lines, "fi")
    end
end

-- should completely be eliminated before the emit process
-- begins. This shall be realized as a additional compiler pass
-- that modifies the AST directly
function emitter.emitForIn(indent, ast, config, stack, lines)
    -- TODO:
end

-- TODO: nil?
function emitter.emitWhile(indent, ast, config, stack, lines)
    local loopExpr = ast[1]
    local loopBlock = ast[2]
    -- only the first tempValue is significant
    local tempValue = emitExpression(indent, loopExpr, config, stack, lines)[1]
    local simpleValue = emitTempVal(indent, config, lines,
                                    emitUtil.derefValToType(tempValue),
                                    emitUtil.derefValToValue(tempValue), true)
    util.addLine(indent, lines, string.format(
                "while [ \"${%s}\" != 0 ]; do",
                simpleValue))
    emitBlock(indent, loopBlock, config, stack, lines)
    -- recalculate expression for next loop
    local tempValue2 = emitExpression(indent, loopExpr, config, stack, lines)[1]
    util.addLine(indent, lines, string.format("eval %s=%s",
                                         simpleValue,
                                         emitUtil.derefValToValue(tempValue2)))
    util.addLine(indent, lines, "true", "to prevent empty block")
    util.addLine(indent, lines, "done")
end

function emitter.emitRepeat(indent, ast, config, stack, lines)
    -- TODO:
end

function emitter.emitBreak(indent, ast, config, stack, lines)
    util.addLine(indent, lines, "break;")
end

function emitter.emitStatement(indent, ast, config, stack, lines)
    if ast.tag == "Call" then
        emitter.emitCall(indent, ast, config, stack, lines)
    -- HACK: This was used to "Simplify implementation"
    elseif ast.tag == "SPECIAL" then
        util.addLine(indent, lines, ast.special)
    elseif ast.tag == "Fornum" then
        emitter.emitFornum(indent, ast, config, stack, lines)
    elseif ast.tag == "Local" then
        emitter.emitLocal(indent, ast, config, stack, lines)
    elseif ast.tag == "ForIn" then
        emitter.emitForIn(indent, ast, config, stack, lines)
    elseif ast.tag == "Repeat" then
        emitter.emitRepeat(indent, ast, config, stack, lines)
    elseif ast.tag == "If" then
        emitter.emitIf(indent, ast, config, stack, lines)
    elseif ast.tag == "Break" then
        emitter.emitBreak(indent, ast, config, stack, lines)
    elseif ast.tag == "While" then
        emitter.emitWhile(indent, ast, config, stack, lines)
    elseif ast.tag == "Do" then
        util.addLine(indent, lines, "# do ")
        emitter.emitBlock(indent, ast, config, stack, lines)
        util.addLine(indent, lines, "# end ")
    elseif ast.tag == "Set" then
        emitter.emitSet(indent, ast, config, stack, lines)
    end
end

function emitter.emitLocal(indent, ast, config, stack, lines)
    -- functions
    -- local vars
    local topScope = stack:top()
    local varNames = {}
    for i = 1, #ast[1] do
        varNames[i] = ast[1][i][1]
    end
    local locations = emitter.emitExplist(indent, ast[2], config, stack, lines)
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
            emitVarUpdate(
                indent, lines,
                symbol:getEmitVarname(),
                symbol:getCurSlot(),
                emitUtil.derefValToValue(location),
                emitUtil.derefValToType(location))
        elseif someWhereDefined and (symScope == stack:top()) then
            symbol:replaceBy(
                scope.getNewLocalSymbol(
                    config, stack, varName))
            emitVarUpdate(
                indent, lines,
                symbol:getEmitVarname(),
                symbol:getCurSlot(),
                emitUtil.derefValToValue(location),
                emitUtil.derefValToType(location))
        else
            symbol = scope.getNewLocalSymbol(config, stack, varName)
            stack:top():getSymbolTable():addNewSymbol(symbol, varName)
            emitUtil.emitVarUpdate(
                indent, lines,
                symbol:getEmitVarname(),
                symbol:getCurSlot(),
                emitUtil.derefValToValue(location),
                emitUtil.derefValToType(location))
        end
    end
end

function emitter.emitSet(indent, ast, config, stack, lines)
    util.addLine(indent, lines, "# " .. serializer.serSet(ast))
    local explist, varlist = ast[2], ast[1]
    local rhsTempresults = emitter.emitExplist(
        indent, explist, config, stack, lines)
    local iterator = util.statefulIIterator(rhsTempresults)
    for k, lhs in ipairs(varlist) do
        if lhs.tag == "Id" then
            emitter.emitSimpleAssign(
                indent, lhs, config, stack, lines, iterator())
        else
            emitter.emitComplexAssign(
                indent, lhs, config, stack, lines, iterator())
        end
    end
end

function emitter.emitSimpleAssign(indent, ast, config, stack, lines, rhs)
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
    emitUtil.emitUpdateGlobVar(
        indent, symbol:getCurSlot(),
        emitUtil.derefValToValue(rhs),
        lines, emitUtil.derefValToType(rhs))
end

-- TODO:
function emitter.emitComplexAssign(lhs, env, lines, rhs)
    local setValue = ee.emitExecutePrefixexp(lhs, env, lines, true)[1]
    emitUtil.emitUpdateGlobVar(
        indent, setValue,
        emitUtil.derefValToValue(rhs),
        lines, emitUtil.derefValToType(rhs))
end

return emitter
