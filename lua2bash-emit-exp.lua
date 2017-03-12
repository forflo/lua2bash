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
        lines[#lines + 1] = augmentLine(
            env,
            string.format("%s_%s%s=(\"%s\", 'VAL_%s_%s%s')",
                          env.varPrefix, getScopePath(ast, env),
                          ast[1], ast.tag, env.varPrefix,
                          getScopePath(ast,env), ast[1]))
    end

    return getIdLvalue(ast, env, lines), lines
end

function makeLhs(env)
    return env.tempPrefix .. "_" .. getUniqueId(env)
end

function emitNumber(ast, env, lines)
    if ast.tag ~= "Number" then
        print("emitNumber(): not a Number node")
        os.exit(1)
    end

    lhs = makeLhs(env)
    lines[#lines + 1] = augmentLine(
        env, string.format("%s=(\"NUM\" 'VAL_%s')", lhs, lhs))
    lines[#lines + 1] = augmentLine(
        env, string.format("VAL_%s='%s'", lhs, ast[1]))

    return lhs, lines
end

function emitNil(ast, env, lines)
    if ast.tag ~= "Nil" then
        print("emitNil(): not a Nil node")
        os.exit(1)
    end

    lhs = makeLhs(env)
    lines[#lines + 1] = augmentLine(
        env, string.format("%s=(\"%s\" '')", lhs, ast.tag))

    return lhs, lines
end

function emitString(ast, env, lines)
    if ast.tag ~= "String" then
        print("emitString(): not a string node")
        os.exit(1)
    end

    lhs = makeLhs(env)
    lines[#lines + 1] = augmentLine(
        env, string.format("%s=(\"%s\" '%s')", lhs, ast.tag, ast[1]))

    return lhs, lines
end

function emitFalse(ast, env, lines)
    if ast.tag ~= "False" then
        print("emitFalse(): not a False node!")
        os.exit(1)
    end

    lhs = makeLhs(env)
    lines[#lines + 1] = augmentLine(
        env, string.format("%s=(\"Bool\" '%s')", lhs, ast.tag))

    return lhs, lines
end

function emitTrue(ast, env, lines)
    if ast.tag ~= "True" then
        print("emitTrue(): not a True node!")
        os.exit(1)
    end

    lhs = makeLhs(env)
    lines[#lines + 1] = augmentLine(
        env, string.format("%s=(\"Bool\" '%s')", lhs, ast.tag))

    return lhs, lines
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

    lines[#lines + 1] = augmentLine(
        env, string.format("%s_%s=(\"TBL\" 'VAL_%s_%s')",
                           env.tablePrefix .. env.tablePath,
                           tableId, env.tablePrefix, tableId))

    lines[#lines + 1] = augmentLine(
        env, string.format("VAL_%s_%s='%s_%s'",
                           env.tablePrefix .. env.tablePath,
                           tableId, env.tablePrefix, tableId))

    for k,v in ipairs(ast) do
        if (v.tag ~= "Table") then
            location, lines = emitExpression(ast[k], env, lines)


            lines[#lines + 1] = augmentLine(
                env,
                string.format("%s_%s%s=(\"VAR\" 'VAL_%s_%s%s')",
                              env.tablePrefix, tableId,
                              env.tablePath .. "_" .. k,
                              env.tablePrefix, tableId,
                              env.tablePath .. "_" .. k))

            lines[#lines + 1] = augmentLine(
                env,
                string.format("VAL_%s_%s%s=\"%s\"", env.tablePrefix,
                              tableId, env.tablePath .. "_" .. k,
                              derefLocation(location)))
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
        lines[#lines + 1] = augmentLine(
            env, string.format("echo %s", derefLocation(location)))

        return nil, lines
    end
end

