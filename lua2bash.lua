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

imap = function(tbl, func)
    local result = {}
    for k,v in ipairs(tbl) do
        result[#result + 1] = func(v)
    end

    return result
end

join = function(strings, char)
    local result = strings[1]
    if #strings == 1 then return strings[1] end
    for i=2, #strings do
            result = result .. char .. strings[i]
    end
    return result
end

function derefLocation(location)
    return string.format("${!%s[1]}", location)
end


function getUniqueId(env)
    env.globalIdCount = env.globalIdCount + 1
    return env.globalIdCount
end

-- todo: refactor name to getScopePath
function getScopePath(ast, env)
    local scopeNames = {}

    for i = 1, #env.scopeStack do
        scopeNames[#scopeNames + 1] = env.scopeStack[i].name
    end

    print(join(scopeNames, '_'))

    --result must be string
    return ""
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

function tableSlice(tbl, first, last, step)
  local sliced = {}

  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

function emitBlock(ast, env, lines)
    local scopeNumber = getUniqueId(env)
    local scopeName

    if #env.scopeStack ~= 0 then
        scopeName = "scope_" .. scopeNumber
    else
        scopeName = "G"
    end

    -- push new scope on top
    env.scopeStack[#env.scopeStack + 1] =
        {name = scopeName, scope = {}}

    -- emit all enclosed statements
    for k,v in ipairs(ast) do
        if type(v) == "table" then
            lines = emitStatement(v, env, lines)
        else
            print("emitBlock error!??")
            os.exit(1)
        end
    end

    -- pop the scope
    env.scopeStack[#env.scopeStack] = {}

    return lines
end

-- TODO: Inject name from for into the new scope
function emitFornum(ast, env, lines)
    -- push new scope only for the loop counter
    env.scopeStack[#env.scopeStack + 1] =
        {name = "loop_" .. getUniqueId(env), scope = {[ast[1][1]] = nil}}

    -- build syntax tree for set instruction
    local tempAST = {
        tag = "Set",
        pos = -1,
        {
            tag = "VarList",
            pos = -1,
            { tag = "Id", pos = -1, ast[1][1] }
        },
        {
            tag = "ExpList",
            pos = -1,
            ast[2]
        }
    }

    lines = emitSet(tempAST, env, lines)

    lines[#lines + 1] = "for ((;;)); do"

    local forBlock = ast[5]
    local tempASTIf = {
        tag = "If",
        pos = -1,
        {
            tag = "Op",
            pos = -1,
            "le",
            ast[1],
            ast[3],
        },
        forBlock,
        {
            tag = "Block",
            pos = -1,
            {
                tag = "SPECIAL",
                pos = -420,
                special = "break;"
            }
        }
    }
    -- extend forblock so that it increments the loop counter
    local incrementor, errormsg = -- TODO: only increments by 1. The
        -- increment needs to bee calculated before
        parser.parse(string.format("%s=%s+1", ast[1][1], ast[1][1]), nil)
    if not ast then
        print(errormsg)
        os.exit(1)
    end
    forBlock[#forBlock + 1] = incrementor[1]


    -- pp.dump(tempASTIf)
    lines = emitIf(tempASTIf, env, lines)


    lines[#lines + 1] = "true\ndone"

    -- pop the loop counter scope
    env.scopeStack[#env.scopeStack] = {}

    return lines
end

function emitIf(ast, env, lines)
    if #ast == 1 then
        -- make else
        --pp.dump(ast[1])
        lines = emitBlock(ast[1], env, lines)
    elseif #ast > 1 then
        -- calculate expression
        local location, l1 = emitExpression(ast[1], env, lines)

        lines[#lines + 1] =
        string.format("if [ \"%s\" = 1 ]; then", derefLocation(location))
        lines = emitBlock(ast[2], env, l1)

        lines[#lines + 1] = "else"

        lines = emitIf(tableSlice(ast, 3, nil, 1), env, lines)
        lines[#lines + 1] = string.format("true\nfi")
    end

    return lines
end

function emitLocal(ast, env, lines)
    local currentScope = env.scopeStack[#env.scopeStack]

    local tempVarlistAST = {
        tag = "VarList",
        pos = -1
    }
    local tempSetAST = {
        tag = "Set",
        pos = -1,
        tempVarlistAST,
        ast[2]
    }

    for i = 1, #ast[1] do
        tempVarlistAST[i] = ast[1][i]
    end

    lines = emitSet(tempSetAST, env, lines, true)
    -- true means make assignment local

    return lines
end

function emitForIn(ast, env, lines)
    -- TODO:

    return lines
end

function emitWhile(ast, env, lines)
    -- TODO:

    return lines
end

function emitRepeat(ast, env, lines)
    -- TODO:

    return lines
end

function emitStatement(ast, env, lines)
    if ast.tag == "Call" then
        _, lines = emitCall(ast, env, lines)
        return lines

    -- HACK: This was used to "Simplyfy implementation"
    elseif ast.tag == "SPECIAL" then
        lines[#lines + 1] = ast.special
        return lines
    elseif ast.tag == "Fornum" then
        return emitFornum(ast, env, lines)
    elseif ast.tag == "Local" then
        return emitLocal(ast, env, lines)
    elseif ast.tag == "ForIn" then
        return emitForIn(ast, env, lines)
    --elseif ast.tag == "Function" then
        -- not necessary here because the parser
        -- rewrites named function definitions into assignment statements
    elseif ast.tag == "Repeat" then
        return emitRepeat(ast, env, lines)
    elseif ast.tag == "If" then
        return emitIf(ast, env, lines)
    elseif ast.tag == "While" then
        return emitWhile(ast, env, lines)
    elseif ast.tag == "Do" then
        return emitBlock(ast[1], env, lines)
    elseif ast.tag == "Set" then
        return emitSet(ast, env, lines, false)
        -- false means that emitSet commits
        -- the assignment into global scope
        -- this is by default required by lua
    end
end


function getIdLvalue(ast, env, lines)
    if ast.tag ~= "Id" then
        print("getIdLvalue(): not a Id node")
        os.exit(1)
    end

    return env.varPrefix .. "_" .. getScopePath(ast, env) .. ast[1]
end

function emitId(ast, env, lines, lvalContext)
    if ast.tag ~= "Id" then
        print("emitId(): not a Id node")
        os.exit(1)
    end

    if lvalContext == true then
        lines[#lines + 1] =
            string.format("%s_%s%s=(\"%s\", 'VAL_%s_%s%s')",
                          env.varPrefix, getScopePath(ast, env),
                          ast[1], ast.tag, env.varPrefix,
                          getScopePath(ast,env), ast[1])
    end

    return getIdLvalue(ast, env, lines), lines
end

function makeLhs(env)
    return env.erg .. "_" .. getUniqueId(env)
end

function emitNumber(ast, env, lines)
    if ast.tag ~= "Number" then
        print("emitNumber(): not a Number node")
        os.exit(1)
    end

    lhs = makeLhs(env)
    lines[#lines + 1] = string.format("%s=(\"NUM\" 'VAL_%s')",
                                      lhs, lhs)
    lines[#lines + 1] = string.format("VAL_%s='%s'", lhs, ast[1])

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
        local location
        location, lines = emitExpression(expression, env, lines)

        lines[#lines + 1] = string.format("RHS_%s=(\"VAR\" 'RHS_%s_VAL')",
                                          k, k)
        lines[#lines + 1] = string.format("RHS_%s_VAL=\"%s\"", k,
                                          derefLocation(location))
    end

    return lines
end

-- TODO: Declaration and definition only once!
-- a=3 (if a already defined) => eval ${!VAR_a[1]}
function emitPrefixexpAsLval(ast, env, lines, lvalContext)
    if ast.tag == "Id" then
        local location, lines = emitId(ast, env, lines, lvalContext)
        lines[#lines + 1] =
            string.format("VAL_%s=\"%s\"",
                          location, derefLocation("RHS_" .. env.currentRval))

        return location, lines
    elseif ast.tag == "Index" then
        _, lines = emitPrefixexp(ast[1], env, lines, true)
        _, lines = emitExpression(ast[2], env, lines)

        return _, lines
    end
end


function emitPrefixexpAsRval(ast, env, lines, locationAccu)
    local recEndHelper = function (location, lines)
        local extractIPairs = function (tab)
            local result = {}
            for k,v in ipairs(tab) do
                result[#result + 1] = v
            end
            return result
        end

        local tableReverse = function (tab)
            local result = {}
            for i=#tab,1,-1 do
                result[#result + 1] = tab[i]
            end
            return result
        end

        locationString = join(tableReverse(extractIPairs(locationAccu)), '_')

        location = derefLocation(location) .. "_" .. locationString

        finalLocation = makeLhs(env)
        lines[#lines + 1] =
            string.format("%s=(\"VAR\" 'VAL_%s')", finalLocation, finalLocation)
        lines[#lines + 1] =
            string.format("VAL_%s=''", finalLocation)
        lines[#lines + 1] =
            string.format("eval ${%s[1]}=\\%s",
                          finalLocation, derefLocation(location))

        return finalLocation, lines
    end

    --
    if ast.tag == "Id" then
        location = getIdLvalue(ast, env, lines)

        return recEndHelper(location, lines)
    elseif ast.tag == "Paren" then
        location, lines = emitExpression(ast[1], env, lines)

        return recEndHelper(location, lines)
    elseif ast.tag == "Call"  then
        --
    elseif ast.tag == "Index" then
        location, lines = emitExpression(ast[2], env, lines)
        locationAccu[#locationAccu + 1] = derefLocation(location)
        _, lines = emitPrefixexpAsRval(ast[1], env, lines, locationAccu)

        return _, lines
    end
end

function emitPrefixexp(ast, env, lines, lvalContext)
    if lvalContext == true then
        return emitPrefixexpAsLval(ast, env, lines, lvalContext)
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
        tableId = getUniqueId(env)
    end

    lines[#lines + 1] = string.format("%s_%s=(\"TBL\" 'VAL_%s_%s')",
                                      env.tablePrefix .. env.tablePath,
                                      tableId, env.tablePrefix, tableId)

    lines[#lines + 1] = string.format("VAL_%s_%s='%s_%s'",
                                      env.tablePrefix .. env.tablePath,
                                      tableId, env.tablePrefix, tableId)

    for k,v in ipairs(ast) do
        if (v.tag ~= "Table") then
            location, lines = emitExpression(ast[k], env, lines)


            lines[#lines + 1] =
                string.format("%s_%s%s=(\"VAR\" 'VAL_%s_%s%s')",
                              env.tablePrefix, tableId,
                              env.tablePath .. "_" .. k,
                              env.tablePrefix, tableId,
                              env.tablePath .. "_" .. k)

            lines[#lines + 1] =
                string.format("VAL_%s_%s%s=\"%s\"", env.tablePrefix,
                              tableId, env.tablePath .. "_" .. k,
                              derefLocation(location))
        else
            oldTablePath = env.tablePath
            env.tablePath = env.tablePath .. "_" .. k

            _, lines = emitTable(v, env, lines, tableId)

            env.tablePath = oldTablePath
        end

    end

    return env.tablePrefix .. "_" .. tableId, lines
end

function emitCall(ast, env, lines)
    if ast[1][1] == "print" then
        local location, lines = emitExpression(ast[2], env, lines)
        lines[#lines + 1] =
            string.format("echo %s", derefLocation(location))

        return nil, lines
    end
end

function emitFunction(ast, env, lines)
    local namelist = ast[1]
    local block = ast[2]
    local functionId = getUniqueId(env)


    -- first make environment
    lines[#lines + 1] =
        string.format("%s_%s=(\"RET\", 'B%s_%s')",
                      env.functionPrefix, functionId,
                      env.functionPrefix, functionId)

    lines[#lines + 1] =
        string.format("%s_%s_RET=(\"VAR\" '%s_%s_VAL_RET')",
                      env.functionPrefix, functionId,
                      env.functionPrefix, functionId)

    -- initialize local variables
    for k, v in ipairs(namelist) do
        lines[#lines + 1] =
            string.format("%s_%s_LCL_%s_%s=(\"VAR\", '%s_%s_VAL_%s_%s')",
                          env.functionPrefix, functionId,
                          env.varPrefix, v[1],
                          env.functionPrefix, functionId,
                          env.varPrefix, v[1])
    end

    -- initialize environment
    -- TODO: generalize

    -- begin of function definition
    lines[#lines + 1] =
        string.format("function B%s_%s () {",
                      env.functionPrefix, functionId)

    -- recurse into the function body
    lines = emitBlock(ast[2], env, lines) -- TODO: Think return!!

    -- end of function definition
    lines[#lines + 1] = string.format("}")

    return string.format("%s_%s", env.functionPrefix, functionId), lines
end

-- always returns a location "string" and the lines table
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
    elseif str == "eq" then return "=="
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
    id = getUniqueId(env)

    lines[#lines + 1] =
        string.format("%s_%s=\"$((%s${%s[1]}))\"",
                      tempE.erg, id,
                      strToOpstring(ast[1]), right)

    return env.erg .. "_" .. id, lines
end


function emitBinop(ast, env, lines)
    local ergId1 = getUniqueId(env)

    lines[#lines + 1] = string.format("%s_%s=(\"VAR\" 'VAL_%s_%s')",
                                      env.erg, ergId1, env.erg, ergId1)

    local left, lines = emitExpression(ast[2], env, lines)
    local right, lines = emitExpression(ast[3], env, lines)

    lines[#lines + 1] =
        string.format("VAL_%s_%s=\"$((${!%s[1]}%s${!%s[1]}))\"",
                      env.erg, ergId1,
                      left,
                      strToOpstring(ast[1]),
                      right)

    return env.erg .. "_" .. ergId1, lines
end

-- TODO: implement local
function emitVarlist(ast, env, lines, emitLocal)
    for k, lvalexp in ipairs(ast) do
        env.currentRval = k
        _, l1 = emitPrefixexp(lvalexp, env, {}, true) -- run in lval context
        lines = tableIAdd(lines, l1)
    end

    return lines
end

-- if emitLocal is set => emit to local scope
function emitSet(ast, env, lines, emitLocal)
    lines = emitExplist(ast[2], env, lines)
    lines = emitVarlist(ast[1], env, lines, emitLocal)
    return lines
end

function tblCountAll(table)
    local counter = 0
    for _1, _2 in pairs(table) do
        counter = counter + 1
    end
    return counter
end

function scopeAddGlobal(id, value, scopeStack)
    if #scopeStack < 1 then
        print("scopeAddGlobal(): invalid size of scopeStack!")
        os.exit(1)
    end

    globalScope = scopeStack[1].scope
    globalScope.id = value
end

function scopePrint(scopeStack)
    for i = 1, #scopeStack do
        print(string.format("scope[%s] with name %s contains:",
                            i, scopeStack[i].name))
        for k, v in pairs(scopeStack[i].scope) do
            print(string.format("  %s = %s", k, v))
        end
    end
end

function scopeGetScopeNamelistScopeStack(scopeStack)
    result = {}
    for i = 1, #scopeStack do
        result[#result + 1] = scopeStack[i].name
    end
    return result
end

function findScope(scopeStack, scopeName)
    for k, v in pairs(scopeStack) do
        if v.name == scopeName then
            return v
        end
    end

    -- if no stack was found, nil will be given
    return nil
end

sample={}
sample.scopeStack = {} -- rechts => neuer
sample.erg = "ERG"
sample.functionPrefix = "AFUN"
sample.ergCnt = 0
sample.tablePrefix = "ATBL"
sample.varPrefix = "VAR"
sample.tablePath = ""
sample.scopeStack = {}
sample.funcArglist = {}
sample.globalIdCount = 0

-- scopeStack = {{name = "global", scope = {<varname> = "<location>"}},
--               {name = "anon1", scope = {}}, ...}

lines = emitBlock(ast, sample, {})

for k,v in ipairs(lines) do
    print(v)
end

os.exit(0)
