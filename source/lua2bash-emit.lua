local datatypes = require("lua2bash-datatypes")
local util = require("lua2bash-util")
local scope = require("lua2bash-scope")
local serializer = require("lua2bash-serialize-ast")
local b = require("bashEdsl")
local parser = require("lua-parser.parser")
local emitUtil = require("lua2bash-emit-util")

local emitter = {}

function emitter.emitId(indent, ast, config, stack, lines)
    if ast.tag ~= "Id" then
        print("emitId(): not an Id node")
        os.exit(1)
    end
    local varname = ast[1]
    local binding = scope.getMostCurrentBinding(stack, varname)
    -- undefined id's are expected to evaluate to nil
    if binding == nil then
        -- Use global VARNIL!
        return emitter.emitNil(indent, {tag = "Nil"}, config, stack, lines)
    end
    local emitVn = binding.symbol:getEmitVarname()
    local tempSlot = emitUtil.getTempAssigneeSlot(config)
    local cmdline = emitUtil.getLineTempVal(
        tempSlot,
        emitUtil.derefVarToType(emitVn),
        emitUtil.derefVarToValue(emitVn),
        emitUtil.derefVarToMtab(emitVn))
    util.addLine(indent, lines, cmdline:render())
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitNumber(indent, ast, config, stack, lines)
    local value = tostring(ast[1])
    if ast.tag ~= "Number" then
        print("emitNumber(): not a Number node")
        os.exit(1)
    end
    local tempSlot = emitUtil.getTempAssigneeSlot(config)
    local cmdline = emitUtil.getLineTempVal(
        tempSlot,
        b.s(value), b.s('NUM'), b.s(config.defaultMtabNumbers))
    util.addLine(indent, lines, cmdline:render())
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitNil(indent, ast, config, stack, lines)
    if ast.tag ~= "Nil" then
        print("emitNil(): not a Nil node")
        os.exit(1)
    end
    local tempSlot = emitUtil.getTempAssigneeSlot(config)
    local cmdline = emitUtil.getLineTempVal(
        tempSlot,
        b.s(''), b.s('NIL'), b.s(config.defaultMtabNil))
    util.addLine(indent, lines, cmdline:render())
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitString(indent, ast, config, stack, lines)
    local value = ast[1]
    if ast.tag ~= "String" then
        print("emitString(): not a string node")
        os.exit(1)
    end
    local tempSlot = emitUtil.getTempAssigneeSlot(config)
    local cmdline = emitUtil.getLineTempVal(
        tempSlot,
        b.s(value), b.s('STR'), b.s(config.defaultMtabStr))
    util.addLine(indent, lines, cmdline:render())
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitFalse(indent, ast, config, stack, lines)
    if ast.tag ~= "False" then
        print("emitFalse(): not a False node!")
        os.exit(1)
    end
    local tempSlot = emitUtil.getTempAssigneeSlot(config)
    local cmdline = emitUtil.getLineTempVal(
        tempSlot,
        b.s('0'), b.s('0'), b.s(config.defaultMtabStr))
    util.addLine(indent, lines, cmdline:render())
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitTrue(indent, ast, config, stack, lines)
    if ast.tag ~= "True" then
        print("emitTrue(): not a True node!")
        os.exit(1)
    end
    local tempSlot = emitUtil.getTempAssigneeSlot(config)
    local cmdline = emitUtil.getLineTempVal(
        tempSlot,
        b.s('1'), b.s('1'), b.s(config.defaultMtabStr))
    util.addLine(indent, lines, cmdline:render())
    return datatypes.Either():makeLeft(tempSlot)
end

function emitter.emitTableValue(indent, config, lines, tblIdx, value, typ)
    local typeString = b.s(config.skalarTypes.tableType)
    local valueName = b.s(config.tablePrefix) .. b.s(tblIdx)
    local cmdline =
        b.e(
            valueName
                .. b.s("=")
                .. b.p((value or valueName)
                        .. b.s(" ")
                        .. (typ or typeString)))
    util.addLine(indent, lines, cmdline())
    return datatypes.Either():makeLeft(valueName)
end

