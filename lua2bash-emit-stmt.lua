-- occasion is the reason for the block
-- can be "do", "function", "for", "while", ...
function emitBlock(ast, env, lines, occasion)
    local scopeNumber = getUniqueId(env)
    local occasion = occasion or "block"
    local scopeName

    if #env.scopeStack ~= 0 then
        scopeName = "Scope_" .. scopeNumber
    else
        scopeName = "G"
    end

    -- push new scope on top
    pushScope(env, occasion, scopeName)

    -- don't forget the indentation counter
    incCC(env)

    -- emit all enclosed statements
    for k,v in ipairs(ast) do
        if type(v) == "table" then
            lines = emitStatement(v, env, lines)
        else
            print("emitBlock error!??")
            os.exit(1)
        end
    end

    decCC(env)

    -- pop the scope
    popScope(env)

    return lines
end

function emitFornum(ast, env, lines)
    -- push new scope only for the loop counter
    pushScope(env,
              "for",
              "loop_" .. getUniqueId(env),
              {[ast[1][1]] = ""})


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

    lines = emitSet(tempAST, env, lines, true)

    lines[#lines + 1] = augmentLine(env, "for ((;;)); do")

    incCC(env)

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

    lines[#lines + 1] = augmentLine(env, "true", "Dummy command for BASH")

    decCC(env)
    lines[#lines + 1] = augmentLine(env, "done")

    -- pop the loop counter scope
    popScope(env)

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

        lines[#lines + 1] = augmentLine(
            env, string.format("if [ \"%s\" = 1 ]; then",
                               derefLocation(location)))

        lines = emitBlock(ast[2], env, l1)

        lines[#lines + 1] = augmentLine(env, "else")

        lines = emitIf(tableSlice(ast, 3, nil, 1), env, lines)
        incCC(env)
        lines[#lines + 1] = augmentLine(env, "true",
                                        "to prevent empty stmt block")
        decCC(env)
        lines[#lines + 1] = augmentLine(env, "fi")
    end

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
        lines[#lines + 1] = augmentLine(env, ast.special)
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
