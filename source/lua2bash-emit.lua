local datatypes = require("lua2bash-datatypes")
local util = require("lua2bash-util")
local scope = require("lua2bash-scope")
local serializer = require("lua2bash-serialize-ast")
local b = require("bashEdsl")
local parser = require("lua-parser.parser")
local emitUtil = require("lua2bash-emit-util")

local emitter = {}

function emitter.emitId(indent, ast, config, stack, lines)
    util.assertAstHasTag(ast, "Id")
    local varname = ast[1]
    local binding = scope.getMostCurrentBinding(stack, varname)
    -- undefined id's are expected to evaluate to nil
    if binding == nil then
        -- Use global VARNIL!
        return emitter.emitNil(indent, {tag = "Nil"}, config, stack, lines)
    end
    local emitVn = binding.symbol:getEmitVarname()
    local tempSlot = emitUtil.emitTempVal(
        indent, config, lines,
        emitUtil.derefVarToType(emitVn),
        emitUtil.derefVarToValue(emitVn),
        emitUtil.derefVarToMtab(emitVn))
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitNumber(indent, ast, config, stack, lines)
    local value = tostring(ast[1])
    util.assertAstHasTag(ast, "Number")
    local tempSlot = emitUtil.emitTempVal(
        indent, config, lines,
        b.string(value), b.string(config.skalarTypes.numberType),
        b.string(config.defaultMtabNumbers))
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitNil(indent, ast, config, _, lines)
    util.assertAstHasTag(ast, "Nil")
    local tempSlot = emitUtil. emitUtil.emitTempVal(
        indent, config, lines,
        b.string(''), b.string(config.skalarTypes.nilType),
        b.string(config.defaultMtabNil))
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitString(indent, ast, config, _, lines)
    local value = ast[1]
    util.assertAstHasTag(ast, "String")
    local tempSlot = emitUtil.emitTempVal(
        indent, config, lines,
        b.string(value), b.string(config.skalarTypes.stringType),
        b.string(config.defaultMtabStr))
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitFalse(indent, ast, config, _, lines)
    util.assertAstHasTag(ast, "False")
    local tempSlot = emitUtil.emitTempVal(
        indent, config, lines,
        b.string('0'), b.string('0'), b.string(config.defaultMtabStr))
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitTrue(indent, ast, config, _, lines)
    util.assertAstHasTag(ast, "True")
    local tempSlot = emitUtil.emitTempVal(
        indent, config, lines,
        b.string('1'), b.string('1'), b.string(config.defaultMtabStr))
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitTableValue(
        indent, config, lines, tblIdx, value, valuetype, metatable)
    local elementCounter = b.string(config.tableElementCounter)
    local incrementCmd = emitUtil.Incrementer(elementCounter, b.s'1')
    local typeString = b.string(config.skalarTypes.tableType)
    local slot =
        b.string(config.tablePrefix) .. tblIdx
        .. b.paramExpansion(config.tableElementCounter)
    local cmdline =
        emitUtil.getLineAssign(
            slot, value or slot, valuetype or typeString, metatable)
    util.addLine(indent, lines, cmdline:render())
    util.addLine(indent, lines, incrementCmd:render())
    return datatypes.Either():makeLeft(slot)
end

function emitter.emitResetTableECounter(indent, config, lines)
    local elementCounter = b.s(config.tableElementCounter)
    util.addLine(
        indent, lines, elementCounter:render() .. "=0",
        "reset element counter")
end

