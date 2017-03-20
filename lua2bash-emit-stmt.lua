-- occasion is the reason for the block
-- can be "do", "function", "for", "while", ...
function emitBlock(ast, env, lines, occasion)
    local scopeNumber = getUniqueId(env)
    local occasion = occasion or "block"
    local scopeName
    if #env.scopeStack ~= 0 then
        scopeName = "S" .. scopeNumber
    else
        scopeName = "G"
    end
    -- push new scope on top
    pushScope(env, occasion, scopeName)
    -- don't forget the indentation counter
    incCC(env)
    emitEnvCounter(env, lines, topScope(env).environmentCounter)
    -- emit all enclosed statements
    for k,v in ipairs(ast) do
        if type(v) == "table" then
            emitStatement(v, env, lines)
        else
            print("emitBlock error!??")
            os.exit(1)
        end
    end
    decCC(env)
    -- pop the scope
    popScope(env)
end

function emitFornum(ast, env, lines)
    -- push new scope only for the loop counter
    pushScope(env,
              "for",
              "L" .. getUniqueId(env))

    local block = ast[5] or ast[4]
    local existsIncrement = ast[4].tag ~= "Block"

    -- build syntax tree for set instruction
    local tempAST = {
        tag = "Set",
        pos = -1,
        {
            tag = "VarList",
            pos = -1,
            {
                tag = "Id",
                pos = -1,
                ast[1][1]
            }
        },
        {
            tag = "ExpList",
            pos = -1,
            ast[2]
        }
    }

    emitSet(tempAST, env, lines, true)

    lines[#lines + 1] = augmentLine(env, "for ((;;)); do")

    incCC(env)

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
        block,
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
        -- increment needs to be calculated before
        parser.parse(string.format("%s=%s+(%s)",
                                   ast[1][1],
                                   ast[1][1],
                                   serExp(ast[4])))
    if not ast then
        print(errormsg)
        os.exit(1)
    end
    block[#block + 1] = incrementor[1]


    -- pp.dump(tempASTIf)
    emitIf(tempASTIf, env, lines)

    lines[#lines + 1] = augmentLine(env, "true", "Dummy command for BASH")

    decCC(env)
    lines[#lines + 1] = augmentLine(env, "done")

    -- pop the loop counter scope
    popScope(env)
end

function emitIf(ast, env, lines)
    if #ast == 1 then
        -- make else
        --pp.dump(ast[1])
        emitBlock(ast[1], env, lines)
    elseif #ast > 1 then
        -- calculate expression
        local location = emitExpression(ast[1], env, lines)

        lines[#lines + 1] = augmentLine(
            env, string.format("if [ \"%s\" = 1 ]; then",
                               derefLocation(location)))

        emitBlock(ast[2], env, lines)

        lines[#lines + 1] = augmentLine(env, "else")

        lines = emitIf(tableSlice(ast, 3, nil, 1), env, lines)
        incCC(env)
        lines[#lines + 1] = augmentLine(env, "true",
                                        "to prevent empty stmt block")
        decCC(env)
        lines[#lines + 1] = augmentLine(env, "fi")
    end
end

function emitForIn(ast, env, lines)
    -- TODO:

end

function emitWhile(ast, env, lines)
    -- TODO:

end

function emitRepeat(ast, env, lines)
    -- TODO:

end

function emitStatement(ast, env, lines)
    if ast.tag == "Call" then
        emitCall(ast, env, lines)

    -- HACK: This was used to "Simplyfy implementation"
    elseif ast.tag == "SPECIAL" then
        lines[#lines + 1] = augmentLine(env, ast.special)
    elseif ast.tag == "Fornum" then
        emitFornum(ast, env, lines)
    elseif ast.tag == "Local" then
        emitLocal(ast, env, lines)
    elseif ast.tag == "ForIn" then
        emitForIn(ast, env, lines)
    elseif ast.tag == "Repeat" then
        emitRepeat(ast, env, lines)
    elseif ast.tag == "If" then
        emitIf(ast, env, lines)
    elseif ast.tag == "While" then
        emitWhile(ast, env, lines)
    elseif ast.tag == "Do" then
        lines[#lines + 1] = augmentLine(env, "# do ")
        emitBlock(ast, env, lines)
        lines[#lines + 1] = augmentLine(env, "# end ")
    elseif ast.tag == "Set" then
        emitSet(ast, env, lines)
    end
end
