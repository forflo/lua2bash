local util = require("lua2bash-util")
local b = require("bashEdsl")

local emitUtil = {}

-- we can do ((Ex = Ex + 1)) even as first comman line because
-- bash will use 0 as value for Ex if the variable is not declared.
function emitUtil.emitEnvCounter(indent, config, lines, envId)
    util.addLine(
        indent, lines,
        string.format("((%s = %s + 1))",
                      config.environmentPrefix .. envId,
                      config.environmentPrefix .. envId),
        "Environment counter")
end

function emitUtil.emitLocalVar(indent, lines, varname, valuename, value, typ)
    util.addLine(indent, lines, b.e(varname .. valuename)())
    util.addLine(indent, lines, b.e(valuename .. b.pN(b.dQ(value) .. typ))())
end

function emitUtil.emitLocalVarUpdate(indent, lines, symbol)
    util.addLine(
        indent, lines,
        b.e(
            symbol:getEmitVarname() .. b.s("=")
                .. symbol:getCurSlot())())
end

function emitUtil.emitVar(indent, symbol, lines)
    util.addLine(
        indent, lines,
        b.e(
            symbol:getEmitVarname() .. b.s("=")
                .. symbol:getCurSlot())())
end

function emitUtil.emitUpdateVar(indent, symbol, valueslot, lines)
    util.addLine(
        indent, lines,
        b.e(
            symbol:getCurSlot()
                .. b.s("=")
                .. b.p(
                    emitUtil.derefValToValue(valueslot)
                        .. b.s(" ")
                        .. emitUtil.derefValToType(valueslot))()))
end

function emitUtil.derefVarToValue(varname)
    return b.pE(b.s("!") .. varname)
end

function emitUtil.derefVarToType(varname)
    return b.pE(b.pE(varname) .. b.s("[1]"))
end

function emitUtil.derefValToEnv(valuename)
    return b.pE(valuename .. b.s("[2]"))
end

function emitUtil.derefValToValue(valuename)
    return b.pE(valuename)
end

function emitUtil.derefValToType(valname)
    return b.pE(valname .. b.s("[1]"))
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
