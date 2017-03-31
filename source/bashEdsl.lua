dbg = require "debugger"
require "lua2bash-util"

local bashDslMtab = { }

local bDsl = { }

local function makeBdsl(activeChars, begin, ending, str, nesting)
    local temp = {}
    for _, v in pairs(activeChars) do
        temp[v] = true
    end
    result = { activeChars = temp, begin = begin,
               ending = ending, payload = str,
               typ = "normal",
               nesting = nesting }
    setmetatable(result, bashDslMtab)
    return result
end

local function bDslWord(bash)
    if not bash then print("error!"); os.exit(1) end
    -- TODO: ok?
    local t, n, result
    if type(bash) == "table" then t, n = bash(), bash.nesting
    else t, n = bash, 0
    end
    result = makeBdsl({}, "", "", t, n)
    result.typ = "separator"
    return result
end

local function bDslEval(bash)
    local t, n
    if type(bash) == "table" then t, n = bash(), bash.nesting
    else t, n = bash, 0
    end
    result = makeBdsl({}, "", "", t, n)
    result.typ = "eval"
    return result
end

local function allAscii()
    local result = {}
    for i = 0, 127 do
        result[#result + 1] = string.char(i)
    end
    return result
end

local function bDslAll(str, nest)
    local result = makeBdsl({}, "" , "", str, 0)
    result.typ = "all"
    result.allnesting = nest or 1
    return result
end

local function bDslString(str)
    return makeBdsl({}, "", "", str, 0)
end

local function bDslParentheses(str)
    return makeBdsl({"(", ")"}, "(", ")", str, (str.nesting or -1) + 1)
end

local function bDslParamExpansion(str)
    return makeBdsl({"$"}, "${", "}", str, (str.nesting or -1) + 1)
end

local function bDslSingleQuotes(str)
    return makeBdsl({"'"}, "'", "'", str, (str.nesting or -1) + 1)
end

local function bDslArithExpansion(str)
    return makeBdsl({"$", "(", ")"}, "$((", "))", str, (str.nesting or -1) + 1)
end

local function bDslDoubleQuotes(str)
    return makeBdsl({[["]]}, "\"", "\"", str, (str.nesting or -1) + 1)
end

local function bDslCommandExpansionTicks(str)
    return makeBdsl({"`"}, "`", "`", str, (str.nesting or -1) + 1)
end

local function bDslCommandExpansionParen(str)
    return makeBdsl({"$", "(", ")"}, "$(", ")", str, (str.nesting or -1) + 1)
end

local function bDslBraceExpansion(str)
    return makeBdsl({"{", "}"}, "{", "}", str, (str.nesting or -1) + 1)
end

local function bDslProcessExpansionIn(str)
    return makeBdsl({"<", "(", ")"}, "<(", ")", str, (str.nesting or -1) + 1)
end

local function bDslProcessExpansionOut(str)
    return makeBdsl({">", ")", "("}, ">(", ")", str, (str.nesting or -1) + 1)
end

local function max(x, y)
    if x > y then return x
    else return y end
end

local function bDslConcat(l, r)
    return makeBdsl({}, "", "", l() .. r(), max(l.nesting, r.nesting))
end

local function bDslExecEval(bstring)
    local repCount = bstring.nesting
    local rest
    if type(bstring.payload) == "table" then
        rest = bstring.payload() -- recurse into tree
    else
        rest = bstring.payload
    end
    return string.rep("eval ", repCount) .. rest
end

local function bDslExecWord(bstring)
    local result = ""
    local rest
    if type(bstring.payload) == "table" then
        rest = bstring.payload() -- recurse into tree
    else
        rest = bstring.payload
    end
    return rest .. " "
end

local function bDslExecNormal(bstring)
    local result = ""
    local ac = bstring.activeChars
    local begin = bstring.begin
    local payload
    if type(bstring.payload) == "table" then
        middle = bstring.payload() -- recurse into tree
    else
        middle = bstring.payload
    end
    local ending = bstring.ending
    local nesting = bstring.nesting
    local repCount = 2 ^ nesting - 1
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

local function bDslExecAll(bstring)
    local payload = bstring.payload
    local middle, result = nil, ""
    if type(payload) == "table" then middle = payload()
    else middle = payload end
    local repCount = 2 ^ bstring.allnesting - 1
    for c in middle:gmatch(".") do
        result = result .. string.rep("\\", repCount) .. c
    end
    return result
end

local dispatchTable = {
    normal = bDslExecNormal,
    eval = bDslExecEval,
    separator = bDslExecWord,
    all = bDslExecAll
}

local function bDslCallDispatch(s)
    return dispatchTable[s.typ](s)
end

bDsl.a = bDslAll
bDsl.w = bDslWord
bDsl.e = bDslEval
bDsl.c = bDslString
bDsl.pE = bDslParamExpansion
bDsl.sQ = bDslSingleQuotes
bDsl.dQ = bDslDoubleQuotes
bDsl.procEi = bDslProcessExpansionIn
bDsl.procEo = bDslProcessExpansionOut
bDsl.cEp = bDslCommandExpansionParen
bDsl.cEt = bDslCommandExpansionTicks
bDsl.aE = bDslArithExpansion
bDsl.bE = bDslBraceExpansion
bDsl.p = bDslParentheses

bashDslMtab.__concat = bDslConcat
bashDslMtab.__call = bDslCallDispatch

return bDsl