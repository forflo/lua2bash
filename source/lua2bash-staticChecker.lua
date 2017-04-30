local util = require("lua2bash-util")
-- this module implements a predicate function
-- which can be used to determine whether an AST
-- can be statically evaluated

local statcheck = {}

function statcheck.isStaticTbl(ast)
    local result = true
    util.imap(ast,
         function(node)
             result = result and statcheck.isStaticExp(node)
    end)
    return result
end

function statcheck.isStaticPair(_)
    print("NOT IMPLEMENTED YET")
    return false
end

function statcheck.isStaticCall(ast)
    local prefixExpr = ast[1]
    local arguments = util.tableSlice(ast, 2, #ast, 1)
    return statcheck.isStaticPrefix(prefixExpr) and
        util.ifold(
            util.imap(
                arguments,
                function(exp)
                    return statcheck.isStaticExp(exp) end),
            function(b, acc)
                return acc and b end,
            true)
end

function statcheck.isStaticFun(ast)
    local namelist = ast[1]
    local block = ast[2]
    return statcheck.isStaticNamelist(namelist) and
        statcheck.isStaticBlock(block)
end

function statcheck.isStaticVarlist(ast)
    return util.ifold(
        util.imap(
            ast,
            function(pExp)
                return statcheck.isStaticPrefix(pExp) end),
        function(b, acc)
            return acc and b end,
        true)
end

function statcheck.isStaticExplist(ast)
    local bools = util.imap(ast, function(exp)
                                return statcheck.isStaticExp(exp) end)
    return util.ifold(bools, function(b, acc) return acc and b end, true)
end

function statcheck.isStaticNamelist(ast)
    --TODO
    return true
end

function statcheck.isStaticLocal(ast)
    return statcheck.isStaticNamelist(ast[1]) and
        statcheck.isStaticExplist(ast[2])
end

function statcheck.isStaticSet(ast)
    local varlist = ast[1]
    local explist = ast[2]
    return statcheck.isStaticVarlist(varlist) and
        statcheck.isStaticExplist(explist)
end

-- TODO: this currently is a dummy
function statcheck.isStaticId(_)
    return false
end

function statcheck.isStaticFor(ast)
    if #ast == 5 then
        return
            statcheck.isStaticExp(ast[2])
            and statcheck.isStaticExp(ast[3])
            and statcheck.isStaticExp(ast[4])
            and statcheck.isStaticBlock(ast[5])
            and statcheck.isStaticId(ast[1])
    else
        return
            statcheck.isStaticExp(ast[2])
            and statcheck.isStaticExp(ast[3])
            and statcheck.isStaticBlock(ast[5])
            and statcheck.isStaticId(ast[1])
    end
end

function statcheck.isStaticForIn(ast)
    local namelist = ast[1]
    local explist = ast[2]
    local block = ast[3]
    return statcheck.isStaticNamelist(namelist) and
        statcheck.isStaticExplist(explist) and
        statcheck.isStaticBlock(block)
end

function statcheck.isStaticWhile(ast)
    return statcheck.isStaticExp(ast[1]) and statcheck.isStaticBlock(ast[2])
end

function statcheck.isStaticIf(ast)
    local result = true
    local elseB = #ast % 2
    for i = 1, #ast - elseB, 2 do
        result = result
            and statcheck.isStaticExpr(ast[i])
            and statcheck.isStaticBlock(ast[i + 1])
    end

    if elseB == 1 then
        result = result and statcheck.isStaticBlock(ast[#ast])
    end
    return result
end

function statcheck.isStaticRepeat(ast)
    return statcheck.isStaticBlock(ast[1]) and statcheck.isStaticBlock(ast[2])
end

function statcheck.isStaticDo(ast)
    local result = true
    util.imap(
        ast,
        function(node)
            result = result and statcheck.isStaticStmt(node)
    end)
    return result
end

function statcheck.isStaticRet(ast)
    return util.ifold(
        util.imap(
            ast,
            function(exp)
                return statcheck.isStaticExp(exp) end),
        function(b, acc)
            return acc and b end,
        true)
end

function statcheck.isStaticStm(ast)
    if ast.tag == "Call" then return statcheck.isStaticCall(ast)
    elseif ast.tag == "Fornum" then return statcheck.isStaticFor(ast)
    elseif ast.tag == "Local" then return statcheck.isStaticLocal(ast)
    elseif ast.tag == "Forin" then return statcheck.isStaticForIn(ast)
    elseif ast.tag == "Repeat" then return statcheck.isStaticRepeat(ast)
    elseif ast.tag == "Return" then return statcheck.isStaticReturn(ast)
    elseif ast.tag == "If" then return statcheck.isStaticIf(ast)
    elseif ast.tag == "While" then return statcheck.isStaticWhile(ast)
    elseif ast.tag == "Do" then return statcheck.isStaticDo(ast)
    elseif ast.tag == "Set" then return statcheck.isStaticSet(ast)
    end
end

function statcheck.isStaticBlock(ast)
    local result = true
    util.imap(
        ast,
        function(node)
            result = result and statcheck.isStaticStmt(node)
    end)
    return result
end

function statcheck.isStaticOp(ast)
    if ast[3] then
        return statcheck.isStaticExp(ast[2]) and statcheck.isStaticExp(ast[3])
    else
        return statcheck.isStaticExp(ast[2])
    end
end

function statcheck.isStaticTable(ast)
    return util.ifold(
        ast,
        function(fieldExp, acc)
            return statcheck.isStaticExp(fieldExp) and acc
        end,
        true)
end

function statcheck.isStaticExp(ast)
    if ast.tag == "Op" then return statcheck.isStaticOp(ast)
    elseif ast.tag == "Id" then return statcheck.isStaticId(ast)
    elseif ast.tag == "True" then return true
    elseif ast.tag == "False" then return true
    elseif ast.tag == "Nil" then return true
    elseif ast.tag == "Number" then return true
    elseif ast.tag == "String" then return true
    elseif ast.tag == "Table" then return statcheck.isStaticTable(ast)
    elseif ast.tag == "Function" then return statcheck.isStaticFun(ast)
    elseif ast.tag == "Call" then return statcheck.isStaticCall(ast)
    elseif ast.tag == "Pair" then return statcheck.isStaticPair(ast)
    elseif ast.tag == "Paren" then return statcheck.isStaticExp(ast[1])
    elseif ast.tag == "Index" then return statcheck.isStaticPrefix(ast)
    else
        print("Static checker: Node type not supported!")
        print("Node type:" .. ast.tag)
        os.exit(1)
    end
end

function statcheck.isStaticPrefix(ast)
    return statcheck.isStaticExp(ast[1])
        and statcheck.isStaticExp(ast[2])
end

return statcheck
