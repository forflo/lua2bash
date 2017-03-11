local parser = require "lua-parser.parser"
local pp = require "lua-parser.pp"

if #arg ~= 1 then
    print("Usage: lua2bash.lua <string>")
    os.exit(1)
end

local ast, error_msg = parser.parse(arg[1], "example.lua")
if not ast then
    print(error_msg)
    os.exit(1)
end

function dumpLines(lines)
    print("Linedump")
    for k,v in ipairs(lines) do
        print(v)
    end
    print("end ld")
end

function zipI(left, right)
    if (left == nil or right == nil) then return nil end
    if #left ~= #right then return nil end

    result = {}

    for k,v in ipairs(left) do
        result[k] = {left[k], right[k]}
    end

    return result
end

function tableIAdd(left, right)
    if (left == nil) then return right end
    if (right == nil) then return left end

    result = {}
    for k,v in ipairs(left) do
        result[#result + 1] = v
    end
    for k,v in ipairs(right) do
        result[#result + 1] = v
    end

    return result
end

function emitBlock(ast, env, lines)
    for k,v in ipairs(ast) do
        if type(v) == "table" then
            lines = tableIAdd(lines, emitStatement(v, env, {}))
        else
            print("emitBlock error!??")
            os.exit(1)
        end
    end
    return lines
end

function emitStatement(ast, env, lines)
    if ast.tag == "Call" then

    elseif ast.tag == "Fornum" then

    elseif ast.tag == "ForIn" then

    elseif ast.tag == "Function" then

    elseif ast.tag == "If" then

    elseif ast.tag == "While" then

    elseif ast.tag == "Do" then

    elseif ast.tag == "Set" then
        return emitSet(ast, env, lines)
    end
end


globalIdCount = 0

function getUniqueId()
    globalIdCount = globalIdCount + 1
    return globalIdCount
end

-- todo: refactor name to getScopePath
function h_getNamePrefix(ast, env)
    result = ""
    for k,scope in ipairs(env.scopeStack) do
        result = result .. scope .. "_"
    end
    return result
end

function getIdLvalue(ast, env, lines)
    if ast.tag ~= "Id" then
        print("getIdLvalue(): not a Id node")
        os.exit(1)
    end

    return env.varPrefix .. "_" .. h_getNamePrefix(ast, env) .. ast[1]
end

-- function emitIdLval(ast, env, lines)
--     if ast.tag ~= "Id" then
--         print("emitId(): not a Id node")
--         os.exit(1)
--     end
--
--     tempResult = makeLhs(env)
--     lines[#lines + 1] = string.format("%s=(\"%s\" '')", tempResult)
-- end

function emitId(ast, env, lines, lvalContext)
    if ast.tag ~= "Id" then
        print("emitId(): not a Id node")
        os.exit(1)
    end

    if lvalContext == true then
        lines[#lines + 1] =
            string.format("%s_%s%s=(\"%s\", '')",
                          env.varPrefix, h_getNamePrefix(ast, env),
                          ast[1], ast.tag)
    end

    return getIdLvalue(ast, env, lines), lines
end

function makeLhs(env)
    return env.erg .. "_" .. getUniqueId()
end

function emitNumber(ast, env, lines)
    if ast.tag ~= "Number" then
        print("emitNumber(): not a Number node")
        os.exit(1)
    end

    lhs = makeLhs(env)
    lines[#lines + 1] = string.format("%s=(\"%s\" '%s')",
                                      lhs, ast.tag, ast[1])

    return lhs, lines
end

function emitNil(ast, env, lines)
    if ast.tag ~= "Nil" then
        print("emitNil(): not a Nil node")
        os.exit(1)
    end

    lhs = makeLhs(env)
    lines[#lines + 1] = string.format("%s=(\"%s\" '')",
                                      lhs, ast.tag)

    return lhs, lines
end

function emitString(ast, env, lines)
    if ast.tag ~= "String" then
        print("emitString(): not a string node")
        os.exit(1)
    end

    lhs = makeLhs(env)
    lines[#lines + 1] = string.format("%s=(\"%s\" '%s')",
                                      lhs, ast.tag, ast[1])

    return lhs, lines
end

function emitFalse(ast, env, lines)
    if ast.tag ~= "False" then
        print("emitFalse(): not a False node!")
        os.exit(1)
    end

    lhs = makeLhs(env)
    lines[#lines + 1] = string.format("%s=(\"Bool\" '%s')",
                                      lhs, ast.tag)

    return lhs, lines
end

function emitTrue(ast, env, lines)
    if ast.tag ~= "True" then
        print("emitTrue(): not a True node!")
        os.exit(1)
    end

    lhs = makeLhs(env)
    lines[#lines + 1] = string.format("%s=(\"Bool\" '%s')",
                                      lhs, ast.tag)

    return lhs, lines
end

function emitExplist(ast, env, lines)
    if ast.tag ~= "ExpList" then
        print("emitExplist(): not an explist node!")
        os.exit(1)
    end

    for k,expression in ipairs(ast) do

        lines[#lines + 1] = string.format("RHS_%s%s=(\"%s\" '')\n",
                                          h_getNamePrefix(ast,env),
                                          k, expression.tag)
        location, lines = emitExpression(expression, env, lines)

        lines[#lines + 1] = string.format("RHS_%s%s[1]=${%s[1]}\n", k,
                                          h_getNamePrefix(ast,env),
                                          location)
    end

    return lines
end

function emitPrefixexpAsLval(ast, env, lines)
    if ast.tag == "Id" then
        location, lines = emitId(ast, env, lines, lvalContext)
        lines[#lines + 1] =
            string.format("%s[1]=\"${%s[1]}\"",
                          location, "RHS_" .. env.currentRval)

        return location, lines
    elseif ast.tag == "Index" then
        _, lines = emitPrefixexp(ast[1], env, lines, true)
        _, lines = emitExpression(ast[2], env, lines)

        return _, lines
    end
end

function emitPrefixexpAsRval(ast, env, lines, locationAccu)
    local recEndHelper = function (location, lines)
        locationString = ""

        for k,v in ipairs(locationAccu) do
            locationString = locationString .. "_" .. v
        end

        location = location .. locationString

        finalLocation = makeLhs(env)
        lines[#lines + 1] =
            string.format("%s=(\"TMP\" '')", finalLocation)
        lines[#lines + 1] =
            string.format("eval %s[1]=\\${%s[1]}", finalLocation, location)

        return finalLocation, lines
    end

    --
    if ast.tag == "Id" then
        location = getIdLvalue(ast, env, lines)

        return recEndHelper(location, lines)
    elseif ast.tag == "Paren" then
        location, lines = emitExpression(ast[1], env, lines)
        print(location)

        return recEndHelper(location, lines)
    elseif ast.tag == "Call"  then
        --
    elseif ast.tag == "Index" then
        location, lines = emitExpression(ast[2], env, lines)
        locationAccu[#locationAccu + 1] = "${" .. location .. "[1]}"
        _, lines = emitPrefixexpAsRval(ast[1], env, lines, locationAccu)

        return _, lines
    end
end

function emitPrefixexp(ast, env, lines, lvalContext)
    if lvalContext == true then
        return emitPrefixexpAsLval(ast, env, lines)
    else
        return emitPrefixexpAsRval(ast, env, lines, {})
    end
end

-- prefixes each table member with env.tablePrefix
-- uses env.tablePath
function emitTable(ast, env, lines, tableId)
    if ast.tag ~= "Table" then
        print("emitTable(): not a Table!")
        os.exit(1)
    end

    if tableId == nil then
        tableId = getUniqueId()
    end

    lines[#lines + 1] = string.format("%s_%s=(\"TBL\" '')",
                                      env.tablePrefix .. env.tablePath,
                                      tableId)

    for k,v in ipairs(ast) do

        if (v.tag ~= "Table") then
            location, lines = emitExpression(ast[k], env, lines)


            lines[#lines + 1] =
                string.format("%s_%s%s=(\"%s\" '')",
                              env.tablePrefix, tableId,
                              env.tablePath .. "_" .. k, ast[k].tag)

            lines[#lines + 1] =
                string.format("%s_%s%s[1]=\"${%s[1]}\"",
                              env.tablePrefix, tableId,
                              env.tablePath .. "_" .. k, location)
        else
            oldTablePath = env.tablePath
            env.tablePath = env.tablePath .. "_" .. k

            _, lines = emitTable(v, env, lines, tableId)

            env.tablePath = oldTablePath
        end

    end

    return env.tablePrefix .. "_" .. tableId, lines
end

function emitExpression(ast, env, lines)
    if ast.tag == "Op" then return emitOp(ast, env, lines)
    elseif ast.tag == "Id" then return emitId(ast, env, lines)
    elseif ast.tag == "True" then return emitTrue(ast, env, lines)
    elseif ast.tag == "False" then return emitFalse(ast, env, lines)
    elseif ast.tag == "Nil" then return emitNil(ast, env, lines)
    elseif ast.tag == "Number" then return emitNumber(ast, env, lines)
    elseif ast.tag == "String" then return emitString(ast, env, lines)
    elseif ast.tag == "Table" then return emitTable(ast, env, lines)
    elseif ast.tag == "Function" then return emitFunction(ast, env, lines)
    elseif ast.tag == "Call" then return emitCall(ast, env, lines)
    elseif ast.tag == "Paren" then return emitParen(ast, env, lines)
    elseif ast.tag == "Index" then return emitPrefixexp(ast, env, lines, false)
    else
        print("emitExpresison(): error!")
        os.exit(1)
    end
end

function strToOpstring(str)
    if str == "add" then return "+"
    elseif str== "sub" then return "-"
    elseif str == "mul" then return "*"
    elseif str == "div" then return "/"
    elseif str == "pow" then return "^"
    elseif str == "mod" then return "%"
    elseif str == "concat" then return ".." -- probably special case
    elseif str == "lt" then return "<"
    elseif str == "gt" then return ">"
    elseif str == "le" then return "<="
    elseif str == "le" then return "<="
    end
end

function emitOp(ast, env, lines)
    if ast.tag ~= "Op" then
        print("emitOp(): not an Op node!")
        os.exit(1)
    end

    if #ast == 3 then return emitBinop(ast, env, lines)
    elseif #ast == 2 then return emitUnop(ast, env, lines)
    else return nil
    end
end

function emitUnop(ast, env, lines)
    right, lines = emitExpression(ast[2], env, lines)
    id = getUniqueId()

    lines[#lines+1] =
        string.format("%s_%s=\"$((%s${%s[1]}))\"",
                      tempE.erg, id,
                      strToOpstring(ast[1]), right)

    return env.erg .. "_" .. id, lines
end


function emitBinop(ast, env, lines)
    local ergId1 = getUniqueId()

    lines[#lines + 1] = string.format("%s_%s=(\"TMP\" '')",
                                      env.erg, ergId1)

    local left, lines = emitExpression(ast[2], env, lines)
    local right, lines = emitExpression(ast[3], env, lines)

    lines[#lines + 1] =
        string.format("%s_%s[1]=\"$((${%s[1]}%s${%s[1]}))\"",
                      env.erg, ergId1,
                      left,
                      strToOpstring(ast[1]),
                      right)

    return env.erg .. "_" .. ergId1, lines
end

function emitVarlist(ast, env, lines)
    for k, lvalexp in ipairs(ast) do
        env.currentRval = k
        _, l1 = emitPrefixexp(lvalexp, env, {}, true) -- run in lval context
        lines = tableIAdd(lines, l1)
    end

    return lines
end

function emitSet(ast, env, lines)
    lines = tableIAdd(lines, emitExplist(ast[2], env, {}))
    lines = tableIAdd(lines, emitVarlist(ast[1], env, {}))
    return lines
end

sample={}
sample.scopeStack = {} -- rechts => neuer
sample.erg = "ERG"
sample.ergCnt = 0
sample.tablePrefix = "ATBL"
sample.varPrefix = "VAR"
sample.tablePath = ""

lines = emitBlock(ast, sample, {})

for k,v in ipairs(lines) do
    print(v)
end

os.exit(0)
