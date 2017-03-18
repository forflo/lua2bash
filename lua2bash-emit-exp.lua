-- hier indirektion wenn in function!
function emitId(ast, env, lines)
    if ast.tag ~= "Id" then
        print("emitId(): not a Id node")
        os.exit(1)
    end

    local inSome, coordinate = isInSomeScope(env, ast[1])
    if inSome == false then
        return "VAR_NIL", lines -- TODO: check
    end

    return env.varPrefix .. "_"
        .. coordinate[1].pathPrefix
        .. "_" .. ast[1],
    lines
end

function emitNumber(ast, env, lines)
    if ast.tag ~= "Number" then
        print("emitNumber(): not a Number node")
        os.exit(1)
    end

    return emitTempVar(ast, env, lines, "NUM", ast[1])
end

function emitNil(ast, env, lines)
    if ast.tag ~= "Nil" then
        print("emitNil(): not a Nil node")
        os.exit(1)
    end

    return emitTempVar(ast, env, lines, "NIL", "")
end

function getTempVarname()
    local varname = join({env.tempVarPrefix,
                      "${" .. topScope(env).environmentCounter .. "}",
                      getUniqueId(env)}, '_')

    return varname, env.tempValPrefix .. '_' .. varname
end

function emitTempVar(ast, env, lines, typ, content)
    tempVn, tempVl = getTempVarname()

    lines[#lines + 1] = augmentLine(
        env, string.format("eval %s=\"%s\"", tempVn, typ, tempVl))
    lines[#lines + 1] = augmentLine(
        env, string.format("eval %s=('%s' '%s')", tempVl, content, typ))

    return tempVn, lines
end

function emitString(ast, env, lines)
    if ast.tag ~= "String" then
        print("emitString(): not a string node")
        os.exit(1)
    end

    return emitTempVar(ast, env, lines, "STR", ast[1])
end

function emitFalse(ast, env, lines)
    if ast.tag ~= "False" then
        print("emitFalse(): not a False node!")
        os.exit(1)
    end

    return emitTempVar(ast, env, lines, "FLS", "0")
end

function emitTrue(ast, env, lines)
    if ast.tag ~= "True" then
        print("emitTrue(): not a True node!")
        os.exit(1)
    end

    return emitTempVar(ast, env, lines, "TRU", "0")
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
        if (v.tag == "Pair") then
            print("Associative tables not yet supported")
            os.exit(1)
        elseif v.tag ~= "Table" then
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

function emitParen(ast, env, lines)
    return emitExpression(ast[1], env, lines)
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
    if #ast == 3 then return emitBinop(ast, env, lines)
    elseif #ast == 2 then return emitUnop(ast, env, lines)
    else
        print("Not supported!")
        os.exit(1)
    end
end

function emitUnop(ast, env, lines)
    operand2, lines = emitExpression(ast[2], env, lines)
    tempVn, _ = getTempVarname()

    lines[#lines + 1] = augmentLine(
        env,
        string.format("eval %s=\"$((%s%s))\"",
                      tempVn,
                      strToOpstring(ast[1]),
                      derefVarToValue(operand2)))

    return tempVn, lines
end

function emitBinop(ast, env, lines)
    local ergId1 = getUniqueId(env)
    local tempVn, tempVl = getTempVarname(env)
    lines[#lines + 1] = augmentLine(
        env,
        string.format("%s=%s", tempVn, tempVl))
    local left, lines = emitExpression(ast[2], env, lines)
    local right, lines = emitExpression(ast[3], env, lines)
    lines[#lines + 1] = augmentLine(
        env,
        string.format("eval %s=\"$((%s%s%s}))\"",
                      tempVl,
                      derefVarToValue(left),
                      strToOpstring(ast[1]),
                      derefVarToValue(right)))
    return tempVn, lines
end

