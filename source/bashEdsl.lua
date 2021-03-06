--
-- This module provides an embedded domain specific
-- language whose purpose is to support the generation
-- of eval aware bash command lines.
--
-- In bash you can not have more than two levels
-- of indirection using only direct parameter expansion.
-- That means if the variable
-- foo contains the string "bar" and if the variable
-- bar contains "moo". You can get the result
-- "moo" by using the expansion ${!foo}, which
-- is a limited, special syntax for that task.
-- However, given the fact that moo contains
-- the string "third", you can not get the
-- result "third" by using ${!!foo} or
-- ${${${foo}}} directly, because the bash simply
-- does not support that (ZSH does by the way).
--
-- In bash we need to think a little bit harder
-- to accomplish the same thing.
--
-- Lets recapitulate the variable assignments first:
-- foo=bar; bar=moo; moo=string;
-- Furthermore we want to print the result "string"
-- only using expansions on the variable foo.
--
-- Eval is our friend! (I assume you know how the bash
-- and the eval builtin works)
--
-- We can simply write:
-- eval eval echo \\\${\${${foo}}}
-- Evaluation steps:
-- (1) eval eval echo \\\${\${${foo}}}
-- (2) eval echo \${${bar}}
-- (3) echo ${moo}
-- (4) => string
--
-- As you can see, each additional eval commands the
-- bash to run the same expansions again that it normally would
-- run only once. Since we want to have an inside-out fashioned
-- evaluation, we need to make sure, that the enclosing outer
-- layers of parameter expansions are quoted so that they
-- only get active in the appropriate next step.
--
-- This library enables you to build up command lines like
-- the one above with a dedicated set of specialized functions
-- that can be used in a combinatorical fashion. With it,
-- the line eval eval echo \\\${${${foo}}}
-- can be built by the call
--
-- b.eval(
--     b.string'echo' .. b.string' ' ..
--     b.paramExpansion(
--         b.paramExpansion(
--             b.paramExpansion(
--                 b.string('foo')
--             )
--         )
--     )
-- )
--
-- However, the inner most expression b.string('foo') could also
-- be just a variable that holds a much more complex expression and
-- b.eval would add more layers of eval in order to completely
-- evaluate the line depending on the overall level of nests.
--
-- Imagine, for example, the following snippet:
--
-- local innerExp =
--         b.paramExpansion(
--             b.paramExpansion(
--                 b.string('foo')))
-- local commandline =
--     b.eval(
--         b.string'echo' .. b.string' ' ..
--         b.paramExpansion(
--             b.paramExpansion(
--                 b.paramExpansion(
--                     innerExp))))
-- local resultstring = commandline:render()
-- print(resultstring)
-- => "eval eval eval eval echo \\\\\\\\\\\\\\\${\\\\\\\${\\\${\${${foo}}}}}"
--
-- Pretty ugly, isn't it... That's exactly the reason why this EDSL exists


local dbg = require "debugger"

local function max(x, y)
    if x > y then return x
    else return y end
end

local bdsl = {}
bdsl.types = { EVAL = {}, BASE = {}, STRING = {}, CONC = {} }

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
    t._type = bdsl.types.CONC
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
    function t:getType() return self._type end
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

local function isStringIn(str, tbl)
    for _, v in pairs(tbl) do
        if v == str then
            return true
        end
    end
    return false
end

