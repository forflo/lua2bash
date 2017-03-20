function emitId(ast, env, lines)
    if ast.tag ~= "Id" then
        print("emitId(): not a Id node")
        os.exit(1)
    end

    local inSome, coordinate = isInSomeScope(env, ast[1])
    if inSome == false then
        return "VAR_NIL", lines -- TODO: check
    end

    return "!" .. coordinate[2].emitVarname
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
    local commonSuffix =
        "${" .. topScope(env).environmentCounter .. "}"
        .. "_" .. getUniqueId(env)

    local varname = env.tempVarPrefix .. commonSuffix
    local valname = env.tempValPrefix .. commonSuffix

    return varname, valname
end

function getTempValname(env)
    local commonSuffix =
        "${" .. topScope(env).environmentCounter .. "}"
        .. "_" .. getUniqueId(env)


    return env.tempValPrefix .. commonSuffix
end

function emitTempVar(ast, env, lines, typ, content)
    tempVal = getTempValname(env)

    lines[#lines + 1] = augmentLine(
        env, string.format("eval %s=\\(%s %s\\)", tempVal, content, typ))

    return tempVal
end

-- TODO:
-- eigentlich müssten hier nur temporäre valueslots ausgegeben werden...
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

            emitTable(v, env, lines, tableId)

            env.tablePath = oldTablePath
        end

    end

    return env.tablePrefix .. "_" .. tableId
end

function emitCall(ast, env, lines)
    if ast[1][1] == "print" then
        local location = emitExpression(ast[2], env, lines)
        lines[#lines + 1] = augmentLine(
            env, string.format("eval echo %s", derefValToValue(location)))
    else
        local varname = emitExpression(ast[1], env, lines)
        lines[#lines + 1] = augmentLine(
            env,
            string.format("eval %s %s",
                          derefValToValue(varname),
                          derefValToType(varname))
        )
    end
end

-- currying just for fun
function fillup(column)
    return function(str)
        local l = string.len(str)
        if column > l then
            return string.format("%s%s", str, string.rep(" ", column - l))
        else
            return str
        end
    end
end

-- function composition
-- compose(fun1, fun2)("foobar") = fun1(fun2("foobar"))
function compose(funOuter)
    return function(funInner)
        return function(x)
            return funOuter(funInner(x))
        end
    end
end

