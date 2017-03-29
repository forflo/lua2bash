local serializer = {}

function serializer.serId(ast)
    return ast[1]
end

function serializer.serNum(ast)
    return ast[1]
end

function serializer.serNil(ast)
    return "nil"
end

function serializer.serStr(ast)
    return "\"" .. ast[1] .. "\""
end

function serializer.serFal(ast)
    return "false"
end

function serializer.serTru(ast)
    return "true"
end

-- prefixes each table member with env.tablePrefix
-- uses env.tablePath
function serializer.serTbl(ast)
    local params = {}

    for i = 1, #ast do
        params[#params + 1] = serExp(ast[i])
    end

    params = join(params, ', ')
    return "{" .. params .. "}"
end

function serializer.serPair(ast)
    return "[" .. serExp(ast[1]) .. "] = " .. serExp(ast[2])
end

function serializer.serCall(ast)
    local params = {}
    for i = 2, #ast do
        params[#params + 1] = serExp(ast[i])
    end
    params = join(params, ", ")

    return serExp(ast[1]) .. "(" .. (params or "") .. ")"
end

function serializer.serFun(ast)
    return "function(" .. serNamelist(ast[1]) .. ") "
        .. serBlock(ast[2]) .. "end"
end

function serializer.serVarlist(ast)
    local result = imap(
        ast,
        function(elem)
            return serExp(elem)
    end)

    return join(result, ', ')
end

function serializer.serExplist(ast)
    local result = imap(
        ast,
        function(elem)
            return serExp(elem)
    end)

    return join(result, ', ')
end

function serializer.serNamelist(ast)
    return join(
        imap(
            ast,
            function(elem)
                return serExp(elem)
        end), ', ')
end

function serializer.serLcl(ast)
    return "local " .. serNamelist(ast[1]) .. " = " .. serExplist(ast[2])
end

function serializer.serSet(ast)
    return serVarlist(ast[1]) .. " = " .. serExplist(ast[2])
end

function serializer.serFor(ast)
    return "for " .. serExp(ast[1]) .. " = "
        .. serExp(ast[2]) .. ", " .. serExp(ast[3])
        .. expIf(
            ast[4].tag == "Block", -- cond
            function()
                return " do " .. (serBlock(ast[4]))
            end,
            function()
                return ", " .. serExp(ast[4]) .. " do " .. serBlock(ast[5])
                end)
        .. "end"
end

function serializer.serForIn(ast)
    return "for " .. serNamelist(ast[1]) .. " in " .. serExplist(ast[2])
    .. " do " .. serBlock(ast[3]) .. "end"
end

function serializer.serWhi(ast)
    return "while " .. "(" .. serExp(ast[1]) .. ")"
    .. " do " .. serBlock(ast[2]) .. "end"
end

-- Well, ...
function serializer.serIf(ast)
    local elseB = #ast % 2 == 1
    return "if " .. serExp(ast[1]) .. " then "
        .. serBlock(ast[2])
        .. join(
            imap(
                tableSlice(ast, 3, expIfStrict(elseB, #ast - 1, #ast), 1),
                function(e)
                    return expIf(
                        e.tag == "Block",
                        function()
                            return serBlock(e)
                        end,
                        function()
                            return "elseif " .. serExp(e) .. " then "
                    end)
                end
            ), '')
        .. expIf(
            elseB,
            function()
                return "else " .. serBlock(ast[#ast]) .. "end"
            end,
            function()
                return "end"
                end)
end

function serializer.serRep(ast)
    return "repeat " .. serBlock(ast[1]) .. "until " .. serExp(ast[2])
end

function serializer.serDo(ast)
    return "do "
        .. join(
            imap(
                ast,
                function(e)
                    return serStm(e)
            end),
            '; ') .. "; end"
end

function serializer.serRet(ast)
    return "return " .. join(
        imap(
            ast,
            function(e)
                return serExp(e) end), ', ')
end

function serializer.serStm(ast)
    if ast.tag == "Call" then return serCall(ast)
    elseif ast.tag == "Fornum" then return serFor(ast)
    elseif ast.tag == "Local" then return serLcl(ast)
    elseif ast.tag == "Forin" then return serForIn(ast)
    elseif ast.tag == "Repeat" then return serRep(ast)
    elseif ast.tag == "Return" then return serRet(ast)
    elseif ast.tag == "If" then return serIf(ast)
    elseif ast.tag == "While" then return serWhi(ast)
    elseif ast.tag == "Do" then return serDo(ast)
    elseif ast.tag == "Set" then return serSet(ast)
    end
end

function serializer.serBlock(ast)
    local parts = imap(
        ast,
        function(elem) return serStm(elem) end)

    return join(parts, '; ') .. '; '
end

function serializer.serPar(ast)
    return "(" .. serExp(ast[1]) .. ")"
end

-- always returns a location "string" and the result table
function serializer.serExp(ast)
    --dbg()
    if ast.tag == "Op" then return serOp(ast)
    elseif ast.tag == "Id" then return serId(ast)
    elseif ast.tag == "True" then return serTru(ast)
    elseif ast.tag == "False" then return serFal(ast)
    elseif ast.tag == "Nil" then return serNil(ast)
    elseif ast.tag == "Number" then return serNum(ast)
    elseif ast.tag == "String" then return serStr(ast)
    elseif ast.tag == "Table" then return serTbl(ast)
    elseif ast.tag == "Function" then return serFun(ast)
    elseif ast.tag == "Call" then return serCall(ast)
    elseif ast.tag == "Pair" then return serPair(ast)
    elseif ast.tag == "Paren" then return serPar(ast)
    elseif ast.tag == "Index" then return serIdx(ast)
    else
        print("Serializer: Node type not supported!")
        print("Node type:" .. ast.tag)
        os.exit(1)
    end
end

function serializer.strToOpstr(str)
    if str == "add" then return "+"
    elseif str== "sub" then return "-"
    elseif str== "unm" then return "-"
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

function serializer.serOp(ast)
    if (#ast == 3) then
        -- binop
        return serExp(ast[2]) .. strToOpstr(ast[1]) .. serExp(ast[3])
    else
        -- unop
        return strToOpstr(ast[1]) .. serExp(ast[2])
    end
end

function serializer.serIdx(ast)
    return serExp(ast[1]) .. "[" .. serExp(ast[2]) .. "]"
end

return serializer
