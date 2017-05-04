local util = require("lua2bash-util")
local datatypes = {}

-- This module contains classes (no inheritance) for
-- * symboltables
-- * symbols
-- * stacks
-- * scopes
-- Each function in the package datatypes serves as constructor
-- for the class it simultaneously represents.
-- Note that each function sets a common metatable for the object
-- returned. The metatable provides for a custom tostring overload
-- that is useful during debugging or logging.

datatypes.commonMtab = {
    __tostring = function(symtab)
        return util.tostring(symtab)
    end
}

function datatypes.Either()
    local t = {}
    t._right, t._left, t._isLeft = nil, nil, nil

    function t:getType()
        return "either"
    end
    function t:isRight()
        assert(t._isLeft, "Either obj not initialized")
        return not self:isLeft()
    end
    function t:isLeft()
        assert(t._isLeft, "Either obj not initialized")
        return t._isLeft
    end

    function t:makeRight(obj)
        assert(obj, "obj must not be nil")
        self._left, self._right = nil, obj
        self._isLeft = false
        return self
    end
    function t:makeLeft(obj)
        assert(obj, "obj must not be nil")
        self._left, self._right = obj, nil
        self.isLeft = true
        return self
    end

    function t:getRight()
        assert(self:isRight(), "getRight on left object")
        return self._right
    end
    function t:getLeft()
        assert(self:isLeft(), "getLeft on right object")
        return self._left
    end

    setmetatable(t, datatypes.commonMtab)
    return t
end

function datatypes.SymbolTable()
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
    setmetatable(t, datatypes.commonMtab)
    return t
end

function datatypes.Symbol(value, redefCount, curSlot, emitVarname)
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
    setmetatable(obj, datatypes.commonMtab)
    return obj
end

datatypes.occasions = {
    BLOCK = {}, FOR = {}, IF = {},
    WHILE = {}, DO = {}
}

function datatypes.Scope(occasion, name, id, path)
    local t = {}
    -- initializer
    t._occasion = occasion
    t._name = name
    t._scopeId = id
    t._path = path
    t._symbolTable = datatypes.SymbolTable()
    -- getter
    function t:getPath() return self._path end
    function t:getName() return self._name end
    function t:getOccasion() return self._occasion end
    function t:getScopeId() return self._scopeId end
    function t:getSymbolTable() return self._symbolTable end
    -- setter
    function t:setScopeId(v) self._scopeId = v end
    function t:setName(v) self._name = v end
    function t:setPath(v) self._path = v end
    function t:setSymbolTable(v) self._symbolTable = v end
    function t:setOccasion(v) self._occasion = v end

    -- TODO: fix this
    --setmetatable(t, datatypes.commonMtab)
    return t
end

-- Create a Table with stack functions
function datatypes.Stack()
    -- stack table
    local t = {}
    -- entry table
    t._et = {}

    -- push a value on to the stack
    function t:push(...)
        if ... then
            local targs = {...}
            -- add values
            for _, v in ipairs(targs) do
                table.insert(self._et, v)
            end
        end
        return self
    end

    -- pop a value from the stack
    function t:pop(num)
        -- get num values from stack
        num = num or 1
        -- return table
        local entries = {}
        -- get values into entries
        for _ = 1, num do
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
        return table.unpack(entries)
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

    function t:genericIIterator()
        return datatypes.GenericIIterator(self._et)
    end

    function t:deepCopy()
        return util.tableDeepCopy(self)
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

    setmetatable(t, datatypes.commonMtab)
    return t
end

function datatypes.GenericIIterator(tbl)
    local t = {}
    t._tbl = tbl
    t._currentIdx = 1
    function t:advance(n)
        assert((n + self._currentIdx) >= 0
                and (n + self._currentIdx) <= self:length(),
            "Invalid andvance count")
        self._currentIdx = self._currentIdx + n
        return self
    end
    -- common functions
    function t:currentObj()
        return self._tbl[self._currentIdx]
    end
    function t:currentIdx()
        return self._currentIdx
    end
    function t:length()
        return #self._tbl
    end
    function t:setMin() self._currentIdx = 1; return self end
    function t:setMax() self._currentIdx = self:length(); return self end
    -- iterator conversions
    function t:IIterator()
        return util.statefulIIterator(self._tbl)
    end
    function t:reverseIIterator()
        return util.reverseIIterator(self._tbl)
    end
    setmetatable(t, datatypes.commonMtab)
    return t
end

function datatypes.CompileTimeScope()
    -- TODO:
end

function datatypes.SpaghettiStack(
        parentSS, localAssigns, assigns, reason)
    local t = {}
    t._parent = parent
    t._localAssigns = localAssigns
    t._assigns = assigns
    t._reason = reason
    t._childs = {}

    function t:addChild(childStack)
        self._scopes[#self._scopes + 1] = scope
    end
    function t:nThScope(n)
        return self._scopes[n]
    end

    function t:parent()
        return self._parent
    end

    setmetatable(t, datatypes.commonMtab)
    return t
end

return datatypes
