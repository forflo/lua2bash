local util = require("lua2bash-util")
-- this module implements a predicate function
-- which can be used to determine whether an AST
-- can be statically evaluated

function isStaticTbl(ast)
    local result = true
    imap(ast,
         function(node)
             result = result and isStaticExp(node)
    end)
    return result
end

function isStaticPair(ast)
end

function isStaticCall(ast)
    local prefixExpr = ast[1]
    local arguments = util.tableSlice(ast, 2, #ast, 1)
    return isStaticPrefix(prefixExpr) and
        util.ifold(
            util.imap(
                arguments,
                function(exp)
                    return isStaticExp(exp) end),
            function(b, acc)
                return acc and b end,
            true)
end

function isStaticFun(ast)
    local namelist = ast[1]
    local block = ast[2]
    return isStaticNamelist(namelist) and
        isStaticBlock(block)
end

function isStaticVarlist(ast)
    return util.ifold(
        util.imap(
            ast,
            function(pExp)
                return isStaticPrefix(pExp) end),
        function(b, acc)
            return acc and b end,
        true)
end

function isStaticExplist(ast)
    local bools = util.imap(ast, function(exp) return isStaticExp(exp) end)
    return util.ifold(bools, function(b, acc) return acc and b end, true)
end

function isStaticNamelist(ast)
    --TODO
    return true
end

function isStaticLocal(ast)
    return isStaticNamelist(ast[1]) and
        isStaticExplist(ast[2])
end

function isStaticSet(ast)
    local varlist = ast[1]
    local explist = ast[2]
    return isStaticVarlist(varlist) and
        isStaticExplist(explist)
end

function isStaticFor(ast)
    if #ast == 5 then
        return isStaticExp(ast[2])
            and isStaticExp(ast[3])
            and isStaticExp(ast[4])
            and isStaticBlock(ast[5])
            and isStaticId(ast[1])
    else return isStaticExp(ast[2])
            and isStaticExp(ast[3])
            and isStaticBlock(ast[5])
            and isStaticId(ast[1]) end
end

function isStaticForIn(ast)
    local namelist = ast[1]
    local explist = ast[2]
    local block = ast[3]
    return isStaticNamelist(namelist) and
        isStaticExplist(explist) and
        isStaticBlock(block)
end

function isStaticWhile(ast)
    return isStaticExp(ast[1]) and isStaticBlock(ast[2])
end

function isStaticIf(ast)
    local result = true
    local elseB = #ast % 2
    for i = 1, #ast - elseB, 2 do
        result = result
            and isStaticExpr(ast[i])
            and isStaticBlock(ast[i + 1])
    end

    if elseB == 1 then
        result = result and isStaticBlock(ast[#ast])
    end
    return result
end

function isStaticRepeat(ast)
    return isStaticBlock(ast[1]) and isStaticBlock(ast[2])
end

function isStaticDo(ast)
    local result = true
    imap(ast, function(node) result = result and isStaticStmt(node) end)
    return result
end

function isStaticRet(ast)
    return util.ifold(
        util.imap(
            ast,
            function(exp)
                return isStaticExp(exp) end),
        function(b, acc)
            return acc and b end,
        true)
end

function isStaticStm(ast)
    if ast.tag == "Call" then return isStaticCall(ast)
    elseif ast.tag == "Fornum" then return isStaticFor(ast)
    elseif ast.tag == "Local" then return isStaticLocal(ast)
    elseif ast.tag == "Forin" then return isStaticForIn(ast)
    elseif ast.tag == "Repeat" then return isStaticRepeat(ast)
    elseif ast.tag == "Return" then return isStaticReturn(ast)
    elseif ast.tag == "If" then return isStaticIf(ast)
    elseif ast.tag == "While" then return isStaticWhile(ast)
    elseif ast.tag == "Do" then return isStaticDo(ast)
    elseif ast.tag == "Set" then return isStaticSet(ast)
    end
end

function isStaticBlock(ast)
    local result = true
    imap(ast, function(node) result = result and isStaticStmt(node) end)
    return result
end

function isStaticExp(ast)
    if ast.tag == "Op" then
        return isStaticExp(ast[2]) and isStaticExp(ast[3])
    elseif ast.tag == "Id" then return isStaticId(ast)
    elseif ast.tag == "True" then return true
    elseif ast.tag == "False" then return true
    elseif ast.tag == "Nil" then return true
    elseif ast.tag == "Number" then return true
    elseif ast.tag == "String" then return true
    elseif ast.tag == "Table" then return isStaticTable(ast)
    elseif ast.tag == "Function" then return isStaticFun(ast)
    elseif ast.tag == "Call" then return isStaticCall(ast)
    elseif ast.tag == "Pair" then return isStaticPair(ast)
    elseif ast.tag == "Paren" then return isStaticExp(ast[1])
    elseif ast.tag == "Index" then return isStaticPrefix(ast)
    else
        print("Static checker: Node type not supported!")
        print("Node type:" .. ast.tag)
        os.exit(1)
    end
end

function isStaticPrefix(ast)
    return isStaticPrefix(ast[1]) .. isStaticPrefix(ast[2])
end
