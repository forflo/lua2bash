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
               nesting = nesting }
    setmetatable(result, bashDslMtab)
    return result
end

-- bashString:
-- { activeChars, begin = "${", string = "foo", end = "}", hostsNests = 0}

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

local function bashStringEmit(bstring)
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
bDsl.lift = bDslAll

bashDslMtab.__concat = bDslConcat
bashDslMtab.__call = bashStringEmit

--print(getmetatable(bDsl.c("foo")).__call)
--print(((bDsl.c("foo") .. iterate(bDsl.pE, "moo", 5)) .. bDsl.pE("moo"))())

return bDsl