-- prefixes each table member with env.tablePrefix
function emitter.emitTable(indent, ast, config, stack, lines, firstCall)
    util.assertAstHasTag(ast, "Table")
    local tableId = b.string(config.counter.table())
    local tableValue = b.string(config.tablePrefix) .. b.string(tableId)
    local tableCounterInc = emitUtil.Incrementer(config.tableElementCounter, 1)
    local fieldExpressions = ast
    if firstCall == nil then
        util.addComment(indent, lines, serializer.serTbl(ast))
    end
    emitter.emitResetTableECounter(indent, config, lines)
    emitter.emitTableValue(
        indent, config, lines, tableId,
        tableValue,
        b.s(config.skalarTypes.tableType),
        b.s(config.defaultMtabTables))
    -- recurse into ast
    for _, fieldExp in ipairs(fieldExpressions) do
        if fieldExp.tag == "Pair" then
            print("Associative tables not yet supported")
            os.exit(1)
        elseif fieldExp.tag ~= "Table" then
            local fieldIndex = tableId
                .. b.paramExpansion(config.tableElementCounter)
            local either1orN = emitter.emitExpression(
                indent, fieldExp, config, stack, lines)
            -- cases when single or multiple values result from
            -- the evaluation of an expression
            if either1orN:isLeft() then
                util.addLine(indent, lines, tableCounterInc:render())
                emitter.emitTableValue(
                    indent, config, stack, lines, fieldIndex,
                    emitUtil.derefValToValue(either1orN:getLeft()),
                    emitUtil.derefValToType(either1orN:getLeft()),
                    emitUtil.derefValToMtab(either1orN:getLeft()))
            else
                print("TODO!!!")
                -- TODO: case where a function was called!
            end
        else
            local subTable = emitter.emitTable(
                indent, fieldExp, config, stack, lines, false)
            emitter.emitTableValue(
                indent, config, stack, lines, tableId,
                emitUtil.derefValToValue(subTable:getLeft()),
                emitUtil.derefValToType(subTable:getLeft()),
                emitUtil.derefValToMtab(subTable:getLeft()))
        end
    end
    return datatypes.Either():makeLeft(tableValue)
end

-- returns a tempvalue of the result
function emitter.emitCallClosure(
        indent, config, lines, closureValue, argValueList)
    local cmdLine =
        b.eval(
            emitUtil.derefValToValue(closureValue)
                .. b.string(" ")
                .. emitUtil.derefValToType(closureValue)
                .. b.string(" ")
                .. util.ifold(
                    argValueList,
                    function(arg, accumulator)
                        return
                            accumulator .. b.string(' ')
                            .. b.doubleQuote(arg):noDep()
                    end, b.string("")))
    util.addLine(indent, lines, cmdLine:render())
    return datatypes.Either():makeRight(
        emitUtil.emitSimpleTempValue(
            indent, config, lines,
            b.pE(config.bootstrap.retVarName)))
end

-- TODO: Marker
function emitter.emitCall(indent, ast, config, stack, lines)
    util.addComment(indent, lines, serializer.serCall(ast))
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
                b.s('t'):sQ(3)())
        util.addLine(
            indent, lines,
            b.e(b.s'echo -e ' .. dereferenced)
                :evalMin(0)
                :evalThreshold(1)
                :render()
        )
        return {}
    elseif functionName == "type" then
        local typeStrValue = emitUtil.emitTempVal(
            indent, config, stack, lines, b.s("STR"),
            emitUtil.derefValToType(tempValues[1]))
        return { typeStrValue }
    else
        local funcValue = emitter.emitExpression(
            indent, functionExp, config, stack, lines)[1]
        return emitter.emitCallClosure(
            indent, config, lines, funcValue, tempValues)
    end
end

-- snapshots all ids that already exist in the symbol tables
-- with the exception of the global scope.
-- otherwise direct recursions would not be possible
function emitter.snapshotEnvironment(indent, ast, config, stack, lines)
    local usedSyms = util.getUsedSymbols(ast)
    local validSymbols = util.filter(
        usedSyms,
        function(sym)
            local query = scope.getMostCurrentBinding(stack, sym)
            if query == nil then
                return false
            else
                if query.scope == stack:bottom() then
                    return false
                else
                    return true
                end
            end
    end)
    --dbg()
    return util.imap(
        validSymbols,
        function(sym)
            local assignmentAst = parser.parse(
                string.format("local %s = %s;", sym, sym))
            -- we only need the local ast not the block surrounding it
            return emitter.emitLocal(
                indent, assignmentAst[1], config, stack, lines)
    end)
end

