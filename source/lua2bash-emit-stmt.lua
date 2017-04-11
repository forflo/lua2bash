datatypes = require("lua2bash-datatypes")
util = require("lua2bash-util")
scope = require("lua2bash-scope")

local se = {}

-- occasion is the reason for the block
-- can be "do", "function", "for", "while", ...
function se.emitBlock(indent, ast, config, stack, lines, occasion)
    local scopeNumber = util.getUniqueId()
    local envId = util.getUniqueId()
    local occasion = occasion or datatypes.occasions.BLOCK
    local scopeName = "S" .. scopeNumber
    -- push new scope on top
    local newScope = datatypes.Scope(
        occasion, scopeName, envId,
        scope.getPathPrefix(stack) .. scopeName)
    stack:push(newScope)
    util.addLine(
        indent, lines,
        "# Begin of Scope: " .. stack:top():getPath())
    emitEnvCounter(indent + config.indentSize, config,
                   lines, stack:top():getEnvironmentId())
    -- emit all enclosed statements
    for k, v in ipairs(ast) do
        if type(v) == "table" then
            emitStatement(indent, v, config, stack, lines)
        else
            print("emitBlock error!??")
            os.exit(1)
        end
    end
    -- pop the scope
    stack:pop()
end

-- TODO: komplett neu schreiben
function se.emitFornum(indent, ast, config, stack, lines)
    -- push new scope only for the loop counter
    pushScope(env,
              "for",
              "L" .. util.getUniqueId(env))

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

    lines[#lines + 1] = augmentLine(config, "for ((;;)); do")

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

function se.emitIf(indent, ast, config, stack, lines)
    if #ast == 1 then
        -- make else
        emitBlock(indent + config.indentSize,
                  ast[1], config, stack, lines,
                  datatypes.occasion.IF)
    elseif #ast > 1 then
        -- calculate expression
        local location = emitExpression(indent, ast[1], config, stack, lines)
        util.addLine(
            indent, lines,
            string.format("if [ \"%s\" = 1 ]; then",
                          derefLocation(location)))
        emitBlock(indent, ast[2], config, stack, lines)
        util.addLine(indent, lines, "else")
        emitIf(indent, tableSlice(ast, 3, nil, 1), config, stack, lines)
        util.addLine(indent, lines, "true", "to prevent empty stmt block")
        util.addLine(indent, lines, "fi")
    end
end

-- should completely be eliminated before the emit process
-- begins. This shall be realized as a additional compiler pass
-- that modifies the AST directly
function se.emitForIn(indent, ast, config, stack, lines)
    -- TODO:
end

-- TODO: nil?
function se.emitWhile(indent, ast, config, stack, lines)
    local loopExpr = ast[1]
    local loopBlock = ast[2]
    -- only the first tempValue is significant
    local tempValue = emitExpression(indent, loopExpr, config, stack, lines)[1]
    local simpleValue = emitTempVal(indent, config, lines,
                                    derefValToType(tempValue),
                                    derefValToValue(tempValue), true)
    util.addLine(indent, lines, string.format(
                "while [ \"${%s}\" != 0 ]; do",
                simpleValue))
    emitBlock(indent, loopBlock, config, stack, lines)
    -- recalculate expression for next loop
    local tempValue2 = emitExpression(indent, loopExpr, config, stack, lines)[1]
    util.addLine(indent, lines, string.format("eval %s=%s",
                                         simpleValue,
                                         derefValToValue(tempValue2)))
    util.addLine(indent, lines, "true", "to prevent empty block")
    util.addLine(indent, lines, "done")
end

function se.emitRepeat(indent, ast, config, stack, lines)
    -- TODO:
end

function se.emitBreak(indent, ast, config, stack, lines)
    util.addLine(indent, lines, "break;")
end

function se.emitStatement(indent, ast, config, stack, lines)
    if ast.tag == "Call" then
        emitCall(indent, ast, config, stack, lines)
    -- HACK: This was used to "Simplify implementation"
    elseif ast.tag == "SPECIAL" then
        util.addLine(indent, lines, ast.special)
    elseif ast.tag == "Fornum" then
        emitFornum(indent, ast, config, stack, lines)
    elseif ast.tag == "Local" then
        emitLocal(indent, ast, config, stack, lines)
    elseif ast.tag == "ForIn" then
        emitForIn(indent, ast, config, stack, lines)
    elseif ast.tag == "Repeat" then
        emitRepeat(indent, ast, config, stack, lines)
    elseif ast.tag == "If" then
        emitIf(indent, ast, config, stack, lines)
    elseif ast.tag == "Break" then
        emitBreak(indent, ast, config, stack, lines)
    elseif ast.tag == "While" then
        emitWhile(indent, ast, config, stack, lines)
    elseif ast.tag == "Do" then
        util.addLine(indent, lines, "# do ")
        emitBlock(indent, ast, config, stack, lines)
        util.addLine(indent, lines, "# end ")
    elseif ast.tag == "Set" then
        emitSet(indent, ast, config, stack, lines)
    end
end

return se
