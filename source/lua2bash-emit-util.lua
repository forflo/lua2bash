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
    util.addLine(indent, lines, b.e(valuename .. b.p(b.dQ(value) .. typ))())
end

function emitUtil.emitLocalVarUpdate(indent, lines, symbol)
    util.addLine(
        indent, lines,
        b.e(
            b.lift(
                symbol:getEmitVarname() .. b.c("=") .. symbol:getCurSlot()))())
end

function emitUtil.emitVar(indent, symbol, lines)
    util.addLine(
        indent, lines,
        b.e(
            b.lift(
                symbol:getEmitVarname() .. b.c("=") .. symbol:getCurSlot()))())
end

function emitUtil.emitUpdateVar(indent, symbol, valueslot, lines)
    util.addLine(
        indent, lines,
        b.e(
            symbol:getCurSlot()
                .. b.c("=")
                .. b.p(
                    emitUtil.derefValToValue(valueslot)
                        .. b.c(" ")
                        .. emitUtil.derefValToType(valueslot)))())
end

function emitUtil.derefVarToValue(varname)
    return b.pE(b.c("!") .. b.c(varname))
end

function emitUtil.derefVarToType(varname)
    return b.pE(b.pE(varname) .. b.c("[1]"))
end

function emitUtil.derefValToEnv(valuename)
    return b.pE(valuename .. b.c("[2]"))
end

function emitUtil.derefValToValue(valuename)
    return b.pE(valuename)
end

function emitUtil.derefValToType(valname)
    return b.pE(valname .. b.c("[1]"))
end

function emitUtil.linearizePrefixTree(indent, ast, config, stack, result)
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
        emitUtil.linearizePrefixTree(ast[1], config, result)
    end
    return util.tableReverse(result)
end

return emitUtil