function emitExplist(ast, env, lines)
    if ast.tag ~= "ExpList" then
        print("emitExplist(): not an explist node!")
        os.exit(1)
    end
    local locations = {}
    for k, expression in ipairs(ast) do
        local tempVn, _ = emitExpression(expression, env, lines)
        local tempVnRhs, _ = emitTempVar(ast, env, lines,
                                         "NKN", derefVarToValue(tempVn))
        locations[#locations + 1] = tempVnRhs
    end
    return locations, lines
end

function scopeSetLocalFirstTime(ast, env, scope, idString)
    local currentPathPrefix = getScopePath(env)
    local emitVN = env.varPrefix .. "_" .. currentPathPrefix .. "_" .. idString
    scope[idString] = {
        value = 0,
        redefCount = 1,
        emitCurSlot = env.valPrefix .. "_DEF1_" .. emitVN,
        emitVarname = emitVN
    }
end

function emitGlobal(env, idString)
    local emitVN = env.varPrefix .. "_" .. "G_" .. idString
    env.scopeStack[1].scope[idString] = {
        value = 0,
        redefCount = 1,
        emitCurSlot = env.valPrefix .. "_DEF1_" .. emitVN,
        emitVarname = emitVN
    }
end

function scopeSetLocalAgain(ast, env, varAttr)
    local currentPathPrefix = getScopePath(env)
    varAttr.redefCount = varAttr.redefCount + 1
    varAttr.emitCurSlot = env.valPrefix .. "_DEF" .. varAttr.redefCount
        .. "_" .. varAttr.emitVarname
end

function emitLocal(ast, env, lines)
    local varNames = {}
    for i = 1, #ast[1] do
        varNames[i] = ast[1][i][1]
    end

    local topScope = env.scopeStack[#env.scopeStack].scope
    local locations, lines = emitExplist(ast[2], env, lines)

    local memNumDiff = tblCountAll(varNames) - tblCountAll(locations)
    if memNumDiff > 0 then -- extend number of expressions to fit varNamelist
        locations[#locations + 1] = "DUMMY"
    end

    local iter = statefulIIterator(locations)
    for _, idString in pairs(varNames) do
        local inSome, attr1 = isInSomeScope(env, idString)
        local inSame, attr2 = isInSameScope(env, idString)
        if inSame then
            scopeSetLocalAgain(ast, env, attr2)
            emitVarUpdate(env,
                          lines,
                          topScope[idString].emitVarname,
                          topScope[idString].emitCurSlot,
                          derefVarToValue(iter()))
        elseif inSome == true or inSome == false then
            -- in both cases, define in top scope
            scopeSetLocalFirstTime(ast, env, topScope, idString)
            emitVarUpdate(env,
                          lines,
                          topScope[idString].emitVarname,
                          topScope[idString].emitCurSlot,
                          derefVarToValue(iter()))
        end
    end
    return lines
end

function emitVarUpdate(env, lines, varname, valuename, value)
            lines[#lines + 1] = augmentLine(
                env,
                string.format("eval %s=%s", varname, valuename))
            lines[#lines + 1] = augmentLine(
                env,
                string.format("eval %s=\"%s\"", valuename, value))
end

-- if emitLocal is set => emit to local scope
function emitSet(ast, env, lines)
    local rhsTempresults, lines = emitExplist(ast[2], env, lines)
    lines = emitVarlist(ast[1], env, lines, rhsTempresults)
    return lines
end

-- TODO: emitPrefixexp should be named emitLefthand
function emitVarlist(ast, env, lines, rhsLocations)
    local iterator = statefulIIterator(rhsLocations)

    for k, lvalexp in ipairs(ast) do
        -- true = run in lval context
        _, lines = emitPrefixexp(lvalexp, env, lines, iterator(), true)
    end

    return lines
end

function emitPrefixexp(ast, env, lines, rhsLoc, lvalContext)
    if lvalContext == true then
        return emitPrefixexpAsLval(ast, env, lines, rhsLoc, lvalContext)
    else
        return emitPrefixexpAsRval(ast, env, lines, {})
    end
end

function emitPrefixexpAsLval(ast, env, lines, rhsLoc, lvalContext)
    if ast.tag == "Id" then
        local inSome, coordinate = isInSomeScope(env, ast[1])
        local location
        if not inSome then -- make var in global
            emitGlobal(env, ast[1])
            inSome, coordinate = isInSomeScope(env, ast[1])
            lines[#lines + 1] = augmentLine(
                env,
                string.format("%s=(\"\" '%s')",
                              coordinate[2].emitVarname,
                              coordinate[2].emitCurSlot))
        end

        location, lines = emitId(ast, env, lines, lvalContext)

        lines[#lines + 1] = augmentLine(
            env,
            string.format("%s=\"%s\"",
                          coordinate[2].emitCurSlot,
                          derefLocation(rhsLoc)))


        return location, lines
    elseif ast.tag == "Index" then
        _, lines = emitPrefixexp(ast[1], env, lines, rhsTemp, true, emitLocal)
        _, lines = emitExpression(ast[2], env, lines)

        return _, lines
    end
end

function emitPrefixexpAsRval(ast, env, lines, locationAccu)
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

    if ast.tag == "Id" then
        location = emitId(ast, env, lines)

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
