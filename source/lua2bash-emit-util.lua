-- Naming conventions in this file
-- All functions prefixed with emit, actually add code
-- to the command line accumulator (called "lines")
--
-- This file also includes functions creating consistent
-- bash edsl values representing the most basic instructions
-- of the target language.


local util = require("lua2bash-util")
local b = require("bashEdsl")

local emitUtil = {}

-- puts together a bash dsl value evaluating to S<CurrentScopeId>
-- depending on the content of the stack
function emitUtil.getEnvVar(config, stack)
    return b.paramExpansion(config.scopePrefix .. stack:top():getScopeId())
end

-- generates a unique slot name
function emitUtil.getUniqueSlot(config)
    local slot =
        b.string(config.tempValPrefix)
        .. b.string("_")
        .. b.string(config.counter.tempval())
    return slot
end

-- we can do ((Ex = Ex + 1)) even as first command line because
-- bash will use 0 as value for Ex if the variable is not declared.
function emitUtil.emitEnvCounter(indent, config, lines, scopeId)
    util.addLine(
        indent, lines,
        emitUtil.Incrementer(
            config.scopePrefix .. scopeId, '1'):render(),
        "environment counter for closures")
end

-- emits bash edsl value evaluating to ((varId+=increment))
function emitUtil.Incrementer(varId, increment)
    return
        b.eval(
            b.parentheses(
                b.parentheses(
                    varId .. b.string('+=') .. b.string(increment)
                ):sameAsSubtree()
            ):sameAsSubtree())
        :evalMin(0)
        :evalThreshold(1)
end

-- emits bash edsl value evaluating to something like
-- { eval } <varname> = <newslot>
function emitUtil.emitLocalVarUpdate(indent, lines, symbol)
    util.addLine(
        indent, lines,
        emitUtil.VarAssignVal(
            symbol:getEmitVarname(),
            symbol:getCurSlot()):render())
end

-- TODO: possibly superfluous!
function emitUtil.emitVar(indent, symbol, lines)
    util.addLine(
        indent, lines,
        emitUtil.VarAssignVal(
            symbol:getEmitVarname(),
            symbol:getCurSlot()):render())
end

-- outputs
-- { "eval " } symbol:getCurSlot() "=" quotedtuple(value, type, mtab)
function emitUtil.emitUpdateVar(indent, symbol, valueslot, lines)
    local assigneeSlot = symbol:getCurSlot()
    util.addLine(
        indent, lines,
        emitUtil.ValAssignTuple(
            assigneeSlot,
            emitUtil.ValTuple(
                emitUtil.derefValToValue(valueslot),
                emitUtil.derefValToType(valueslot),
                emitUtil.derefValToMtab(valueslot))):render())
end

-- writes a new temp variable into lines and gives back the slotname
function emitUtil.emitTempVal(
        indent, config, lines, value, valuetype, metatable)
    local lhsSlot = emitUtil.getUniqueSlot(config)
    local commandLine = emitUtil.getLineAssign(
        lhsSlot, value, valuetype, metatable)
    util.addLine(indent, lines, commandLine:render())
    return lhsSlot
end

function emitUtil.emitSimpleTempVal(indent, config, lines, value)
    local lhsSlot = emitUtil.getUniqueSlot(config)
    local cmdline = emitUtil.VarAssignVal(lhsSlot, value)
    util.addLine(indent, lines, cmdline:render())
    return lhsSlot
end

-- typ and content must be values from bash EDSL
function emitUtil.getLineAssign(lhs, value, valtype, mtab)
    local line = emitUtil.getValAssignTuple(
        lhs,
        emitUtil.ValTuple(value, valtype, mtab)
            :noDependentQuoting())
    return line
end

-- assembles a properly quotet line in the form of
-- { "eval " } <varid> "=" <valueid>
function emitUtil.VarAssignVal(varId, valId)
    return
        b.eval(varId .. b.s('=') .. valId)
            :evalMin(varId:getQuotingIndex())
            :evalThreshold(1)
end

-- assembles a properly quoted line in the form of
-- { "eval " } "local " <valueid> "=" "(" <value> " " <type> " " <metatable> ")"
function emitUtil.ValAssignTuple(slot, valueTuple)
    return
        b.eval(
            slot
                .. b.string('=')
                .. valueTuple)
        :evalMin(slot:getQuotingIndex())
        :evalThreshold(1)
end

-- returns a b.parentheses object which encloses the value
-- the type and the metatable
function emitUtil.ValTuple(value, valuetype, metatable)
    local quoting = util.max(
        value:getQuotingIndex(),
        util.max(
            valuetype:getQuotingIndex(),
            metatable:getQuotingIndex()))
    return
        b.parentheses(
            -- the double quotes of value must be resolved last
            b.doubleQuotes(value):setQuotingIndex(quoting)
                .. b.string(" ") .. valuetype
                .. b.string(" ") .. metatable)
end

function emitUtil.derefVarToValue(varname)
    return b.paramExpansion(b.string("!") .. varname)
end

function emitUtil.derefVarToType(varname)
    return b.paramExpansion(b.paramExpansion(varname) .. b.string("[1]"))
end

function emitUtil.derefVarToMtab(varname)
    return b.paramExpansion(b.paramExpansion(varname) .. b.string("[2]"))
end

function emitUtil.derefValToValue(valuename)
    return b.paramExpansion(valuename)
end

function emitUtil.derefValToType(valname)
    return b.paramExpansion(valname .. b.string("[1]"))
end

function emitUtil.derefValToMtab(valname)
    return b.paramExpansion(valname .. b.string("[2]"))
end

function emitUtil.linearizePrefixTree(ast, result)
    result = result or {}
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
