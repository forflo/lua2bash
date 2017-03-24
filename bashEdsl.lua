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
    if type(bash) == "table" then t, n = bash.payload, bash.nesting
    else t, n = bash, 0
    end
    result = makeBdsl({}, "", "", t, n)
    result.typ = "eval"
    return result
end

local function bDslAll(str)
    return makeBdsl({"\"", "'", "`", "{", "}", "(", ")", "$"},
        "" , str, "", 1)
end

local function bDslString(str)
    return makeBdsl({}, "", "", str, 0)
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
    local result = ""
    local repCount = bstring.nesting
    local rest
    if type(bstring.payload) == "table" then
        rest = bstring.payload() -- recurse into tree
    else
        rest = bstring.payload
    end
    result = result .. string.rep("eval ", repCount) .. rest
    return result
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

local function bashStringEmitCmd(bstring)
    return string.format(
        "%s%s",
        string.rep("eval ", bstring.nesting),
        bstring())
end

local dispatchTable = {
    normal = bDslExecNormal,
    eval = bDslExecEval,
    separator = bDslExecWord
}

local function bDslCallDispatch(s)
    return dispatchTable[s.typ](s)
end

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

bashDslMtab.__concat = bDslConcat
bashDslMtab.__call = bDslCallDispatch

b = bDsl

--local t
--t = b.e(b.w("echo") .. b.w(iterate(bDsl.sQ, "foo", 2))
--            .. b.pE(b.c("TL") .. b.pE("E2") .. b.c("_26")))
--print(t())

return bDsl
