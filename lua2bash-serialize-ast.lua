function serId(ast, result)
    return ast[1]
end

function serNum(ast, result)
    return ast[1]
end

function serNil(ast, result)
    return "nil"
end

function serStr(ast, result)
    return ast[1]
end

function serFal(ast, result)
    return "false"
end

function serTru(ast, result)
    return "true"
end

-- prefixes each table member with env.tablePrefix
-- uses env.tablePath
function serTbl(ast, result)
    local params = ""

    for i = 1, #ast do
        params[#params + 1] = serExp(ast[i])
    end

    params = join(params, ',')
    return params
end

function serPair(ast, result)
    return "[" .. serExp(ast[i]) .. "] = " .. serExp(ast[i])
end

function serCall(ast, result)
    local params = ""
    for i = 2, #ast - 1 do
        params[#params + 1] = serExp(ast[i])
    end
    params = join(params, ",")

    return serExp(ast[1]) .. "(" .. params .. ")"
end

-- TODO: because that would require a serializer also for statements...
-- I'm not quite motivated to do that now
function serFun(ast, result)
    print("Serializer: Not yet supported!") -- TODO: feature
    os.exit(1)
end

-- always returns a location "string" and the result table
function serExp(ast, result)
    if ast.tag == "Op" then return serOp(ast, result)
    elseif ast.tag == "Id" then return serId(ast, result)
    elseif ast.tag == "True" then return serTru(ast, result)
    elseif ast.tag == "False" then return serFal(ast, result)
    elseif ast.tag == "Nil" then return serNil(ast, result)
    elseif ast.tag == "Number" then return serNum(ast, result)
    elseif ast.tag == "String" then return serStr(ast, result)
    elseif ast.tag == "Table" then return serTbl(ast, result)
    elseif ast.tag == "Function" then return serFun(ast, result)
    elseif ast.tag == "Call" then return serCall(ast, result)
    elseif ast.tag == "Pair" then return serPair(ast, result)
    elseif ast.tag == "Paren" then return serPar(ast, result)
    elseif ast.tag == "Index" then return serIdx(ast, result)
    else
        print("Serializer: Node type not supported!")
        os.exit(1)
    end
end

function strToOpstr(str)
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
    else
        print("Serializer: Unknown operator!")
        os.exit(1)
    end
end

function serOp(ast, result)
    if (#ast == 3) then
        -- binop
        return serExp(2) .. strToOpstr(ast[1]) .. serExp(3)
    else
        -- unop
        return strToOpstr(ast[1]) .. serExp(2)
    end
end

function serIdx(ast, result)
    return serExp(ast[1]) .. "[" .. serExp(ast[2]) .. "]"
end