function emitter.emitFunction(indent, ast, config, stack, lines)
    local namelist = ast[1]
    local block = ast[2]
    local functionId = config.counter.func()
    local oldEnv = stack:top():getScopeId()
    local scopeName = "F" .. functionId
    local environmentPtrSetter = b.s("E") .. b.s(oldEnv) .. b.s("=") .. b.pE("1")
    local newScope = datatypes.Scope(
        datatypes.occasions.FUNCTION, scopeName,
        config.counter.scope(), scope.getPathPrefix(stack) .. scopeName)
    stack:push(newScope)
    local newEnv = stack:top():getScopeId()
    -- temporary set to old for snapshotting
    stack:top():setScopeId(oldEnv)
    local closureAssignment =
        emitUtil.emitLineAssign(
            emitUtil.getTempAssigneeSlot(config),
            b.s('BF') .. b.s(functionId),
            b.paramExpansion('E' .. stack:top():getScopeId()),
            b.string(''))
    util.addLine(indent, lines, closureAssignment:render() ,"Closure defintion")
    util.addComment(indent, lines, "Environment Snapshotting")
    emitter.snapshotEnvironment(indent, ast, config, stack, lines)
    -- set again to new envid
    stack:top():setEnvironmentId(newEnv)
    -- translate to bash function including environment set code
    util.addLine(indent, lines, string.format("function BF%s {", functionId))
    util.addLine(indent, lines, environmentPtrSetter:render(), "Env pointer")
    emitter.transferFuncArguments(indent, namelist, config, stack, lines)
    -- recurse into block
    emitter.emitBlock(indent, block, config, stack, lines)
    -- TODO: needed???
    --    util.addLine(
    --        indent, lines,
    --        string.format("%s=$1", "E" .. stack:top():getScopeId()))
    -- end of function definition
    util.addComment(indent, lines, "Dummy return")
    emitter.emitReturn(indent, {{tag = "Nil"}}, config, stack, lines)
    util.addLine(indent, lines, "}", "of BF" .. functionId)
    stack:pop()
    return { tempVal }
end

function emitter.transferFuncArguments(indent, ast, config, stack, lines)
    local namelist, counter = ast, 2
    util.imap(
        namelist,
        function(name)
            local varName = name[1]
            local tempSym = scope.getNewLocalSymbol(config, stack, varName)
            stack:top():getSymbolTable():addNewSymbol(varName, tempSym)
            emitUtil.emitVar(indent, tempSym, lines)
            emitUtil.emitUpdateVar(
                indent, tempSym,
                b.pE(tostring(counter) .. b.s':-VALVARNIL'),
                lines)
            counter = counter + 1
    end)
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
        print("emitExpresison(): error!" .. ast.tag)
        os.exit(1)
    end
end

function emitter.emitOp(indent, ast, config, stack, lines)
    if #ast == 3 then
        return emitter.emitBinop(indent, ast, config, stack, lines)
    elseif #ast == 2 then
        return emitter.emitUnop(indent, ast, config, stack, lines)
    else
        print("Not supported!")
        os.exit(1)
    end
end

function emitter.emitUnop(indent, ast, config, stack, lines)
    local right = emitter.emitExpression(
        indent, ast[2], config, stack, lines)[1]
    local tempVal = emitTempVal(
        indent, config, lines,
        b.arithExpansion(
            b.string(util.strToOpstr(ast[1])) ..
                emitUtil.derefValToValue(right)),
        emitUtil.derefValToType(right),
        emitUtil.derefValToMtab(right))
    return datatypes.Either():makeLeft(tempVal)
end

function emitter.emitBinop(indent, ast, config, stack, lines)
    local left = emitter.emitExpression(
        indent, ast[2], config, stack, lines)[1]
    local right = emitter.emitExpression(
        indent, ast[3], config, stack, lines)[1]
    local valuePart =
        b.aE(
            emitUtil.derefValToValue(left) ..
                b.s(util.strToOpstr(ast[1])):sQ(
                    util.max(
                        emitUtil.derefValToValue(left)
                            :getQuotingIndex(),
                        emitUtil.derefValToValue(right)
                            :getQuotingIndex())) ..
                emitUtil.derefValToValue(right))
    local typePart =
        util.expIfStrict(
            util.exists(
                {"==", "<", ">", "<=", ">=", "<<", ">>"},
                util.strToOpstr(ast[1]),
                util.operator.equ),
            valuePart,
            emitUtil.derefValToType(right))
    -- finally constructing the command line
    local tempVal = emitUtil.emitTempVal(
        indent, config, lines, valuePart, typePart, b.s'')
    return datatypes.Either():makeLeft(tempVal)
end