function emitFunction(ast, env, lines)
    local namelist = ast[1]
    local block = ast[2]
    local functionId = getUniqueId(env)


    -- first make environment
    lines[#lines + 1] = augmentLine(
        env,
        string.format("%s_%s=(\"RET\", 'B%s_%s')",
                      env.functionPrefix, functionId,
                      env.functionPrefix, functionId))

    lines[#lines + 1] = augmentLine(
        env,
        string.format("%s_%s_RET=(\"VAR\" '%s_%s_VAL_RET')",
                      env.functionPrefix, functionId,
                      env.functionPrefix, functionId))

    -- initialize local variables
    for k, v in ipairs(namelist) do
        lines[#lines + 1] = augmentLine(
            env,
            string.format("%s_%s_LCL_%s_%s=(\"VAR\", '%s_%s_VAL_%s_%s')",
                          env.functionPrefix, functionId,
                          env.varPrefix, v[1],
                          env.functionPrefix, functionId,
                          env.varPrefix, v[1]))
    end

    -- initialize environment
    -- TODO: generalize

    -- begin of function definition
    lines[#lines + 1] = augmentLine(
        env, string.format("function B%s_%s () {",
                           env.functionPrefix, functionId))

    -- recurse into the function body
    lines = emitBlock(ast[2], env, lines) -- TODO: Think return!!

    -- end of function definition
    lines[#lines + 1] = augmentLine(env, "}")

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

    lines[#lines + 1] = augmentLine(
        env,
        string.format("%s_%s=\"$((%s${%s[1]}))\"",
                      tempE.tempPrefix, id,
                      strToOpstring(ast[1]), right))

    return env.tempPrefix .. "_" .. id, lines
end


function emitBinop(ast, env, lines)
    local ergId1 = getUniqueId(env)

    lines[#lines + 1] = augmentLine(
        env,
        string.format("%s_%s=(\"VAR\" 'VAL_%s_%s')",
                      env.tempPrefix, ergId1, env.tempPrefix, ergId1))

    local left, lines = emitExpression(ast[2], env, lines)
    local right, lines = emitExpression(ast[3], env, lines)

    lines[#lines + 1] = augmentLine(
        env,
        string.format("VAL_%s_%s=\"$((${!%s[1]}%s${!%s[1]}))\"",
                      env.tempPrefix, ergId1,
                      left,
                      strToOpstring(ast[1]),
                      right))

    return env.tempPrefix .. "_" .. ergId1, lines
end

-- TODO: implement local
-- TODO: emitPrefixexp should be named emitLefthand
function emitVarlist(ast, env, lines, emitLocal)
    for k, lvalexp in ipairs(ast) do
        -- true = run in lval context
        _, lines = emitPrefixexp(lvalexp, env, lines, k, true)
    end

    return lines
end

function emitExplist(ast, env, lines)
    if ast.tag ~= "ExpList" then
        print("emitExplist(): not an explist node!")
        os.exit(1)
    end

    for k,expression in ipairs(ast) do
        local location
        location, lines = emitExpression(expression, env, lines)

        lines[#lines + 1] = augmentLine(
            env, string.format("RHS_%s=(\"VAR\" 'RHS_%s_VAL')", k, k))
        lines[#lines + 1] = augmentLine(
            env, string.format("RHS_%s_VAL=\"%s\"", k, derefLocation(location)))
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

    -- true means make assignment local
    lines = emitSet(tempSetAST, env, lines, true)

    return lines
end

-- if emitLocal is set => emit to local scope
function emitSet(ast, env, lines, emitLocal)
    lines = emitExplist(ast[2], env, lines)
    lines = emitVarlist(ast[1], env, lines, emitLocal)
    return lines
end

function emitPrefixexp(ast, env, lines, rhsTemp, lvalContext)
    if lvalContext == true then
        return emitPrefixexpAsLval(ast, env, lines, rhsTemp, lvalContext)
    else
        return emitPrefixexpAsRval(ast, env, lines, rhsTemp, {})
    end
end

-- TODO: Declaration and definition only once!
-- a=3 (if a already defined) => eval ${!VAR_a[1]}
function emitPrefixexpAsLval(ast, env, lines, rhsTemp, lvalContext)
    if ast.tag == "Id" then
        local location, lines = emitId(ast, env, lines, lvalContext)
        lines[#lines + 1] = augmentLine(
            env,
            string.format("VAL_%s=\"%s\"", location,
                          derefLocation("RHS_" .. rhsTemp)))

        return location, lines
    elseif ast.tag == "Index" then
        _, lines = emitPrefixexp(ast[1], env, lines, true)
        _, lines = emitExpression(ast[2], env, lines)

        return _, lines
    end
end

function emitPrefixexpAsRval(ast, env, lines, rhsTemp, locationAccu)
    local recEndHelper = function (location, lines)

        locationString = join(tableReverse(extractIPairs(locationAccu)), '_')

        location = derefLocation(location) .. "_" .. locationString

        finalLocation = makeLhs(env)
        lines[#lines + 1] = augmentLine(
            env, string.format("%s=(\"VAR\" 'VAL_%s')",
                               finalLocation,
                               finalLocation))
        lines[#lines + 1] = augmentLine(
            env, string.format("VAL_%s=''",
                               finalLocation))
        lines[#lines + 1] = augmentLine(
            env, string.format("eval ${%s[1]}=\\%s",
                               finalLocation,
                               derefLocation(location)))

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
