function emitId(ast, env, lines)
    if ast.tag ~= "Id" then
        print("emitId(): not a Id node")
        os.exit(1)
    end
    local inSome, coordinate = isInSomeScope(env, ast[1])
    if inSome == false then
        return "VAR_NIL", lines -- TODO: check
    end
    return { emitTempVal(ast, env, lines,
                         derefVarToType(coordinate[2].emitVarname),
                         derefVarToValue(coordinate[2].emitVarname)) }
end

function emitNumber(ast, env, lines)
    if ast.tag ~= "Number" then
        print("emitNumber(): not a Number node")
        os.exit(1)
    end
    return { emitTempVal(ast, env, lines, b.c("NUM"), b.c(tostring(ast[1]))) }
end

function emitNil(ast, env, lines)
    if ast.tag ~= "Nil" then
        print("emitNil(): not a Nil node")
        os.exit(1)
    end
    return { emitTempVal(ast, env, lines, b.c("NIL"), b.c("")) }
end

function getEnvSuffix(env)
    return b.pE(topScope(env).environmentCounter)
end

function getTempValname(env, simple)
    local commonSuffix
    if not simple then
        commonSuffix = b.c(getEnvSuffix(env)) ..
            b.c("_") ..
            b.c(tostring(getUniqueId(env)))
    else
        commonSuffix = b.c("_") .. b.c(getUniqueId(env))
    end
--    dbg()
    return b.c(env.tempValPrefix) .. commonSuffix
end

function derefVarToValue(varname)
    return b.pE(b.c("!") .. b.c(varname))
end

function derefVarToType(varname)
    return b.pE(b.pE(varname) .. b.c("[1]"))
end

function derefValToEnv(valuename)
    return b.pE(valuename .. b.c("[2]"))
end

function derefValToValue(valuename)
    return b.pE(valuename)
end

function derefValToType(valname)
    return b.pE(valname .. b.c("[1]"))
end

function emitTempVal(ast, env, lines, typ, content, simple)
    local tempVal = getTempValname(env, simple)
    local cmdLine = b.e(tempVal .. b.c("=") .. b.p(content .. b.c(" ") .. typ))
    lines[#lines + 1] = augmentLine(env, cmdLine())
    return tempVal
end

function emitString(ast, env, lines)
    if ast.tag ~= "String" then
        print("emitString(): not a string node")
        os.exit(1)
    end
    return { emitTempVal(ast, env, lines, b.c("STR"), b.c(ast[1])) }
end

function emitFalse(ast, env, lines)
    if ast.tag ~= "False" then
        print("emitFalse(): not a False node!")
        os.exit(1)
    end
    return { emitTempVal(ast, env, lines, b.c("FLS"), b.c("0")) }
end

function emitTrue(ast, env, lines)
    if ast.tag ~= "True" then
        print("emitTrue(): not a True node!")
        os.exit(1)
    end
    return { emitTempVal(ast, env, lines, b.c("TRU"), b.c("1")) }
end

function emitTableValue(env, lines, suffix, value, typ)
    local typeString = b.c("Table")
    local envSuffix = getEnvSuffix(env)
    local valueName = b.c(env.tablePrefix) .. envSuffix .. suffix
    local cmdline = b.e(
        valueName .. b.c("=")
            .. b.p((value or valueName)
                    .. b.c(" ") ..
                    (typ or typeString)))
    addLine(env, lines, cmdline())
    return valueName
end

-- prefixes each table member with env.tablePrefix
function emitTable(ast, env, lines, firstCall)
    if ast.tag ~= "Table" then
        print("emitTable(): not a Table!")
        os.exit(1)
    end
    if firstCall == nil then
        addLine(env, lines, "# " .. serTbl(ast))
    end
    local tableId = getUniqueId(env)
    local tempValues
    emitTableValue(env, lines, tableId)
    for k, v in ipairs(ast) do
        local fieldExp = ast[k]
        if (v.tag == "Pair") then
            print("Associative tables not yet supported")
            os.exit(1)
        elseif v.tag ~= "Table" then
            tempValues = emitExpression(fieldExp, env, lines)
            imap(
                tempValues,
                function(v)
                    emitTableValue(env, lines, tableId .. k,
                                   derefValToValue(v),
                                   derefValToType(v)) end)
        else
            -- tempValues possibly is a list of tempValue
            tempValues = emitTable(ast[k], env, lines, false)
            imap(
                tempValues,
                function(v)
                    emitTableValue(env, lines, tableId .. k,
                                   derefValToValue(v),
                                   derefValToType(v)) end)
        end
    end
    return { env.tablePrefix .. getEnvSuffix(env) .. tableId }
end

-- TODO: argValueList!
-- returns a tempvalue of the result
function emitCallClosure(env, lines, closureValue, argValueList)
    local cmdLine = b.e(derefValToValue(closureValue) .. b.c(" ")
                            .. derefValToType(closureValue))
    addLine(env, lines, cmdLine())
end

-- TODO: return und argumente
function emitCall(ast, env, lines)
    addLine(env, lines, "# " .. serCall(ast))
    local functionName = ast[1][1]
    local functionExp = ast[1]
    local arguments = ast[2]
    if functionName == "print" then
    --    dbg()
        local tempValues = emitExpression(arguments, env, lines)
        local dereferenced =
            join(imap(tempValues, derefValToValue), "\t")
        addLine(
            env, lines,
            string.format("eval echo %s", dereferenced))
    elseif functionName == "type" then
        -- TODO: table!
        local value = emitExpression(arguments, env, lines)[1]
        local typeStrValue = emitTempVal(ast, env, lines,
                                         "STR", derefValToType(value))

        return typeStrValue
    else
        -- TODO: table
        local c = emitExpression(functionExp, env, lines)[1]
        return emitCallClosure(env, lines, c)
    end
end

-- we can do ((Ex = Ex + 1)) even as first comman line because
-- bash will use 0 as value for Ex if the variable is not declared.
function emitEnvCounter(env, lines, envName)
    lines[#lines + 1] = augmentLine(
        env, string.format("((%s = %s + 1))", envName, envName),
        "Environment counter")
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
                    b.pE(topScope(env).environmentCounter),
                    b.c("BF") .. b.c(tostring(functionId)))
    addLine(env, lines, "# Environment Snapshotting")
    snapshotEnvironment(ast, env, lines, usedSyms)
    topScope(env).environmentCounter = newEnv

    addLine(env, lines,
            string.format("function BF%s {", functionId))
    incCC(env)
    addLine(env, lines, (b.c(oldEnv) .. b.c("=") .. b.pE("1"))())
    decCC(env)

    -- recurse into block
    emitBlock(ast[2], env, lines)
    incCC(env)
    lines[#lines + 1] = augmentLine(
        env,
        --TODO:
        string.format("%s=$1", topScope(env).environmentCounter))
    decCC(env)
    -- end of function definition
    addLine(env, lines, "}")
    popScope(env)
    return { tempVal }