-- prefixes each table member with env.tablePrefix
function emitter.emitTable(indent, ast, config, stack, lines, firstCall)
    if ast.tag ~= "Table" then
        print("emitTable(): not a Table!")
        os.exit(1)
    end
    if firstCall == nil then
        util.addLine(indent, lines, "# " .. serializer.serTbl(ast))
    end
    local tableId = config.counter.table()
    local elementCounter = b.s(config.tableElementCounter)
    local incrementCmd = emitUtil.getLineIncrementVar(elementCounter, b.s'1')
    addLine(indent, lines, elementCounter:render() .. " = 0",
            "reset element counter")
    addLine(indent, lines, incrementCmd:render())
    emitter.emitTableValue(indent, config, stack, lines, tableId)
    for _, v in ipairs(ast) do
        local fieldExp = v
        if (v.tag == "Pair") then
            print("Associative tables not yet supported")
            os.exit(1)
        elseif v.tag ~= "Table" then
            local either = emitter.emitExpression(
                indent, fieldExp, config, stack, lines)
            assert(type(either) == "table" and either.getType ~= nil,
                   "Must be an either")
            if either:isLeft() then
                emitter.emitTableValue(
                    indent, config, stack,
                    lines, tableId,
                    emitUtil.derefValToValue(either:getLeft()),
                    emitUtil.derefValToType(either:getLeft()))
            else
                -- TODO: case where a function was called!
            end
        else
            local either = emitter.emitTable(
                indent, fieldExp, config, stack, lines, false)
            assert(type(either) == "table" and either.getType ~= nil,
                   "Must be an either")
            assert(either:isLeft(), "Impossible state")
                emitter.emitTableValue(
                    indent, config, stack,
                    lines, tableId,
                    emitUtil.derefValToValue(either:getLeft()),
                    emitUtil.derefValToType(either:getRight()))
        end
    end
    return datatypes.Either():makeLeft(b.s(config.tablePrefix .. b.s(tableId)))
end

-- returns a tempvalue of the result
function emitter.emitCallClosure(
        indent, config, lines, closureValue, argValueList)
    local cmdLine =
        b.e(
            emitUtil.derefValToValue(closureValue)
                .. b.s(" ")
                .. emitUtil.derefValToType(closureValue)
                .. b.s(" ")
                .. util.ifold(
                    argValueList,
                    function(arg, accumulator)
                        return
                            accumulator .. b.s' ' .. b.dQ(arg):noDep()
                    end, b.s("")))
    util.addLine(indent, lines, cmdLine())
    return datatypes.Either():makeRight("dummy")
end

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
        -- TODO: table!
        local typeStrValue = emitUtil.emitTempVal(
            indent, config, stack, lines, b.s("STR"),
            emitUtil.derefValToType(tempValues[1]))
        return { typeStrValue }
    else
        -- TODO: table
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
    local newScope = datatypes.Scope(
        datatypes.occasions.FUNCTION, scopeName,
        config.counter.scope(), scope.getPathPrefix(stack) .. scopeName)
    stack:push(newScope)
    local newEnv = stack:top():getScopeId()
    -- temporary set to old for snapshotting
    stack:top():setScopeId(oldEnv)
    util.addLine(indent, lines, "# Closure defintion")
    local tempVal =
        emitUtil.emitTempVal(
            indent, config, stack, lines,
            b.pE("E" .. stack:top():getScopeId()),
            -- adjust symbol string?
            b.s("BF") .. b.s(tostring(functionId)))
    util.addLine(indent, lines, "# Environment Snapshotting")
    emitter.snapshotEnvironment(indent, ast, config, stack, lines)
    -- set again to new envid
    stack:top():setEnvironmentId(newEnv)
    -- translate to bash function including environment set code
    util.addLine(indent, lines, string.format("function BF%s {", functionId))
    util.addLine(
        indent, lines, (b.s("E") .. b.s(tostring(oldEnv))
                            .. b.s("=") .. b.pE("1"))())
    emitter.transferFuncArguments(indent, namelist, config, stack, lines)
    -- recurse into block
    emitter.emitBlock(indent, block, config, stack, lines)
    -- TODO: needed???
    --    util.addLine(
    --        indent, lines,
    --        string.format("%s=$1", "E" .. stack:top():getScopeId()))
    -- end of function definition
    emitter.emitReturn(indent, {{tag = "Nil"}}, config, stack, lines)
    util.addLine(indent, lines, "}")
    stack:pop()
    return { tempVal }
end

