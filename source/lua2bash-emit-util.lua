local util = require("lua2bash-util")
local b = require("bashEdsl")

local emitUtil = {}

-- we can do ((Ex = Ex + 1)) even as first command line because
-- bash will use 0 as value for Ex if the variable is not declared.
function emitUtil.emitEnvCounter(indent, config, lines, envId)
    util.addLine(
        indent, lines,
        emitUtil.getLineIncrementVar(
            config.environmentPrefix .. envId,
            config.environmentPrefix .. envId):render(),
        "environment counter for closures")
end

function emitUtil.getLineIncrementVar(varId, increment)
    return
        b.eval(
        b.parentheses(
            b.parentheses(
                varId .. b.string(' = ')
                    .. varId .. b.string(' + ') .. increment
            ):sameAsSubtree()
        ):sameAsSubtree())
        :evalMin(0)
        :evalThreshold(1)
end

function emitUtil.emitLocalVarUpdate(indent, lines, symbol)
    util.addLine(
        indent, lines,
        b.e(
            symbol:getEmitVarname() .. b.s("=")
                .. symbol:getCurSlot())())
end

-- TODO: rewrite using emitVarAssignVal
function emitUtil.emitVar(indent, symbol, lines)
    util.addLine(
        indent, lines,
        b.e(
            symbol:getEmitVarname()
                .. b.s("=")
                .. symbol:getCurSlot()
        ):eM(1)())
end

function emitUtil.getLineUpdateVar(indent, symbol, valueslot, lines)
    local assigneeSlot = symbol:getCurSlot()
    local valueSlot = valueslot

    util.addLine(
        indent, lines,
        b.e(
            b.s(lcl .. ' ') .. symbol:getCurSlot()
                .. b.s("=")
                .. b.p(
                    b.dQ(emitUtil.derefValToValue(valueslot))
                        .. b.s(" ")
                        .. emitUtil.derefValToType(valueslot)):sL(-1)
        ):eT(1)())
end

function emitUtil.getEnvVar(config, stack)
    return b.pE(config.environmentPrefix .. stack:top():getEnvironmentId())
end

function emitUtil.getTempAssigneeSlot(config)
    local assigneeSlot = b.s(config.tempValPrefix) .. b.s("_")
        .. b.s(config.counter.tempval())
    return assigneeSlot
end

-- typ and content must be values from bash EDSL
function emitUtil.getLineTempVal(assigneeSlot, value, valtype, mtab)
    local line = emitUtil.getLineValAssignTuple(
        assigneeSlot,
        emitUtil.getValTuple(value, valtype, mtab)
            :noDependentQuoting())
    return line
end

-- returns a b.parentheses object which encloses the value
-- the type and the metatable
function emitUtil.getValTuple(value, valuetype, metatable)
    local quoting = util.max(
        value:getQuotingIndex(),
        util.max(
            valuetype:getQuotingIndex(),
            metatable:getQuotingIndex()))
    return
        b.parentheses(
            -- the double quotes of value must be resolved last
            b.doubleQuotes(content):setQuotingIndex(quoting)
                .. b.string(" ")
                .. valtype
                .. b.string(" ")
                .. mtab)
end

-- assembles a properly quotet line in the form of
-- { "eval " } <varid> "=" <valueid>
function emitUtil.getLineVarAssignVal(varId, valId)
    return
        b.e(varId .. b.s('=') .. valId)
            :evalMin(varId:getQuotingIndex())
            :evalThreshold(1)
end

-- assembles a properly quoted line in the form of
-- { "eval " } "local " <valueid> "=" "(" <value> " " <type> " " <metatable> ")"
function emitUtil.getLineValAssignTuple(assigneeSlot, valueTuple)
    return
        b.e(
            assigneeSlot
                .. b.s('=')
                .. valueTuple)
        :evalMin(assigneeSlot:getQuotingIndex())
        :evalThreshold(1)
end

function emitUtil.derefVarToValue(varname)
    return b.pE(b.s("!") .. varname)
end

function emitUtil.derefVarToType(varname)
    return b.pE(b.pE(varname) .. b.s("[1]"))
end

function emitUtil.derefVarToMtab(varname)
    return b.pE(b.pE(varname) .. b.s("[2]"))
end

function emitUtil.derefValToValue(valuename)
    return b.pE(valuename)
end

function emitUtil.derefValToType(valname)
    return b.pE(valname .. b.s("[1]"))
end

function emitUtil.derefValToMtab(valname)
    return b.pE(valname .. b.s("[2]"))
end

function emitUtil.linearizePrefixTree(ast, result)
    local result = result or {}
    if type(ast) ~= "table" then
        return result
    end
    if ast.tag == "Id" then
        result[#result + 1] =
            { id = ast[1],
              typ = ast.tag,
              exp = nil,
              ast = ast }
    elseif ast.tag == "Paren" then
        result[#result + 1] =
            { typ = ast.tag,
              exp = ast[1],
              ast = ast }
    elseif ast.tag == "Call"  then
        result[#result + 1] =
            { callee = ast[1],
              typ = ast.tag,
              exp = util.tableSlice(ast, 2, #ast, 1),
              ast = ast }
    elseif ast.tag == "Index" then
        result[#result + 1] =
            { indexee = ast[1],
              typ = ast.tag,
              exp = ast[2],
              ast = ast }
    end
    if ast.tag ~= "Id" then
        emitUtil.linearizePrefixTree(ast[1], result)
    end
    return util.tableReverse(result)
end

return emitUtil
