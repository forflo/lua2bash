util = require("lua2bash-util")
compiler = require("lua2bash-comp")

local scope = {}

function scope.getPathPrefix(stack)
    local paths = stack:map(function(s) return s:getName() end)
    return util.join(paths, '')
end

function scope.setLocalFirstTime(ast, config, stack, varName)
    local symbol = compiler.Symbol(0, 1)
    local currentPathPrefix = scope.getPathPrefix(config, stack)
    local emitVarname = config.varPrefix .. "${"
        .. stack:top():getEnvironmentId() .. "}"
        .. currentPathPrefix .. "_" .. varName
    symbol.setEmitVarname(emitVarname)
    symbol.setCurSlot(config.valPrefix .. "D"
                          .. symbol.getRedefCnt() .. emitVarname)
    stack:top():addNewSymbol(varName, symbol)
end

function scope.updateSymbol(config, stack, symbol, varName)
    local definitionInfix = "D"
    local newSymbol = compiler.Symbol(0, 1)
    local currentPathPrefix = scope.getScopePrefix(config, stack)
    newSymbol.setRedefCount(symbol.getRedefCnt() + 1)
    newSymbol.setCurSlot(config.valPrefix
                          .. definitionInfix
                          .. symbol.getRedefCount
                          .. varAttr.emitVarname)
    return newSymbol
end

function scope.setGlobal(config, stack, varName)
    local bottom = stack:bottom()
    local definitionInfix = "D1"
    local emitVarname = config.varPrefix .. "${"
        .. bottom:getEnvironmentId() .. "}"
        .. varName
    local symbol = compiler.Symbol(value, 1)
    symbol.setEmitVarname(emitVarname)
    symbol.setCurSlot(config.valPrefix .. emitVarname)
    bottom:addNewSymbol(varName, symbol)
end

function scope.isInSomeScope(config, stack, varName)
    local key, symbol
    local entries = stack:map(
        function(scope)
            return scope.getSymbolTable():isInSymtab(varName) end)
    return entries[#entries]
    -- only the most current entry (topmost on stack is wanted here)
end

return scope
