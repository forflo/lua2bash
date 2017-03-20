function emitId(ast, env, lines)
    if ast.tag ~= "Id" then
        print("emitId(): not a Id node")
        os.exit(1)
    end
    local inSome, coordinate = isInSomeScope(env, ast[1])
    if inSome == false then
        return "VAR_NIL", lines -- TODO: check
    end
    return emitTempVal(ast, env, lines,
                       derefVarToType(coordinate[2].emitVarname),
                       derefVarToValue(coordinate[2].emitVarname))
end

function emitNumber(ast, env, lines)
    if ast.tag ~= "Number" then
        print("emitNumber(): not a Number node")
        os.exit(1)
    end
    return emitTempVal(ast, env, lines, "NUM", ast[1])
end

function emitNil(ast, env, lines)
    if ast.tag ~= "Nil" then
        print("emitNil(): not a Nil node")
        os.exit(1)
    end
    return emitTempVal(ast, env, lines, "NIL", "")
end

function getEnvSuffix(env)
    return "${" .. topScope(env).environmentCounter .. "}"
end

function getTempValname(env)
    local commonSuffix = getEnvSuffix(env)
        .. "_" .. getUniqueId(env)
    return env.tempValPrefix .. commonSuffix
end

function emitTempVal(ast, env, lines, typ, content)
    tempVal = getTempValname(env)
    lines[#lines + 1] = augmentLine(
        env, string.format("eval %s=\\(%s %s\\)", tempVal, content, typ))
    return tempVal
end

function emitString(ast, env, lines)
    if ast.tag ~= "String" then
        print("emitString(): not a string node")
        os.exit(1)
    end
    return emitTempVal(ast, env, lines, "STR", ast[1])
end

function emitFalse(ast, env, lines)
    if ast.tag ~= "False" then
        print("emitFalse(): not a False node!")
        os.exit(1)
    end
    return emitTempVal(ast, env, lines, "FLS", "0")
end

function emitTrue(ast, env, lines)
    if ast.tag ~= "True" then
        print("emitTrue(): not a True node!")
        os.exit(1)
    end
    return emitTempVal(ast, env, lines, "TRU", "1")
end

function emitTableValue(ast, env, lines, suffix, value, typ)
    local typeString = "Table"
    local envSuffix = getEnvSuffix(env)
    local valueName = env.tablePrefix .. envSuffix .. suffix
    addLine(
        env, lines,
        string.format("eval %s=\\(%s %s\\)",
                      valueName, value or valueName,
                      typ or typeString))
    return valueName
end

-- prefixes each table member with env.tablePrefix
-- uses env.tablePath
function emitTable(ast, env, lines, tableId, tablePath)
    if tableId == nil then
        tableId = getUniqueId(env)
    end
    local tablePath = tablePath or ""
    local separatorChar = "_"
    if ast.tag ~= "Table" then
        print("emitTable(): not a Table!")
        os.exit(1)
    end
    emitTableValue(ast, env, lines,
                   tableId .. tablePath)
    for k,v in ipairs(ast) do
        if (v.tag == "Pair") then
            print("Associative tables not yet supported")
            os.exit(1)
        elseif v.tag ~= "Table" then
            tempValue = emitExpression(ast[k], env, lines)
            emitTableValue(ast, env, lines,
                           tableId .. tablePath .. k,
                           derefValToValue(tempValue),
                           derefValToType(tempValue))
        else
            emitTable(ast, env, lines, tableId, tablePath .. k)
        end
    end
    return env.tablePrefix .. separatorChar .. tableId
end

function addLine(env, lines, line)
    lines[#lines + 1] = augmentLine(
        env, line)
end

function emitCall(ast, env, lines)
    local functionName = ast[1][1]
    local functionExp = ast[1]
    local arguments = ast[2]
    if functionName == "print" then
        local location = emitExpression(arguments, env, lines)
        addLine(
            env, lines,
            string.format("eval echo %s", derefValToValue(location)))
    elseif functionName == "type" then
        local value = emitExpression(arguments, env, lines)
        local typeStrValue = emitTempVal(ast, env, lines,
                                         "STR", derefValToType(value))

        return typeStrValue
    else
        local varname = emitExpression(functionExp, env, lines)
        -- TODO: Argument values!
        addLine(
            env, lines,
            string.format("eval %s %s",
                          derefValToValue(varname),
                          derefValToType(varname)))
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

    pushScope(env, "function", "F" .. functionId)
    local newEnv = topScope(env).environmentCounter
    topScope(env).environmentCounter = oldEnv

    addLine(env, lines, "# Closure defintion")
    local tempVal =
        emitTempVal(ast, env, lines,
                    "${" .. topScope(env).environmentCounter .. "}",
                    "BF" .. functionId)
    addLine(env, lines, "# Environment Snapshotting")
    snapshotEnvironment(ast, env, lines, usedSyms)
    topScope(env).environmentCounter = newEnv

    addLine(env, lines,
            string.format("function BF%s {", functionId))
    -- recurse into block
    emitBlock(ast[2], env, lines)
    incCC(env)
    lines[#lines + 1] = augmentLine(
        env,
        string.format("%s=$1", topScope(env).environmentCounter))
    decCC(env)
    -- end of function definition
    addLine(env, lines, "}")
    popScope(env)
    return tempVal
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
        string.format("eval %s=\\(\"\\$((%s%s))\" %s\\)",
                      tempVal,
                      strToOpstring(ast[1]),
                      derefValToValue(operand2),
                      derefValToType(operand2)))

    return tempVal
end

function emitBinop(ast, env, lines)
    local ergId1 = getUniqueId(env)
    local tempVal = getTempValname(env)
    local left = emitExpression(ast[2], env, lines)
    local right = emitExpression(ast[3], env, lines)
    lines[#lines + 1] = augmentLine(
        env,
        string.format("eval %s=\\(\"\\$((%s%s%s))\" %s\\)",
                      tempVal,
                      derefValToValue(left),
                      strToOpstring(ast[1]),
                      derefValToValue(right),
                      derefValToType(right)))
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
        local tempVnRhs = emitTempVal(ast, env, lines,
                                      derefValToType(tempVal),
                                      derefValToValue(tempVal))
        locations[#locations + 1] = tempVnRhs
    end
    return locations
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
        emitPrefixexp(lvalexp, env, lines, iterator(), true)
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

function emitUpdateGlobVar(valuename, value, lines, env, typ)
    lines[#lines + 1] = augmentLine(
        env,
        string.format([[eval %s=\(%s %s\)]], valuename, value, typ))
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
        --location = emitId(ast, env, lines, lvalContext)
        emitUpdateGlobVar(coordinate[2].emitCurSlot,
                          derefValToValue(rhsLoc),
                          lines,
                          env,
                          derefValToType(rhsLoc))
        return location
    elseif ast.tag == "Index" then
        location = emitPrefixexp(ast[1], env, lines, rhsTemp, true, emitLocal)
        emitExpression(ast[2], env, lines)

        return location
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