function emitEnvCounter(env, lines, envName)
    imap({string.format("if [ -z $%s ]; then", envName),
          string.format("%s%s=0;",
                        string.rep(" ", env.indentSize),
                        envName),
          string.format("else"),
          string.format("%s((%s++))",
                        string.rep(" ", env.indentSize),
                        envName,
                        envName),
          string.format("fi")},
        compose(
            function(e)
                lines[#lines + 1] = augmentLine(env, e, "environment counter")
                return lines
        end)(fillup(50)))
end

function snapshotEnvironment(ast, env, lines, usedSyms)
    return imap(
        usedSyms,
        function(sym)
            local assignmentAst = parser.parse(
                string.format("local %s = %s;",
                              sym,
                              sym))

            -- we only need the local ast not the block surrounding it
            return emitLocal(assignmentAst[1], env, lines)
    end)
end

function emitFunction(ast, env, lines)
    local namelist = ast[1]
    local block = ast[2]
    local functionId = getUniqueId(env)
    local usedSyms = getUsedSymbols(block)
    local oldEnv = topScope(env).environmentCounter

    pushScope(env, "function", "fun" .. functionId)
    lines[#lines + 1] =
        augmentLine(env, topScope(env).environmentCounter .. "=$" .. oldEnv)
    local varname, _ =
        emitTempVar(ast, env, lines,
                    "${" .. topScope(env).environmentCounter .. "}",
                    "BF" .. functionId)
    lines[#lines + 1] = augmentLine(env, "", "Environment Snapshotting")
    snapshotEnvironment(ast, env, lines, usedSyms)

    lines[#lines + 1] = augmentLine(
        env,
        string.format("function BF%s {", functionId))
--    lines = emitBlock(ast[2], env, lines)

    incCC(env)
    lines[#lines + 1] = augmentLine(
        env,
        string.format("%s=$1", topScope(env).environmentCounter))

    imap(block, function(stmt) emitStatement(stmt, env, lines) end)
    decCC(env)

    -- end of function definition
    lines[#lines + 1] = augmentLine(env, "}")

    popScope(env)

    return varname
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
    tempVal = getTempValname(env)

    lines[#lines + 1] = augmentLine(
        env,
        string.format("eval %s=\"\\$((%s%s))\"",
                      tempVal,
                      strToOpstring(ast[1]),
                      derefValToValue(operand2)))

    return tempVal
end

function emitBinop(ast, env, lines)
    local ergId1 = getUniqueId(env)
    local tempVal = getTempValname(env)
    local left = emitExpression(ast[2], env, lines)
    local right = emitExpression(ast[3], env, lines)
    lines[#lines + 1] = augmentLine(
        env,
        string.format("eval %s=\"\\$((%s%s%s))\"",
                      tempVal,
                      derefValToValue(left),
                      strToOpstring(ast[1]),
                      derefValToValue(right)))
    return tempVal
end

function emitExplist(ast, env, lines)
    if ast.tag ~= "ExpList" then
        print("emitExplist(): not an explist node!")
        os.exit(1)
    end
    local locations = {}
    for k, expression in ipairs(ast) do
        local tempVal = emitExpression(expression, env, lines)
        local tempVnRhs = emitTempVar(ast, env, lines,
                                      "NKN", derefValToValue(tempVal))
        locations[#locations + 1] = tempVnRhs
    end
    return locations
end

function scopeSetLocalFirstTime(ast, env, scope, idString)
    local currentPathPrefix = getScopePath(env)
    local emitVN = env.varPrefix .. "${" .. scope.environmentCounter .. "}"
        .. "_" .. currentPathPrefix .. "_" .. idString
    scope.scope[idString] = {
        value = 0,
        redefCount = 1,
        emitCurSlot = env.valPrefix .. "_DEF1_" .. emitVN,
        emitVarname = emitVN
    }
end

function scopeSetGlobal(env, idString)
    local emitVN = env.varPrefix .. "${" .. env.scopeStack[1].environmentCounter
        .. "}_" .. "G_" .. idString
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
    local locations = emitExplist(ast[2], env, lines)

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
            local t = iter()
            emitVarUpdate(env,
                          lines,
                          topScope[idString].emitVarname,
                          topScope[idString].emitCurSlot,
                          derefValToValue(t),
                          derefValToType(t))
        elseif inSome == true or inSome == false then
            -- in both cases, define in top scope
            scopeSetLocalFirstTime(ast, env,
                                   env.scopeStack[#env.scopeStack],
                                   idString)
            local t = iter()
            emitVarUpdate(env,
                          lines,
                          topScope[idString].emitVarname,
                          topScope[idString].emitCurSlot,
                          derefValToValue(t),
                          derefValToType(t))
        end
    end
end

function emitVarUpdate(env, lines, varname, valuename, value, typ)
            lines[#lines + 1] = augmentLine(
                env,
                string.format("eval %s=%s", varname, valuename))
            lines[#lines + 1] = augmentLine(
                env,
                string.format("eval %s=\\(\"%s\" %s\\)", valuename, value, typ))
end

function emitSet(ast, env, lines)
    local rhsTempresults = emitExplist(ast[2], env, lines)
    emitVarlist(ast[1], env, lines, rhsTempresults)
end

-- TODO: emitPrefixexp should be named emitLefthand
function emitVarlist(ast, env, lines, rhsLocations)
    local iterator = statefulIIterator(rhsLocations)

    for k, lvalexp in ipairs(ast) do
        -- true = run in lval context
        _, lines = emitPrefixexp(lvalexp, env, lines, iterator(), true)
    end
end

function emitPrefixexp(ast, env, lines, rhsLoc, lvalContext)
    if lvalContext == true then
        emitPrefixexpAsLval(ast, env, lines, rhsLoc, lvalContext)
    else
        emitPrefixexpAsRval(ast, env, lines, {})
    end
end

function emitGlobalVar(varname, valuename, lines, env)
    lines[#lines + 1] = augmentLine(
        env,
        string.format("eval %s=%s", varname, valuename))
end

function emitUpdateGlobVar(valuename, value, lines, env)
    lines[#lines + 1] = augmentLine(
        env,
        string.format("eval %s=\"%s\"", valuename, value))
end

function emitPrefixexpAsLval(ast, env, lines, rhsLoc, lvalContext)
    if ast.tag == "Id" then
        local inSome, coordinate = isInSomeScope(env, ast[1])
        local location
        if not inSome then -- make var in global
            scopeSetGlobal(env, ast[1])
            inSome, coordinate = isInSomeScope(env, ast[1])

            emitGlobalVar(coordinate[2].emitVarname,
                          coordinate[2].emitCurSlot,
                          lines,
                          env)
        end
        location = emitId(ast, env, lines, lvalContext)
        emitUpdateGlobVar(coordinate[2].emitCurSlot,
                          derefValToValue(rhsLoc),
                          lines,
                          env)
        return location
    elseif ast.tag == "Index" then
        emitPrefixexp(ast[1], env, lines, rhsTemp, true, emitLocal)
        emitExpression(ast[2], env, lines)

        return nil
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
        return finalLocation
    end

    if ast.tag == "Id" then
        location = emitId(ast, env, lines)

        return recEndHelper(location, lines)
    elseif ast.tag == "Paren" then
        location = emitExpression(ast[1], env, lines)

        return recEndHelper(location, lines)
    elseif ast.tag == "Call"  then
        --
    elseif ast.tag == "Index" then
        location, lines = emitExpression(ast[2], env, lines)
        locationAccu[#locationAccu + 1] = derefLocation(location)
        emitPrefixexpAsRval(ast[1], env, lines, locationAccu)
    end
end
