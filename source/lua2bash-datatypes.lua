local util = require("lua2bash-util")
local comp = {}

function comp.SymbolTable()
    local t = {}
    t._symbolTable = {}
    function t:isInSymtab(varName)
        for k, v in pairs(self._symbolTable) do
            if k == varName then
                return v -- v is a symbol
            end
        end
        return nil
    end
    function t:addNewSymbol(varName, symbol)
        self._symbolTable[varName] = symbol
    end
    function t:removeSymbol(varName)
        --TODO:?
    end
    return t
end

function comp.Symbol(value, redefCount, curSlot, emitVarname)
    local obj = {}
    obj._curSlot = curSlot
    obj._emitVarname = emitVarname
    obj._value = value
    obj._redefCount = redefCount
    -- getter
    function obj:getCurSlot() return obj._curSlot end
    function obj:getEmitVarname() return obj._emitVarname end
    function obj:getValue() return obj._value end
    function obj:getRedefCnt() return obj._redefCount end
    -- misc functions
    function obj:replaceBy(v)
        self._curSlot = v:getCurSlot(v)
        self._emitVarname = v:getEmitVarname(v)
        self._value = v:getValue(v)
        self._redefCount = v:getRedefCnt(v)
        return self
    end
    -- setter
    function obj:setCurSlot(v) self._curSlot = v; return self end
    function obj:setEmitVarname(v) self._emitVarname = v; return self end
    function obj:setValue(v) self._value = v; return self end
    function obj:setRedefCnt(v) self._redefCount = v; return self end
    return obj
end

comp.occasions = {
    BLOCK = {}, FOR = {}, IF = {},
    WHILE = {}, DO = {}
}

function comp.Scope(occasion, name, id, path)
    local t = {}
    local mtab = {}
    mtab.__tostring = function(scope)
        return util.tostring(scope)
    end
    -- initializer
    t._occasion = occasion
    t._name = name
    t._environmentId = id
    t._path = path
    t._symbolTable = comp.SymbolTable()
    -- getter
    function t:getPath() return self._path end
    function t:getName() return self._name end
    function t:getOccasion() return self._occasion end
    function t:getEnvironmentId() return self._environmentId end
    function t:getSymbolTable() return self._symbolTable end
    -- setter
    function t:setEnvironmentId(v) self._environmentId = v end
    function t:setName(v) self._name = v end
    function t:setPath(v) self._path = v end
    function t:setSymbolTable(v) self._symbolTable = v end
    function t:setOccasion(v) self._occasion = v end

--    setmetatable(t, mtab)
    return t
end

-- Create a Table with stack functions
function comp.Stack()
    -- stack table
    local t = {}
    local mtab = {}
    -- entry table
    t._et = {}
    -- tostring overload
    mtab.__tostring = function(stack)
        return util.tostring(stack._et)
    end

    -- push a value on to the stack
    function t:push(...)
        if ... then
            local targs = {...}
            -- add values
            for _, v in ipairs(targs) do
                table.insert(self._et, v)
            end
        end
    end

    -- pop a value from the stack
    function t:pop(num)
        -- get num values from stack
        local num = num or 1
        -- return table
        local entries = {}
        -- get values into entries
        for i = 1, num do
            -- get last entry
            if #self._et ~= 0 then
                table.insert(entries, self._et[#self._et])
                -- remove last value
                table.remove(self._et)
            else
                break
            end
        end
        -- return unpacked entries
        return unpack(entries)
    end

    -- map on stacks from bottom to top
    function t:map(fun)
        local result = {}
        for i = 1, #self._et do
            result[#result + 1] = fun(self._et[i])
        end
        return result
    end

    function t:top()
        return self._et[#self._et]
    end

    function t:bottom()
        if self._et[1] then return self._et[1]
        else return nil end
    end

    function t:getNth(n)
        if n < 0 or n > #self._et then return nil
        else return self._et[n] end
    end

    function t:getn()
        return #self._et
    end

    setmetatable(t, mtab)
    return t
end

return comp
