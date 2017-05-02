local util = {}

local ntostring
function ntostring(tbl, indent)
    indent = indent or 0
    local function rep(i) return string.rep(" ", i) end
    if type(tbl) == "table" then
        local s = "{" .. "\n"
        for k, v in pairs(tbl) do
            s = s .. rep(indent + 2) .. tostring(k)
                .. " = " .. ntostring(v, indent + 2) .. "\n"
        end
        s = s .. rep(indent) .. "}"
        return s
    else
        return tostring(tbl)
    end
end
util.tostring = ntostring


-- print(util.tostring{1,2,3})
-- print(util.tostring{"foo", "bar"})
-- print(util.tostring{1,{"foo", "bar"},2,3,{3,4,{4,5,6}}})
-- print(util.tostring({1,{"foo", "bar"},2,3,{3,4,{4,5,6}}}))

function util.max(n1, n2)
    return util.expIfStrict(n1 <= n2, n2, n1)
end

-- recursively traverses depth-first (left to right)
-- and appends each non-table value to result
function util.tableFlatten(tbl, result)
    if type(tbl) ~= "table" then
        result[#result + 1] = tbl
    else
        for _, v in pairs(tbl) do
            util.tableFlatten(v, result)
        end
    end
    return result
end

function util.tableIConcat(tbl1, result)
    result = result or {}
    for _, v in ipairs(tbl1) do
        if type(v) == "table" then
            for _, w in ipairs(v) do
                result[#result + 1] = w
            end
        else
            result[#result + 1] = v
        end
    end
    return result
end

function util.call(callable)
    return callable()
end

-- mainly used by the serializer functions
function util.strToOpstr(str)
    if str == "add" then return "+"
    elseif str == "sub"    then return "-"
    elseif str == "unm"    then return "-"
    elseif str == "mul"    then return "*"
    elseif str == "div"    then return "/"
    elseif str == "idiv"   then return "//"
    elseif str == "bor"    then return "|"
    elseif str == "shl"    then return "<<"
    elseif str == "shr"    then return ">>"
    elseif str == "len"    then return "#"
    elseif str == "pow"    then return "^"
    elseif str == "mod"    then return "%"
    elseif str == "band"   then return "&"
    elseif str == "concat" then return ".." -- probably special case
    elseif str == "lt"     then return "<"
    elseif str == "not"    then return str
    elseif str == "and"    then return str
    elseif str == "or"     then return str
    elseif str == "gt"     then return ">"
    elseif str == "le"     then return "<="
    elseif str == "eq"     then return "=="
    else
        print("StrToOpstr: Unknown operator!")
        print(tostring(str))
        os.exit(1)
    end
end

function util.iterate(fun, arg, n)
    if (n <= 1) then return fun(arg)
    else return util.iterate(fun, fun(arg), n - 1) end
end

-- adds indentation and optionally a comment
function util.augmentLine(indent, line, comment)
    if comment then comment = " # " .. comment end
    return string.format("%s%s %s",
                         string.rep(" ", indent),
                         line,
                         comment or "")
end

function util.expIf(cond, funTrue, funFalse)
    if cond then return funTrue()
    else return funFalse() end
end

function util.expIfStrict(cond, expTrue, expFalse)
    if cond then return expTrue
    else return expFalse end
end

function util.filter(tbl, fun)
    local result = {}
    for _, v in pairs(tbl) do
        if fun(v) then result[#result + 1] = v end
    end
    return result
end

function util.ifold(tbl, fun, acc)
    for _, v in ipairs(tbl) do
        acc = fun(v, acc)
    end
    return acc
end

function util.map(tbl, func)
    local result = {}
    for _, v in pairs(tbl) do
        result[#result + 1] = func(v)
    end
    return result
end

-- Note that if func returns nil, LUA's table semantic leads to
-- no additional field being added to the resulting map
function util.imap(tbl, func)
    local result = {}
    for _, v in ipairs(tbl) do
        result[#result + 1] = func(v)
    end
    return result
end

-- The identity function
function util.identity(x) return x end

function util.join(strings, char)
    if not strings or #strings == 0 then return "" end
    local result = strings[1]
    if #strings == 1 then return strings[1] end
    for i=2, #strings do
        result = result .. char .. strings[i]
    end
    return result
end

function util.bind(argument, func)
    return function(...)
        return func(argument, ...)
    end
end

function util.flip(func)
    return function(left, right)
        return func(right, left)
    end
end

function util.getCounter(increment)
    increment = increment or 1
    local upvalCount = 0
    return function()
        upvalCount = upvalCount + increment
        return upvalCount
    end
end

util.operator = {
        add = function(x, y) return x + y end,
        sub = function(x, y) return x - y end,
        equ = function(x, y) return x == y end,
        neq = function(x, y) return x ~= y end,
        logAnd = function(x, y) return x and y end
}

function util.exists(tbl, value, comparator)
    local result = false
    for _, v in pairs(tbl) do
        result = result or comparator(v, value)
    end
    return result
end

function util.zipI(left, right)
    if (left == nil or right == nil) then return nil end
    if #left ~= #right then return nil end
    local result = {}
    for k, _ in ipairs(left) do
        result[k] = {left[k], right[k]}
    end
    return result
end

function util.addLine(indent, lines, line, comment)
    lines[#lines + 1] = util.augmentLine(indent, line, comment)
end

function util.addComment(indent, lines, comment)
    lines[#lines + 1] = util.augmentLine(indent, "# " .. comment)
end

function util.tableIAddInplace(dest, source)
    dest = dest or {} -- make new table if dest is nil
    for _, v in ipairs(source) do dest[#dest + 1] = v end
    return dest
end

function util.tableFullAdd(left, right)
    local result = {}
    for _, v in pairs(left) do result[#result + 1] = v end
    for _, v in pairs(right) do result[#result + 1] = v end
    return result
end

function util.tableIAdd(left, right)
    local result = {}
    for _,v in ipairs(left) do result[#result + 1] = v end
    for _,v in ipairs(right) do result[#result + 1] = v end
    return result
end

function util.tableSlice(tbl, first, last, step)
  local sliced = {}
  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end
  return sliced
end

function util.incCC(config)
    config.columnCount = config.columnCount + config.indentSize
end

function util.decCC(config)
    config.columnCount = config.columnCount - config.indentSize
end

function util.statefulIIterator(tbl)
    local index = 0
    return function()
        index = index + 1
        return tbl[index]
    end
end

-- returns iterator that does
-- return action(next) on each call on next
function util.actionIIterator(tbl, action)
    local iterator = util.statefulIIterator(tbl)
    return function()
        return action(iterator())
    end
end

function util.tableGetKeyset(tbl)
    local n = 0
    local keyset = {}
    for k, _ in pairs(tbl) do
        n = n + 1
        keyset[n] = k
    end
    return keyset
end

-- can also be used in conjunction with for in loops
-- example:
-- for k, v in statefulKVIterator{x = 1, y = 2, z = 3, 1, 2, 3} do
--     print (k, v)
-- end
function util.statefulKVIterator(tbl)
    local keyset = util.tableGetKeyset(tbl)
    local keyIdx = 0
    return function()
        keyIdx = keyIdx + 1
        return keyset[keyIdx], tbl[keyset[keyIdx]]
    end
end

function util.tblCountAll(table)
    local counter = 0
    for _, _ in pairs(table) do
        counter = counter + 1
    end
    return counter
end

function util.extractIPairs(tab)
    local result = {}
    for _, v in ipairs(tab) do
        result[#result + 1] = v
    end
    return result
end

function util.tableReverse(tab)
    local result = {}
    for i=#tab,1,-1 do
        result[#result + 1] = tab[i]
    end
    return result
end

-- maps between lua types and the type tags used
-- by the package lua-parser
util.typeToType = {
    ["number"] = "Number",
    ["string"] = "String",
    ["table"] = "Table",
    ["nil"] = "Nil",
    ["true"] = "True",
    ["false"] = "False",
    ["function"] = "Function"
}

function util.isNode(node)
    return node.tag ~= nil
end

function util.isStmtNode(node)
    local stmtTags = {
        "Call", "Fornum", "Local", "Forin", "Repeat",
        "Return", "Break", "If", "While", "Do", "Set"
    }

    return util.exists(stmtTags, node.tag, util.operator.equ)
end

function util.isBlockNode(node)
    return util.exists({"Block", "Do"}, node.tag, util.operator.equ)
end

function util.isExpNode(node)
    local expTags = {
        "Op", "Id", "True", "False", "Nil", "Number", "String", "Table",
        "Function", "Call", "Pair", "Paren", "Index"
    }
    return util.exists(expTags, node.tag, util.operator.equ)
end

function util.isConstantNode(node)
    local constTags = {
        "True", "False", "Number",
        "Nil", "String"
    }
    return util.exists(constTags, node.tag. util.operator.equ)
end

-- currying just for fun
function util.fillup(column)
    return function(str)
        local l = string.len(str)
        if column > l then
            return string.format("%s%s", str, string.rep(" ", column - l))
        else
            return str
        end
    end
end

function util.assertAstHasTag(node, tag, message)
    local stdMsg = "Node has not tag type: " .. tag
    message = message or stdMsg
    assert(node.tag == tag, message)
end

-- function composition
-- compose(fun1)(fun2)("foobar") = fun1(fun2("foobar"))
function util.compose(funOuter)
    return function(funInner)
        return function(x)
            return funOuter(funInner(x))
        end
    end
end

-- vararg function composition
-- compose(fun1, fun2, ... fun_n)(x) = fun1(fun2(...fun_n(x)))
function util.composeV(...)
    local functions = table.pack(...)
    return function(x)
        local final = functions[#functions](x)
        for i = #functions - 1, 1, -1 do
            final = functions[i](final)
        end
        return final
    end
end

return util
