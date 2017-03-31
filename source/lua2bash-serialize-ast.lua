local util = require("lua2bash-util")
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
        params[#params + 1] = serializer.serExp(ast[i])
    end

    params = util.join(params, ', ')
    return "{" .. params .. "}"
end

function serializer.serPair(ast)
    return "[" .. serializer.serExp(ast[1])
        .. "] = " .. serializer.serExp(ast[2])
end

function serializer.serCall(ast)
    local params = {}
    for i = 2, #ast do
        params[#params + 1] = serializer.serExp(ast[i])
    end
    params = util.join(params, ", ")
    return serializer.serExp(ast[1]) .. "(" .. (params or "") .. ")"
end

function serializer.serFun(ast)
    return "function(" .. serNamelist(ast[1]) .. ") "
        .. serBlock(ast[2]) .. "end"
end

function serializer.serVarlist(ast)
    local result = util.imap(
        ast,
        function(elem)
            return serializer.serExp(elem)
    end)
    return util.join(result, ', ')
end

function serializer.serExplist(ast)
    local result = util.imap(
        ast,
        function(elem)
            return serializer.serExp(elem)
    end)
    return util.join(result, ', ')
end

function serializer.serNamelist(ast)
    return util.join(
        util.imap(
            ast,
            function(elem)
                return serializer.serExp(elem)
        end), ', ')
end

function serializer.serLcl(ast)
    return "local " .. serializer.serNamelist(ast[1])
        .. " = " .. serializer.serExplist(ast[2])
end

function serializer.serSet(ast)
    return serializer.serVarlist(ast[1])
        .. " = " .. serializer.serExplist(ast[2])
end

function serializer.serFor(ast)
    return "for " .. serializer.serExp(ast[1]) .. " = "
        .. serializer.serExp(ast[2]) .. ", " .. serializer.serExp(ast[3])
        .. util.expIf(
            ast[4].tag == "Block", -- cond
            function()
                return " do " .. serializer.serBlock(ast[4])
            end,
            function()
                return ", " .. serializer.serExp(ast[4])
                .. " do " .. serializer.serBlock(ast[5])
                end) .. "end"
end

function serializer.serForIn(ast)
    return "for " .. serializer.serNamelist(ast[1])
        .. " in " .. serializer.serExplist(ast[2])
    .. " do " .. serializer.serBlock(ast[3]) .. "end"
end

function serializer.serWhi(ast)
    return "while " .. "(" .. serializer.serExp(ast[1]) .. ")"
    .. " do " .. serializer.serBlock(ast[2]) .. "end"
end

-- Well, ...
function serializer.serIf(ast)
    local elseB = #ast % 2 == 1
    return "if " .. serializer.serExp(ast[1]) .. " then "
        .. serializer.serBlock(ast[2])
        .. util.join(
            util.imap(
                util.tableSlice(ast, 3, util.expIfStrict(
                                    elseB, #ast - 1, #ast), 1),
                function(e)
                    return util.expIf(
                        e.tag == "Block",
                        function()
                            return serializer.serBlock(e)
                        end,
                        function()
                            return "elseif "
                            .. serializer.serExp(e) .. " then "
                    end)
                end
            ), '')
        .. util.expIf(
            elseB,
            function()
                return "else " .. serializer.serBlock(ast[#ast]) .. "end"
            end,
            function()
                return "end"
                end)
end

function serializer.serRep(ast)
    return "repeat " .. serializer.serblock(ast[1])
    .. "until " .. serializer.serexp(ast[2])
end

function serializer.serDo(ast)
    return "do "
        .. join(
            util.imap(
                ast,
                function(e)
                    return serializer.serStm(e)
            end),
            '; ') .. "; end"
end

function serializer.serRet(ast)
    return "return " .. util.join(
        util.imap(
            ast,
            function(e)
                return serializer.serExp(e) end), ', ')
end

function serializer.serStm(ast)
    if ast.tag == "Call" then return serializer.serCall(ast)
    elseif ast.tag == "Fornum" then return serializer.serFor(ast)
    elseif ast.tag == "Local" then return serializer.serLcl(ast)
    elseif ast.tag == "Forin" then return serializer.serForIn(ast)
    elseif ast.tag == "Repeat" then return serializer.serRep(ast)
    elseif ast.tag == "Return" then return serializer.serRet(ast)
    elseif ast.tag == "If" then return serializer.serIf(ast)
    elseif ast.tag == "While" then return serializer.serWhi(ast)
    elseif ast.tag == "Do" then return serializer.serDo(ast)
    elseif ast.tag == "Set" then return serializer.serSet(ast)
    end
end

function serializer.serBlock(ast)
    local parts = util.imap(
        ast,
        function(elem) return serializer.serStm(elem) end)

    return util.join(parts, '; ') .. '; '
end

function serializer.serPar(ast)
    return "(" .. serializer.serExp(ast[1]) .. ")"
end

-- always returns a location "string" and the result table
function serializer.serExp(ast)
    if ast.tag == "Op" then return serializer.serOp(ast)
    elseif ast.tag == "Id" then return serializer.serId(ast)
    elseif ast.tag == "True" then return serializer.serTru(ast)
    elseif ast.tag == "False" then return serializer.serFal(ast)
    elseif ast.tag == "Nil" then return serializer.serNil(ast)
    elseif ast.tag == "Number" then return serializer.serNum(ast)
    elseif ast.tag == "String" then return serializer.serStr(ast)
    elseif ast.tag == "Table" then return serializer.serTbl(ast)
    elseif ast.tag == "Function" then return serializer.serFun(ast)
    elseif ast.tag == "Call" then return serializer.serCall(ast)
    elseif ast.tag == "Pair" then return serializer.serPair(ast)
    elseif ast.tag == "Paren" then return serializer.serPar(ast)
    elseif ast.tag == "Index" then return serializer.serIdx(ast)
    else
        print("Serializer: Node type not supported!")
        print("Node type:" .. ast.tag)
        os.exit(1)
    end
end

function serializer.serOp(ast)
    if (#ast == 3) then
        -- binop
        return serializer.serExp(ast[2])
            .. " "
            .. util.strToOpstr(ast[1])
            .. " "
            .. serializer.serExp(ast[3])
    else
        -- unop
        return util.strToOpstr(ast[1])
            .. " " .. serializer.serExp(ast[2])
    end
end

function serializer.serIdx(ast)
    return serializer.serExp(ast[1]) .. "["
        .. serializer.serExp(ast[2]) .. "]"
end

return serializer
