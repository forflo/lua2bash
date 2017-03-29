util = require("lua2bash-util")
compiler = require("lua2bash-comp")

local scope = {}

function scope.getPathPrefix(stack)
    local paths = stack:map(function(s) return s:getName() end)
    return util.join(paths, '')
end

function scope.setLocalFirstTime(config, stack, varName)
    local symbol = compiler.Symbol(0, 1)
    local currentPathPrefix = scope.getPathPrefix(stack)
    local emitVarname = config.varPrefix .. "${"
        .. stack:top():getEnvironmentId() .. "}"
        .. currentPathPrefix .. "_" .. varName
    symbol:setEmitVarname(emitVarname)
    symbol:setCurSlot(config.valPrefix .. "D"
                          .. symbol:getRedefCnt() .. emitVarname)
    stack:top():getSymbolTable():addNewSymbol(varName, symbol)
    return symbol
end

-- TODO: test
function scope.updateSymbol(config, stack, symbol, varName)
    local definitionInfix = "D"
    local newSymbol = compiler.Symbol(0, 1)
    local currentPathPrefix = scope.getPathPrefix(stack)
    newSymbol:setRedefCount(symbol.getRedefCnt() + 1)
    newSymbol:setEmitVarname(symbol:getEmitVarname())
    newSymbol:setCurSlot(config.valPrefix
                          .. definitionInfix
                          .. symbol.getRedefCount
                          .. varAttr.emitVarname)
    return newSymbol
end

function scope.setGlobal(config, stack, varName)
    local bottom = stack:bottom()
    local emitVarname = config.varPrefix .. "${" .. config.environmentPrefix
        .. bottom:getEnvironmentId() .. "}" .. scope.getPathPrefix(stack)
        .. varName
    local symbol = compiler.Symbol(value, 1)
    symbol:setEmitVarname(emitVarname)
    symbol:setCurSlot(config.valPrefix .. emitVarname)
    bottom:getSymbolTable():addNewSymbol(varName, symbol)
    return symbol
end

function scope.whereInScope(stack, varName)
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
    local entries = scope.whereInScope(stack, varName)
    entries = util.filter(entries, function(e) return e.exists end)
    if #entries == 0 then return nil
    else return entries[#entries] end
end

return scope
