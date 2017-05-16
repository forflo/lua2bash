local util = require("lua2bash-util")

local astBuilder = {}

function astBuilder.forNum(loopVar, begin, limit, step, block)
    return { tag = "Fornum", pos = -1, loopVar, begin, limit, step, block }
end

function astBuilder.forIn(namelist, explist, block)
    return { tag = "ForIn", pos = -1, namelist, explist, block }
end

function astBuilder.nameList(...)
    return { tag = "NameList", pos = -1, ... }
end

function astBuilder.expList(...)
    return { tag = "ExpList", pos = -1, ... }
end

-- ... are the parameters
function astBuilder.callStmt(prefixExp, ...)
    return { tag = "Call", pos = -1, prefixExp, ... }
end

function astBuilder.localAssignment(namelist, explist)
    return { tag = "Local", pos = -1, namelist, explist }
end

function astBuilder.repeatLoop(block, condition)
    return { tag = "Repeat", pos = -1, block, condition }
end

function astBuilder.whileLoop(condition, block)
    return { tag = "While", pos = -1, condition, block }
end

function astBuilder.ifStmt(condition, ifBlock, elseBlock)
    return { tag = "If", pos = -1, condition, ifBlock, elseBlock }
end

function astBuilder.breakStmt()
    return { tag = "Break", pos = -1 }
end

function astBuilder.doStmt(...)
    return { tag = "Do", pos = -1, ... }
end

function astBuilder.returnStmt(...)
    return { tag = "Return", pos = -1, ... }
end

function astBuilder.globalAssignment(varlist, explist)
    return { tag = "Set", pos = -1, varlist, explist }
end

function astBuilder.varList(...)
    return { tag = "VarList", pos = -1, ... }
end

function astBuilder.id(idString)
    return { tag = "Id", pos = -1, idString }
end

function astBuilder.trueLit()
    return { tag = "True", pos = -1 }
end

function astBuilder.falseLit()
    return { tag = "False", pos = -1 }
end

function astBuilder.nilLit()
    return { tag = "Nil", pos = -1 }
end

function astBuilder.numberLit(number)
    return { tag = "Number", pos = -1, number }
end

function astBuilder.stringLit(str)
    return { tag = "String", pos = -1, str }
end

-- TODO: include pairs
function astBuilder.iTable(...)
    return { tag = "Table", pos = -1, ... }
end

function astBuilder.functionExp(namelist, block)
    return { tag = "Function", pos = -1, namelist, block }
end

function astBuilder.callExp(...)
    return astBuilder.callStmt(...)
end

function astBuilder.Pair(fst, snd)
    return { tag = "Pair", pos = -1, fst, snd }
end

function astBuilder.paren(exp)
    return { tag = "Paren", pos = -1, exp }
end

function astBuilder.index(prefixExp, bracketExp)
    return { tag = "Index", pos = -1, prefixExp, bracketExp }
end

function astBuilder.op(operator, left, right)
    return { tag = "Op", pos = -1, operator, left, right }
end

function astBuilder.block(...)
    return { tag = "Block", pos = -1, ... }
end

-- usage example
-- auxNaryAnd(astBuilder.id'foo', astBuilder.id'bar')
function astBuilder.auxNaryAnd(first, ...)
    return util.ifold(
        table.pack(...),
        function(value, accumulator)
            return astBuilder.op(
                astBuilder.operator['and'], accumulator, value)
        end,
        first)
end

function astBuilder.auxVarList(...)
    astBuilder.varList(
        table.unpack(
            util.imap(
                table.pack(...),
                function(str)
                    return astBuilder.id(str)
                end)))
end

function astBuilder.auxNameList(...)
    return
        astBuilder.nameList(
            table.unpack(
                util.imap(
                    table.pack(...),
                    function(str)
                        return astBuilder.id(str)
                    end)))
end

astBuilder.operator = {
    sub =  "sub", unm =  "unm", mul =  "mul",
    div =  "div", idiv = "idiv", bor =  "bor",
    shl =  "shl", len =  "len", pow =  "pow",
    mod =  "mod", band = "band", concat ="concat",
    lt =   "lt", ["not"]  =  "not", ["and"] =  "and",
    ["or"] =   "or", gt =   "gt",
    le =   "le", eq =   "eq", add = "add"
}

return astBuilder