function dslObjects.Base(activeChars, begin, ending, dslobj)
    local t = {}
    t._activeChars = settify(activeChars)
    t._type = bdsl.types.BASE
    t._begin = begin
    t._dependentQuoting = true
    t._subtree = nil
    t._end = ending
    if isStringIn(type(dslobj), {"string", "number", "nil", "boolean"}) then
        t._subtree = dslObjects.String(tostring(dslobj))
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
    function t:setQuotingIndex(n)
        if not n then n = 1 end
        self._quotingIndex = n
        return self
    end
    function t:noDependentQuoting()
        self._dependentQuoting = false
        self._quotingIndex = t._subtree:getQuotingIndex()
        return self
    end
    function t:sameAsSubtree()
        self._quotingIndex = t._subtree:getQuotingIndex()
        return self
    end
    function t:getQuotingIndex()
        return self._quotingIndex
    end
    --
    function t:getType() return self._type end
    function t:getActiveChars() return self._activeChars end
    function t:getBegin() return self._begin end
    function t:getEnd() return self._end end
    function t:getSubtree() return self._subtree end
    function t:render()
        local result, middle = "", self:getSubtree():render()
        local ac, begin, ending =
            self:getActiveChars(), self:getBegin(), self:getEnd()
        local nesting, repCount = self:getQuotingIndex(), nil
        if nesting > 0  and self._dependentQuoting then
            repCount = 2 ^ (nesting - 1) - 1
        elseif not self._dependenQuoting then
            repCount = 1
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
    -- write only
    function t:sL(n) return self:shallowLift(n) end
    function t:dL(n) return self:deepLift(n) end
    function t:noDep() return self:noDependentQuoting() end
    function t:sQ(n) return self:setQuotingIndex(n) end
    function t:sAS() return self:sameAsSubtree() end
    setmetatable(t, mtab)
    return t
end

function dslObjects.String(str)
    assert(type(str) == "string", "Not of string type")
    local t = {}
    t._content = str
    t._quotingIndex = 0
    t._type = bdsl.types.STRING
    function t:getType() return self._type end
    function t:shallowLift() return self end
    function t:deepLift() return self end
    function t:getQuotingIndex() return 0 end
    function t:getSubtree() return nil end
    function t:setQuotingIndex(n)
        if not n then n = 1 end
        self._quotingIndex = n
        return self
    end
    -- all chars will be prepended by an appropriate amount
    -- of backslash quotes depending on the quoting index
    function t:render()
        local repCount = 2 ^ self._quotingIndex - 1
        local result = ""
        for c in self._content:gmatch(".") do
            result = result .. string.rep("\\", repCount) .. c
        end
        return result
    end
    -- write only
    function t:sL(n) return self:shallowLift(n) end
    function t:dL(n) return self:deepLift(n) end
    function t:sQ(n) return self:setQuotingIndex(n) end
    setmetatable(t, mtab)
    return t
end


function dslObjects.Eval(dslobj)
    local t = {}
    t._subtree = nil
    t._type = bdsl.types.EVAL
    if type(dslobj) == "string" then
        t._subtree = dslObjects.String(dslobj)
    else
        t._subtree = dslobj
    end
    t._evalCountMin = 0
    t._evalThreshold = 1
    t._evalCount = t._subtree:getQuotingIndex() - t._evalThreshold
    -- member functions
    function t:shallowLift() return self end
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
    function t:evalThreshold(n)
        if not n then n = 1 end
        self._evalThreshold = n
        return self
    end
    function t:evalMin(n)
        if not n then n = 1 end
        self._evalCountMin = n
        return self
    end
    function t:getSubtree() return self._subtree end
    function t:getEvalCountMin() return self._evalCountMin end
    function t:getEvalThreshold() return self._evalThreshold end
    function t:getType() return self._type end
    function t:getQuotingIndex()
        return self:getSubtree():getQuotingIndex() end
    function t:getEvalCount() return self._evalCount end
    function t:render()
        local evalCount = self:getQuotingIndex() - self:getEvalThreshold()
        local rest = self:getSubtree():render()
        if evalCount < self:getEvalCountMin() then
            evalCount = self:getEvalCountMin()
        end
        return string.rep("eval ", evalCount) .. rest
    end
    -- write only
    function t:sL(n) return self:shallowLift(n) end
    function t:dL(n) return self:deepLift(n) end
    function t:eL(n) return self:evalLift(n) end
    function t:eM(n) return self:evalMin(n) end
    function t:eT(n) return self:evalThreshold(n) end
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

-- better readability
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

-- write only
bdsl.e = bDslEval
bdsl.s = bDslString
bdsl.pE = bDslParamExpansion
bdsl.sQ = bDslSingleQuotes
bdsl.dQ = bDslDoubleQuotes
bdsl.pEI = bDslProcessExpansionIn
bdsl.pEO = bDslProcessExpansionOut
bdsl.cEP = bDslCommandExpansionParen
bdsl.cET = bDslCommandExpansionTicks
bdsl.aE = bDslArithExpansion
bdsl.bE = bDslBraceExpansion
bdsl.p = bDslParentheses

return bdsl