function emitter.transferFuncArguments(indent, ast, config, stack, lines)
    local namelist, counter = ast, 2
    util.imap(ast,
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
    if #ast == 3 then return emitter.emitBinop(indent, ast, config, stack, lines)
    elseif #ast == 2 then return emitter.emitUnop(indent, ast, config, stack, lines)
    else
        print("Not supported!")
        os.exit(1)
    end
end

function emitter.emitUnop(indent, ast, config, stack, lines)
    local right = emitter.emitExpression(
        indent, ast[2], config, stack, lines)[1]
    local tempVal = emitter.getTempValname(config, stack, false)
    util.addLine(
        indent, lines,
        b.e(
            tempVal
                .. b.s("=")
                .. b.s("\\(")
                .. b.aE(
                    b.s(util.strToOpstr(ast[1])) ..
                        emitUtil.derefValToValue(right))
                .. b.s(" ")
                .. emitUtil.derefValToType(right)
                .. b.s("\\)"))())
    return { tempVal }
end

util.operator = {
        add = function(x, y) return x + y end,
        sub = function(x, y) return x - y end,
        equ = function(x, y) return x == y end,
        neq = function(x, y) return x ~= y end
}

function util.exists(tbl, value, comparator)
    local result = false
    for _, v in pairs(tbl) do
        result = result or comparator(v, value)
    end
    return result
end

function emitter.emitBinop(indent, ast, config, stack, lines)
    local ergId1 = util.getUniqueId()
    local tempVal = emitter.getTempValname(config, stack)
    local left = emitter.emitExpression(
        indent, ast[2], config, stack, lines)[1]
    local right = emitter.emitExpression(
        indent, ast[3], config, stack, lines)[1]
    local valuePart, typePart
    valuePart =
        b.aE(
            emitUtil.derefValToValue(left) ..
                b.s(util.strToOpstr(ast[1])):sQ(
                    util.max(
                        emitUtil.derefValToValue(left)
                            :getQuotingIndex(),
                        emitUtil.derefValToValue(right)
                            :getQuotingIndex())) ..
                emitUtil.derefValToValue(right))
    typePart =
        util.expIfStrict(
            util.exists(
                {"==", "<", ">", "<=", ">=", "<<", ">>"},
                util.strToOpstr(ast[1]),
                util.operator.equ),
            valuePart,
            emitUtil.derefValToType(right))
    -- finally constructing the command line
    util.addLine(
        indent, lines,
        b.e(
            tempVal
                .. b.s("=")
                .. b.p(valuePart .. b.s(" ") .. typePart):noDep() )())
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
            util.imap(
                tempValues,
                function(v)
                    return emitUtil.emitTempVal(
                        indent, config, stack, lines,
                        emitUtil.derefValToType(v),
                        emitUtil.derefValToValue(v)) end)
        util.tableIAddInplace(locations, tempVnRhs)
    end
    return locations
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
    return { temp[#temp] }
end

function emitter.emitBootstrap(indent, config, stack, lines)
    util.addLine(indent, lines, "# Bootstrapping code")
    emitUtil.emitValAssignTuple(
        indent, "VAL" .. config.nilVarName,
        b.p(b.dQ(""):sL(-1) .. b.s' ' .. b.s'NIL'),
        lines)
    emitUtil.emitValAssignTuple(
        indent, "VALRET",
        b.p(b.dQ(""):sL(-1) .. b.s' ' .. b.s'NIL'), lines)
end

-- TODO: should not handle scopes!
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
                   lines, stack:top():getScopeId())
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
        emitter.emitBlock(
            indent + config.indentSize,
            ast[1], config, stack, lines,
            datatypes.occasions.IF)
    elseif #ast > 1 then
        -- calculate expression
        local tempValue = emitter.emitExpression(
            indent, ast[1], config, stack, lines)[1]
        local resultType = emitter.emitTypelessScalar(
            indent, config, stack, lines, emitUtil.derefValToType(tempValue))
        --dbg()
        util.addLine(
            indent, lines,
            string.format(
                "if [ %s != NIL -a %s != \"0\" ]; then",
                b.pE(resultType)(), b.pE(resultType)()))
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

function emitter.emitTypelessScalar(indent, config, stack, lines, content)
    local tempVal = emitter.getTempValname(config, stack, true)
    local cmdLine = b.e(tempVal .. b.s("=") .. b.dQ(content)):eM(1)
    util.addLine(indent, lines, cmdLine())
    return tempVal
end

-- TODO: nil?
function emitter.emitWhile(indent, ast, config, stack, lines)
    local loopExpr = ast[1]
    local loopBlock = ast[2]
    -- only the first tempValue is significant
    local tempValue = emitter.emitExpression(
        indent, loopExpr, config, stack, lines)[1]
    local resultType = emitter.emitTypelessScalar(
        indent, config, stack, lines, emitUtil.derefValToType(tempValue))
    --dbg()
    util.addLine(
        indent, lines,
        string.format(
            "while [ %s != NIL -a %s != \"0\" ]; do",
            b.pE(resultType)(), b.pE(resultType)()))
    emitter.emitBlock(indent, loopBlock, config, stack, lines)
    -- recalculate expression for next loop
    local tempValue2 = emitter.emitExpression(
        indent, loopExpr, config, stack, lines)[1]
    util.addLine(
        indent, lines,
        b.e(
            resultType
                .. b.s("=")
                .. emitUtil.derefValToType(tempValue2))())
    util.addLine(indent, lines, "true", "to prevent empty block")
    util.addLine(indent, lines, "done")
end

function emitter.emitRepeat(indent, ast, config, stack, lines)
    -- TODO:
end

function emitter.emitBreak(indent, ast, config, stack, lines)
    util.addLine(indent, lines, "break;")
end

-- TODO: This is a limitation. Only one return expression is
-- allowed right now. I think there is a solution. However, I also
-- think that it's implementation will require far-reaching modifications.
function emitter.emitReturn(indent, ast, config, stack, lines)
    util.addLine(indent, lines, "# " .. serializer.serRet(ast))
    local firstExpression = ast[1]
    local tempVal = emitter.emitExpression(
        indent, firstExpression, config, stack, lines)[1]
    local cmdline =
        b.e(
            b.s'VALRET' .. b.s'=' ..
                b.p(
                    emitUtil.derefValToValue(tempVal)
                        .. b.s' '
                        .. emitUtil.derefValToType(tempVal)):noDep())
    util.addLine(indent, lines, cmdline(), "Set return value")
    util.addLine(indent, lines, "return 0", "Finish exec of this function")
    return returnLocation
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
    elseif ast.tag == "Return" then
        emitter.emitReturn(indent, ast, config, stack, lines)
    elseif ast.tag == "Set" then
        emitter.emitSet(indent, ast, config, stack, lines)
    end
end

function emitter.emitLocal(indent, ast, config, stack, lines)
    util.addLine(indent, lines, "# " .. serializer.serLcl(ast))
    local topScope = stack:top()
    local varNames = {}
    for i = 1, #ast[1] do
        varNames[i] = ast[1][i][1]
    end
    local locations =
        emitter.emitExplist(indent, ast[2], config, stack, lines)
    local memNumDiff =
        util.tblCountAll(varNames) - util.tblCountAll(locations)
    if memNumDiff > 0 then -- extend number of expressions to fit varNamelist
        for i = 1, memNumDiff do
            locations[#locations + 1] = { b.s("VAR_NIL") }
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
        if someWhereDefined and (symScope == stack:top()) then
            symbol:replaceBy(
                scope.getUpdatedSymbol(
                    config, stack, symbol, varName))
            emitUtil.emitLocalVarUpdate(indent, lines, symbol)
            emitUtil.emitUpdateVar(indent, symbol, location, lines)
--        elseif someWhereDefined and (symScope ~= stack:top()) then
--            symbol:replaceBy(
--                scope.getUpdatedSymbol(
--                    config, stack, symbol, varName))
--            emitVarUpdate(
--                indent, lines,
--                symbol:getEmitVarname(),
--                symbol:getCurSlot(),
--                emitUtil.derefValToValue(location),
--                emitUtil.derefValToType(location))
        else
            symbol = scope.getNewLocalSymbol(config, stack, varName)
            stack:top():getSymbolTable():addNewSymbol(varName, symbol)
            emitUtil.emitVar(indent, symbol, lines)
            emitUtil.emitUpdateVar(indent, symbol, location, lines)
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
        symbol = bindingQuery.symbol
    else
        symbol = scope.getGlobalSymbol(config, stack, varName)
        stack:bottom():getSymbolTable():addNewSymbol(varName, symbol)
        emitUtil.emitVar(indent, symbol, lines)
    end
    emitUtil.emitUpdateVar(indent, symbol, rhs, lines)
end

function emitter.emitComplexAssign(indent, lhs, config, stack, lines, rhs)
    local setValue = emitter.emitExecutePrefixexp(
        indent, lhs, config, stack, lines, true)[1]
    local tempSym = datatypes.Symbol():setCurSlot(setValue)
    emitUtil.emitUpdateVar(indent, tempSym, rhs, lines)
end

return emitter
