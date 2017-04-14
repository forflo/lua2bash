local util = require("lua2bash-util")
local datatypes = require("lua2bash-datatypes")
local b = require("bashEdsl")

local scope = {}

function scope.getPathPrefix(stack)
    local paths = stack:map(function(s) return s:getName() end)
    return util.join(paths, '')
end

-- @pure
function scope.getNewLocalSymbol(config, stack, varName)
    local newSymbol = datatypes.Symbol(0, 1)
    local currentPathPrefix = scope.getPathPrefix(stack)
    local emitVarname =
        b.c(config.varPrefix)
        .. b.pE(config.environmentPrefix .. stack:top():getEnvironmentId())
        .. b.c(currentPathPrefix .. "_" .. varName)
    newSymbol:setEmitVarname(emitVarname)
    newSymbol:setCurSlot(b.c(config.valPrefix .. "D1") .. emitVarname)
    return newSymbol
end

-- @pure
function scope.getUpdatedSymbol(config, stack, oldSymbol, varName)
    local newSymbol = datatypes.Symbol():replaceBy(oldSymbol)
    newSymbol:setRedefCnt(newSymbol:getRedefCnt() + 1)
    newSymbol:setCurSlot(
        b.c(config.valPrefix)
            .. b.c("D")
            .. b.c(newSymbol:getRedefCnt())
            .. newSymbol:getEmitVarname())
    return newSymbol
end

-- @pure
function scope.getGlobalSymbol(config, stack, varName)
    local bottom = stack:bottom()
    local emitVarname =
        b.c(config.varPrefix)
        .. b.pE(config.environmentPrefix .. bottom:getEnvironmentId())
        .. b.c(stack:bottom():getName())
        .. b.c(varName)
    local newSymbol = datatypes.Symbol(0, 1)
    newSymbol:setEmitVarname(emitVarname)
    newSymbol:setCurSlot(
        b.c(config.valPrefix) .. emitVarname)
    return newSymbol
end

function scope.whereInScope(stack, varName)
    assert(stack or varName, "Arguments must not be nil")
    local entries = stack:map(
        function(scope)
            local result = scope:getSymbolTable():isInSymtab(varName)
            local t1, t2
            if result == nil then t1, t2 = false, scope
            else t1, t2 = true, scope end
            return { ["exists"] = t1, ["symbol"] = result, ["scope"] = t2 }
    end)
    return entries
end

function scope.getMostCurrentBinding(stack, varName)
    assert(varName or stack, "Arguments must not be nil")
    local entries = scope.whereInScope(stack, varName)
    entries = util.filter(entries, function(e) return e.exists end)
    if #entries == 0 then return nil
    else return entries[#entries] end
end

return scope