function emitter.getExpressionEmitters(indent, ast, config, stack, lines)
    local emitters
    local expressions = ast
    if ast.tag ~= "ExpList" then
        print("emitExplist(): not an explist node!")
        os.exit(1)
    end
    emitters = util.imap(
        expressions,
        function(expression)
            return function()
                local tempValue = emitter.emitExpression(
                    indent, expression, config, stack, lines)
                return emitUtil.emitTempVal(
                    indent, config, lines,
                    emitUtil.derefValToType(tempValue),
                    emitUtil.derefValToValue(tempValue),
                    emitUtil.derefValToMtab(tempValue))
            end
        end
    )
    return emitters
end

function emitter.emitPrefixexp(indent, ast, config, stack, lines)
    return emitter.emitExecutePrefixexp(indent, ast, config, stack, lines)
end

--
-- dereferences expressions like getTable()[1]
-- and returns the values to be written to
function emitter.emitExecutePrefixexp(indent, prefixExp, config,
                                      stack, lines, asLval)
    local indirections = emitUtil.linearizePrefixTree(prefixExp)
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
            local id = emitter.emitId(
                indent, indirection.ast, config, stack, lines)[1]
            if id:isLeft() then
                temp[i] = id:getLeft()
            else
                -- TODO: take topmost element from stack
                -- delete any other element
                -- and lay the taken element into temp[i]
            end
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
            index = emitUtil.derefValToValue(temp[i-1])
                .. emitUtil.derefValToValue(index)
            if i == #indirections and asLval then
                temp[i] = index
            else
                temp[i] = emitUtil.emitTempVal(
                    indent, config, stack, lines,
                    b.pE(index .. b.s("[1]")),
                    b.pE(index))
            end
        end
    end
    return datatypes.Either():makeLeft(temp[#temp])
end

-- emits bash code that pops popElements elements
function emitter.emitStackCleanup(popElements)
    -- TODO:
end

function emitter.emitBootstrap(indent, config, _, lines)
    util.addComment(indent, lines, "Bootstrapping code")
    util.addLine(indent, lines, config.bootstrap.stackPointer .. "=0")
    util.addLine(indent, lines, config.bootstrap.retVarName .. "=0")
    emitUtil.emitValAssignTuple(
        indent, "VAL" .. config.bootstrap.nilVarName,
        b.p(b.dQ(""):sL(-1) .. b.s' ' .. b.s'NIL'),
        lines)
end

function emitter.emitScopedBlock(indent, ast, config, stack, lines, occasion)
    occasion = occasion or datatypes.occasions.BLOCK
    local scopeNumber = config.counter.scope()
    local scopeName = "S" .. scopeNumber
    local newScope = datatypes.Scope(
        occasion, scopeName, scopeNumber,
        scope.getPathPrefix(stack) .. scopeName)
    -- push new scope on top
    stack:push(newScope)
    util.addComment(indent, lines, "Begin of Scope: " .. stack:top():getPath())
    emitUtil.emitEnvCounter(indent, config, lines, scopeNumber)
    -- emit all statements
    emitter.emitBlock(indent, ast, config, stack, lines)
    -- pop the scope
    stack:pop()
end

function emitter.emitBlock(indent, ast, config, stack, lines)
    -- emit all enclosed statements
    for _, statement in ipairs(ast) do
        if type(statement) == "table" then
            emitter.emitStatement(indent, statement, config, stack, lines)
        else
            print("emitBlock error!??")
            os.exit(1)
        end
    end
end

-- for v = e1, e2, e3 do block end
-- =>
-- do
--   local var, limit, step = tonumber(e1), tonumber(e2), tonumber(e3)
--   if not (var and limit and step) then error() end
--   var = var - step
--   while true do
--     var = var + step
--     if (step >= 0 and var > limit) or (step < 0 and var < limit) then
--       break
--     end
--     local v = var
--     <block>
--   end
-- end
-- TODO: komplett neu schreiben

local ab = require("lua2bash-ast-builder")
function emitter.elaborateForNum(ast)
    local block = ast[5] or ast[4]

    if #ast == 4 then -- if no increment provided
        ast[5] = ast[4]
        ast[4] = ab.number(1)
    end

    local newAst =
        ab.doStmt(
            ab.localAssignment(
                ab.namelist(
                    ab.id('var'), ab.id('limit'), ab.id('step')
                ),
                ab.explist(
                    ab.
            ))
        )
end

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
        emitter.emitScopedBlock(
            indent + config.indentSize,
            ast[1], config, stack, lines,
            datatypes.occasions.IF)
    elseif #ast > 1 then
        -- calculate expression
        local tempValue = emitter.emitExpression(
            indent, ast[1], config, stack, lines)
        local resultType = emitUtil.emitTempVal(
            indent, config, lines,
            emitUtil.derefValToValue(tempValue),
            emitUtil.derefValToType(tempValue),
            emitUtil.derefValToMtab(tempValue))
        --dbg()
        util.addLine(
            indent, lines,
            string.format(
                "if [ %s != NIL -a %s != 0 ]; then",
                emitUtil.derefValToType(resultType)(),
                emitUtil.derefValToType(resultType)()))
        -- recurse into block
        emitter.emitBlock(indent + config.indentSize, ast[2], config, stack, lines)
        util.addLine(indent, lines, "else")
        emitter.emitIf(
            indent, util.tableSlice(ast, 3, nil, 1), config, stack, lines)
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
    local evaledLoopExpr = emitter.emitExpression(
        indent, loopExpr, config, stack, lines)[1]
    local resultType = emitter.emitTempVal(
        indent, config, stack, lines,
        emitUtil.derefValToType(evaledLoopExpr),
        emitUtil.derefValToType(evaledLoopExpr),
        emitUtil.derefValToMtab(evaledLoopExpr))
    --dbg()
    util.addLine(
        indent, lines,
        string.format(
            "while [ %s != NIL -a %s != 0 ]; do",
            emitUtil.derefValToType(resultType)(),
            emitUtil.derefValToType(resultType)()))
    emitter.emitBlock(indent, loopBlock, config, stack, lines)
    -- recalculate expression for next loop
    local evaledLoopExprNext = emitter.emitExpression(
        indent, loopExpr, config, stack, lines)
    util.addLine(
        indent, lines,
        b.eval(
            resultType
                .. b.string("=")
                .. emitUtil.derefValToType(evaledLoopExprNext))())
    util.addLine(indent, lines, "true", "to prevent empty block")
    util.addLine(indent, lines, "done")
end

function emitter.emitRepeat(indent, ast, config, stack, lines)
    -- TODO:
end

function emitter.emitBreak(indent, _, _, _, lines)
    util.addLine(indent, lines, "break")
end

function emitter.emitPutOnStack(indent, ast, config, tempVal, lines)

end

-- function (x)
--     return x + 1, x + 2, x + 3
-- end
--
-- PUTONTOP=0
-- SP=0
-- STACK${SP}=x+1
-- ((SP++, PUTONTOP++))
-- STACK${SP}=x+2
-- ((SP++, PUTONTOP++))
-- STACK${SP}=x+3
-- ((SP++, PUTONTOP++))
--
-- STACK${SP}=$PUTONTOP
--
-- Optimization possibility:
-- when all expressions in return are static, that is, if it's known
-- how many elements will be put on top of the stack, the stack pointer
-- needs only to be incremented by that amount once
-- i.e. function(x) return 1, 2, 3 end => puts 3 arguments on the stack
-- so the bash code can increment SP by simply doing ((SP+=3, PUTONTOP+=3))
function emitter.emitReturn(indent, ast, config, stack, lines)
    util.addComment(indent, lines, serializer.serRet(ast))
    local returnExpressions = ast
    util.addLine(indent, lines, 'local SPBeforeReturn=$SP')
    local returnIncrementor = emitUtil.Incrementer(
        'SPBeforeReturn', b.string('1'))
    local stackPtrIncrementor = emitUtil.Incrementer(
        config.stackpointer, b.string('1'))
    -- emit instructions
    util.imap(
        returnExpressions,
        function(expr)
            local either = emitter.emitExpression(
                indent, expr, config, stack, lines)
            if either:isLeft() then
                local tempVal = either:getLeft()
                emitter.emitPutOnStack(indent, ast, config, tempVal, lines)
                util.addLine(indent, lines, returnIncrementor:render())
                util.addLine(indent, lines, stackPtrIncrementor:render())
            else
                -- the other function has already put
                -- the values on top of the stack, so here nothing to do
            end
    end)

    util.addLine(indent, lines, "PUTONTOP=$SPBeforeReturn")
    util.addLine(indent, lines, "return 0", "Finish exec of this function")
    return returnLocation
end

function emitter.emitStatement(indent, ast, config, stack, lines)
    if ast.tag == "Call" then
        emitter.emitCall(indent, ast, config, stack, lines)
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
    elseif ast.tag == "Return" then
        emitter.emitReturn(indent, ast, config, stack, lines)
    elseif ast.tag == "Set" then
        emitter.emitSet(indent, ast, config, stack, lines)
    end
end

function emitter.emitLocal(indent, ast, config, stack, lines)
    util.addComment(indent, lines, serializer.serLcl(ast))
    local varNames = {}
    for i = 1, #ast[1] do
        varNames[i] = ast[1][i][1]
    end
    local locations =
        emitter.emitExplist(indent, ast[2], config, stack, lines)
    local memNumDiff =
        util.tblCountAll(varNames) - util.tblCountAll(locations)
    if memNumDiff > 0 then -- extend number of expressions to fit varNamelist
        for _ = 1, memNumDiff do
            locations[#locations + 1] = emitter.emitNil(
                indent, {tag = 'Nil'}, config, stack, lines)
        end
    end
    local iter = util.statefulIIterator(locations)
    for _, varName in pairs(varNames) do
        local bindingQuery = scope.getMostCurrentBinding(stack, varName)
        local someWhereDefined = bindingQuery ~= nil
        local symScope, symbol
        local location = iter()
        if someWhereDefined then
            symScope, symbol = bindingQuery.scope, bindingQuery.symbol
        end
        if someWhereDefined and (symScope == stack:top()) then
            symbol:replaceBy(
                scope.getUpdatedSymbol(
                    config, stack, symbol, varName))
            emitUtil.emitLocalVarUpdate(indent, lines, symbol)
            emitUtil.emitUpdateVar(indent, symbol, location, lines)
        else
            symbol = scope.getNewLocalSymbol(config, stack, varName)
            stack:top():getSymbolTable():addNewSymbol(varName, symbol)
            emitUtil.emitVar(indent, symbol, lines)
            emitUtil.emitUpdateVar(indent, symbol, location, lines)
        end
    end
end

function emitter.emitSet(indent, ast, config, stack, lines)
    util.addComment(indent, lines, serializer.serSet(ast))
    local explist, varlist = ast[2], ast[1]
    local emitters = emitter.getExpressionEmitters(
        indent, explist, config, stack, lines)
    local iterator = util.actionIIterator(emitters, util.call)
    for _, lhs in ipairs(varlist) do
        if lhs.tag == "Id" then
            emitter.emitSimpleAssign(
                indent, lhs, config, stack, lines, iterator())
        else
            emitter.emitComplexAssign(
                indent, lhs, config, stack, lines, iterator())
        end
    end
end

-- takes one expression
function emitter.emitSimpleAssign(indent, lhs, config, stack, lines, rhs)
    local varName = lhs[1]
    local bindingQuery = scope.getMostCurrentBinding(stack, varName)
    local someWhereDefined = bindingQuery ~= nil
    local symbol
    if someWhereDefined then
        symbol = bindingQuery.symbol
    else
        symbol = scope.getGlobalSymbol(config, stack, varName)
        stack:bottom():getSymbolTable():addNewSymbol(varName, symbol)
        emitUtil.emitVar(indent, symbol, lines)
    end
    if rhs:isLeft() then
        local cmdline =
            emitUtil.emitUpdateVar(indent, symbol, rhs:getLeft(), lines)
        util.addLine(indent, lines, cmdline:reneder())
    else
        local numReturned = rhs:getRight()
    end
end

function emitter.emitComplexAssign(indent, lhs, config, stack, lines, rhs)
    local setValue = emitter.emitExecutePrefixexp(
        indent, lhs, config, stack, lines, true)
    local tempSym = datatypes.Symbol():setCurSlot(setValue)
    if rhs:isLeft() then
        emitUtil.emitUpdateVar(indent, tempSym, rhs:getLeft(), lines)
    else
        local numReturned = rhs:getRight()
    end
end

return emitter