end

function emitParen(ast, env, lines)
    return emitExpression(ast[1], env, lines)
end

-- always returns a table of location "strings" and the lines table
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
    elseif ast.tag == "Index" then return emitPrefixexp(ast, env, lines)
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
    elseif str == "not" then return "!"
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
    operand2, lines = emitExpression(ast[2], env, lines)[1]
    tempVal = getTempValname(env)


    lines[#lines + 1] = augmentLine(
        env,
        b.e(tempVal
                .. b.c("=")
                .. b.p(
                    b.dQ(
                        b.aE(
                            b.c(strToOpstring(ast[1])) ..
                                derefValToValue(operand2))) ..
                        b.c(" ") ..
                        derefValToType(operand2)))())

    return { tempVal }
end

function emitBinop(ast, env, lines)
    local ergId1 = getUniqueId(env)
    local tempVal = getTempValname(env)
    local left = emitExpression(ast[2], env, lines)[1]
    local right = emitExpression(ast[3], env, lines)[1]
    lines[#lines + 1] = augmentLine(
        env,
        (b.e(
             tempVal
                 .. b.c("=")
                 .. b.p(
                     b.dQ(
                         b.aE(
                             derefValToValue(left) ..
                                 b.c(strToOpstring(ast[1])) ..
                                 derefValToValue(right)) ..
                             b.c(" ") ..
                             derefValToType(right)))))())
    return { tempVal }
end

function emitExplist(ast, env, lines)
    if ast.tag ~= "ExpList" then
        print("emitExplist(): not an explist node!")
        os.exit(1)
    end
    local locations = {}
    for k, expression in ipairs(ast) do
        local tempValues = emitExpression(expression, env, lines)
        local tempVnRhs =
            imap(tempValues,
                 function(v)
                     return emitTempVal(ast, env, lines,
                                        derefValToType(v),
                                        derefValToValue(v)) end)
        tableIAddInplace(locations, tempVnRhs)
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
            local t = iter()
            scopeSetLocalAgain(ast, env, attr2)
            emitVarUpdate(env,
                          lines,
                          topScope[idString].emitVarname,
                          topScope[idString].emitCurSlot,
                          derefValToValue(t),
                          derefValToType(t))
        elseif inSome == true or inSome == false then
            local t = iter()
            -- in both cases, define in top scope
            scopeSetLocalFirstTime(ast, env,
                                   env.scopeStack[#env.scopeStack],
                                   idString)
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
        env, b.e(varname, valuename)())
    lines[#lines + 1] = augmentLine(
        env, b.e(valuename .. b.p(b.dQ(value) .. typ))())
