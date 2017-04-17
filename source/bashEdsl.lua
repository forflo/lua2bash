dbg = require "debugger"

local function max(x, y)
    if x > y then return x
    else return y end
end

local bdsl = {}

local mtab = {}
local dslObjects = {}

mtab.__call = function(callee, arg)
    return callee:render(arg)
end
mtab.__concat = function(l, r)
    assert(l and r, "Arguments must not be nil")
    assert((getmetatable(l) == mtab or type(l) == "string") and
            (getmetatable(r) == mtab or type(r) == "string"),
        "Arguments must have been generated by bash EDSL functions\n" ..
            "type left: " .. type(l) .. " type right: " .. type(r))
    if type(l) == "string" then
        l = dslObjects.String(l)
    end
    if type(r) == "string" then
        r = dslObjects.String(r)
    end
    return dslObjects.Concat(l, r)
end

function dslObjects.Concat(left, right)
    local t = {}
    t._left = left
    t._right = right
    function t:render()
        return self:getLeft():render() .. self:getRight():render()
    end
    function t:shallowLift(n)
        if not n then n = 1 end
        self:getLeft():shallowLift(n)
        self:getRight():shallowLift(n)
        return self
    end
    function t:deepLift(n)
        if not n then n = 1 end
        self:getLeft():deepLift(n)
        self:getRight():deepLift(n)
        return self
    end
    function t:getLeft() return self._left end
    function t:getRight() return self._right end
    function t:getQuotingIndex()
        return max(self:getLeft():getQuotingIndex(),
                   self:getRight():getQuotingIndex())
    end
    setmetatable(t, mtab)
    return t
end

local function settify(activeChars)
    local charSet = {}
    for _, v in pairs(activeChars) do
        charSet[v] = true
    end
    return charSet
end

function dslObjects.Base(activeChars, begin, ending, dslobj)
    local t = {}
    t._activeChars = settify(activeChars)
    t._begin = begin
    t._dependentQuoting = true
    t._subtree = nil
    t._end = ending
    if type(dslobj) == "string" then
        t._subtree = dslObjects.String(dslobj)
    else
        t._subtree = dslobj
    end
    t._quotingIndex = t._subtree:getQuotingIndex() + 1
    -- member functions
    function t:shallowLift(n)
        if not n then n = 1 end
        self._quotingIndex = self._quotingIndex + n
        return self
    end
    function t:deepLift(n)
        if not n then n = 1 end
        self:shallowLift(n)
        self:getSubtree():deepLift(n)
        return self
    end
    function t:noDependentQuoting()
        self._dependentQuoting = false
        return self
    end
    function t:getQuotingIndex()
        return self._quotingIndex
    end
    --
    function t:getActiveChars() return self._activeChars end
    function t:getBegin() return self._begin end
    function t:getEnd() return self._end end
    function t:getSubtree() return self._subtree end
    function t:render()
        local result, middle = "", self:getSubtree():render()
        local ac, begin, ending = self:getActiveChars(), self:getBegin(), self:getEnd()
        local nesting, repCount = self:getQuotingIndex(), nil
        if nesting > 0 then
            repCount = 2 ^ (nesting - 1) - 1
        else
            repCount = 0
        end
        for c in begin:gmatch(".") do
            if ac[c] then result = result .. string.rep("\\", repCount) .. c
            else result = result .. c end
        end
        result = result .. middle
        for c in ending:gmatch(".") do
            if ac[c] then result = result .. string.rep("\\", repCount) .. c
            else result = result .. c end
        end
        return result
    end
    setmetatable(t, mtab)
    return t
end

function dslObjects.String(str)
    local t = {}
    t._content = str
    function t:shallowLift(n) return self end
    function t:deepLift(n) return self end
    function t:getQuotingIndex() return 0 end
    function t:getSubtree() return nil end
    function t:render() return self._content end
    setmetatable(t, mtab)
    return t
end

function dslObjects.Eval(dslobj)
    local t = {}
    t._subtree = nil
    if type(dslobj) == "string" then
        t._subtree = dslObjects.String(dslobj)
    else
        t._subtree = dslobj
    end
    t._evalCount = t._subtree:getQuotingIndex() - 1
    -- member functions
    function t:shallowLift(n) return self end
    function t:deepLift(n)
        if not n then n = 1 end
        t:getSubtree():deepLift(n)
        return self
    end
    function t:evalLift(n)
        if not n then n = 1 end
        self._evalCount = self._evalCount + n
        return self
    end
    function t:getSubtree() return self._subtree end
    function t:getQuotingIndex() return self:getSubtree():getQuotingIndex() end
    function t:getEvalCount() return self._evalCount end
    function t:render()
        local repCount = self:getQuotingIndex() - 1
        if self:getEvalCount() ~= repCount then
            repCount = self:getEvalCount()
        end
        local rest = self:getSubtree():render()
        return string.rep("eval ", repCount) .. rest
    end
    setmetatable(t, mtab)
    return t
end

local function bDslEval(dslobj)
    return dslObjects.Eval(dslobj)
end

local function bDslString(str)
    return dslObjects.String(str)
end

local function bDslParentheses(dslobj)
    return dslObjects.Base({"(", ")"}, "(", ")", dslobj)
end

local function bDslParamExpansion(str)
    return dslObjects.Base({"$"}, "${", "}", str)
end

local function bDslSingleQuotes(str)
    return dslObjects.Base({"'"}, "'", "'", str)
end

local function bDslArithExpansion(str)
    return dslObjects.Base({"$", "(", ")"}, "$((", "))", str)
end

local function bDslDoubleQuotes(str)
    return dslObjects.Base({[["]]}, "\"", "\"", str)
end

local function bDslCommandExpansionTicks(str)
    return dslObjects.Base({"`"}, "`", "`", str)
end

local function bDslCommandExpansionParen(str)
    return dslObjects.Base({"$", "(", ")"}, "$(", ")", str)
end

local function bDslBraceExpansion(str)
    return dslObjects.Base({"{", "}"}, "{", "}", str)
end

local function bDslProcessExpansionIn(str)
    return dslObjects.Base({"<", "(", ")"}, "<(", ")", str)
end

local function bDslProcessExpansionOut(str)
    return dslObjects.Base({">", ")", "("}, ">(", ")", str)
end

bdsl.eval = bDslEval
bdsl.string = bDslString
bdsl.paramExpansion = bDslParamExpansion
bdsl.singleQuotes = bDslSingleQuotes
bdsl.doubleQuotes = bDslDoubleQuotes
bdsl.processExpansionIn = bDslProcessExpansionIn
bdsl.processExpansionOut = bDslProcessExpansionOut
bdsl.cmdExpansionParen = bDslCommandExpansionParen
bdsl.cmdExpansionTicks = bDslCommandExpansionTicks
bdsl.arithExpansion = bDslArithExpansion
bdsl.braceExpansion = bDslBraceExpansion
bdsl.parentheses = bDslParentheses

return bdsl