end

function emitGlobalVar(varname, valuename, lines, env)
    lines[#lines + 1] = augmentLine(
        env, b.e(varname .. b.c("=") .. valuename)())
end

function emitUpdateGlobVar(valuename, value, lines, env, typ)
    lines[#lines + 1] = augmentLine(
        env, b.e(valuename .. b.c("=") .. b.p(value .. typ))())
end

function emitSet(ast, env, lines)
    addLine(env, lines, "# " .. serSet(ast))
    local explist, varlist = ast[2], ast[1]
    local rhsTempresults = emitExplist(explist, env, lines)
    local iterator = statefulIIterator(rhsTempresults)
    for k, lhs in ipairs(varlist) do
        if lhs.tag == "Id" then
            emitSimpleAssign(lhs, env, lines, iterator())
        else
            emitComplexAssign(lhs, env, lines, iterator())
        end
    end
end

function emitSimpleAssign(ast, env, lines, rhs)
    local idString = ast[1]
    local inSome, coordinate = isInSomeScope(env, idString)
    if not inSome then -- make var in global
        scopeSetGlobal(env, idString)
        inSome, coordinate = isInSomeScope(env, idString)
        emitGlobalVar(coordinate[2].emitVarname,
                      coordinate[2].emitCurSlot,
                      lines, env)
    end
    emitUpdateGlobVar(coordinate[2].emitCurSlot,
                      derefValToValue(rhs),
                      lines, env,
                      derefValToType(rhs))
end

function emitComplexAssign(lhs, env, lines, rhs)
    local setValue = emitExecutePrefixexp(lhs, env, lines, true)[1]
    emitUpdateGlobVar(string.format([[$(eval echo %s)]], setValue),
                      derefValToValue(rhs),
                      lines, env,
                      derefValToType(rhs))
end

function emitPrefixexp(ast, env, lines)
    return emitExecutePrefixexp(ast, env, lines)
end

--
-- dereferences expressions like getTable()[1]
-- and returns the values to be written to
function emitExecutePrefixexp(prefixExp, env, lines, asLval)
    local indirections = linearizePrefixTree(prefixExp, env)
    local temp = {}
    for i = 1, #indirections do
        local indirection = indirections[i]
        -- Id and Paren nodes are both terminal in this production tree
        -- in prefix expressions a paren or id node can only occur once
        -- on the left
        if indirection.typ == "Id" then
            local inSome, coordinate = isInSomeScope(env, indirection.id)
            if not inSome then
                print("Must be in one scope!");
                os.exit(1);
            end
            temp[i] = emitId(indirection.ast, env, lines)[1]
        elseif indirection.typ == "Paren" then
            temp[i] = emitExpression(indirection.exp, env, lines)[1]
        elseif indirection.typ == "Call"  then
            -- TODO function arguments!
            local funArgs
            temp[i] = emitCallClosure(env, lines, temp[i - 1], funArgs)[1]
        elseif indirection.typ == "Index" then
            local index = emitExpression(indirection.exp, env, lines)[1]
            index =  derefValToValue(temp[i-1]) .. derefValToValue(index)
            if i == #indirections and asLval then
                temp[i] = index
            else
                temp[i] = emitTempVal(
                    ast, env, lines,
                    b.pE(index .. b.c("[1]")),
                    b.pE(index))
            end
        end
    end
    return { temp[#temp] }
end

function linearizePrefixTree(ast, env, result)
    local result = result or {}
    if type(ast) ~= "table" then return result end
    if ast.tag == "Id" then
        result[#result + 1] =
            { id = ast[1],
              typ = ast.tag,
              ast = ast,
              exp = nil}
    elseif ast.tag == "Paren" then
        result[#result + 1] =
            { exp = ast[1],
              typ = ast.tag,
              ast = ast}
    elseif ast.tag == "Call"  then
        result[#result + 1] =
            { callee = ast[1],
              typ = ast.tag,
              ast = ast,
              exp = tableSlice(ast, 2, #ast, 1)}
    elseif ast.tag == "Index" then
        result[#result + 1] =
            { indexee = ast[1],
              typ = ast.tag,
              ast = ast,
              exp = ast[2]}
    end
    if ast.tag ~= "Id" then
        linearizePrefixTree(ast[1], env, result)
    end
    return tableReverse(result)
end
