oldtostring = tostring
function tostring(x)
    local s
    if type(x) == "table" then
        s = "{ "
        local i, v = next(x)
        while i do
            s = s .. tostring(i) .. " = " .. tostring(v)
            i, v = next(x, i)
            if i then s = s .. ", " end
        end
        return s .. " }"
    else
        return oldtostring(x)
    end
end

function max(n1, n2)
    return expIfStrict(n1 <= n2, n2, n1)
end

function iterate(fun, arg, n)
    if (n <= 1) then return fun(arg)
    else return iterate(fun, fun(arg), n - 1) end
end

-- adds indentation and optionally a comment
function augmentLine(env, line, comment)
    if comment then comment = " # " .. comment end
    return string.format("%s%s %s",
                         string.rep(" ", env.columnCount),
                         line,
                         comment or "")
end

function expIf(cond, funTrue, funFalse)
    if cond then
        return funTrue()
    else
        return funFalse()
    end
end

function expIfStrict(cond, expTrue, expFalse)
    if cond then
        return expTrue
    else
        return expFalse
    end
end

function imap(tbl, func)
    local result = {}
    for k, v in ipairs(tbl) do
        result[#result + 1] = func(v)
    end
    return result
end

function join(strings, char)
    if #strings == 0 then return "" end

    local result = strings[1]
    if #strings == 1 then return strings[1] end
    for i=2, #strings do
            result = result .. char .. strings[i]
    end
    return result
end

function getUniqueId(env)
    env.globalIdCount = env.globalIdCount + 1
    return env.globalIdCount
end


function zipI(left, right)
    if (left == nil or right == nil) then return nil end
    if #left ~= #right then return nil end

    result = {}

    for k,v in ipairs(left) do
        result[k] = {left[k], right[k]}
    end

    return result
end

function addLine(env, lines, line, comment)
    lines[#lines + 1] = augmentLine(env, line, comment)
end

function tableIAddInplace(dest, source)
    local dest = dest or {} -- make new table if dest is nil
    for k, v in ipairs(source) do dest[#dest + 1] = v end
    return dest
end

function tableFullAdd(left, right)
    result = {}
    for k, v in pairs(left) do result[#result + 1] = v end
    for k, v in pairs(right) do result[#result + 1] = v end
    return result
end

function tableIAdd(left, right)
    result = {}
    for k,v in ipairs(left) do result[#result + 1] = v end
    for k,v in ipairs(right) do result[#result + 1] = v end
    return result
end

function tableSlice(tbl, first, last, step)
  local sliced = {}
  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end
  return sliced
end

function msgdebug(msg)
--    print(string.format("[%s]: %s", debug.getinfo(2).name, msg))
end

function incCC(env)
    env.columnCount = env.columnCount + env.indentSize
end

function statefulIIterator(tbl)
    local index = 0
    return function()
        index = index + 1
        return tbl[index]
    end
end

function tableGetKeyset(tbl)
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
function statefulKVIterator(tbl)
    local keyset = tableGetKeyset(tbl)
    local keyIdx = 0
    return function()
        keyIdx = keyIdx + 1
        return keyset[keyIdx], tbl[keyset[keyIdx]]
    end
end

function decCC(env)
    env.columnCount = env.columnCount - env.indentSize
end

function tblCountAll(table)
    local counter = 0
    for _1, _2 in pairs(table) do
        counter = counter + 1
    end
    return counter
end

function extractIPairs (tab)
    local result = {}
    for k,v in ipairs(tab) do
        result[#result + 1] = v
    end
    return result
end

function tableReverse (tab)
    local result = {}
    for i=#tab,1,-1 do
        result[#result + 1] = tab[i]
    end
    return result
end

-- does scope analysis tailored towards closure detection
function traverser(ast, func, env, predicate, recur)
    if type(ast) ~= "table" then return end

    if predicate(ast) then
        func(ast, env)

        -- don't traverse this subtree.
        -- the function func takes care of that
        if not (recur) then
            return
        end
    end

    for k, v in ipairs(ast) do
        traverser(v, func, env, predicate, recur)
    end
end

function getNodePredicate(typ)
    return function(node)
        if node.tag == typ then
            return true
        else
            return false
        end
    end
end

function getUsedSymbols(ast)
    local visitor = function(astNode, env)
        env[astNode[1]] = true
    end

    local result = {}
    traverser(ast, visitor, result, getNodePredicate("Id"), true)

    return tableGetKeyset(result)
end

-- annotates the AST adding the member containsFuncs to all
-- function nodes. This field can either be true or false. If
-- it is true, the subtree will contain at least one other function
-- subtree, otherwise one can be sure that there is no other function
-- declaration
traverser(ast,
          function (node)
              local env = {count = 0}
              local predicate = function (x) return true end -- traverse all
              local counter = function (node, env)
                  if node.tag == "Function" then
                      env.count = env.count + 1
                  end
              end

              traverser(node, counter, env, predicate, true)
              if env.count > 1 then
                  node.containsFuncs = true
              else
                  node.containsFuncs = false
              end

          end, nil,
          function (node)
              if node.tag == "Function" then
                  return true
              else
                  return false
              end
          end, true)

-- currying just for fun
function fillup(column)
    return function(str)
        local l = string.len(str)
        if column > l then
            return string.format("%s%s", str, string.rep(" ", column - l))
        else
            return str
        end
    end
end

-- function composition
-- compose(fun1, fun2)("foobar") = fun1(fun2("foobar"))
function compose(funOuter)
    return function(funInner)
        return function(x)
            return funOuter(funInner(x))
        end
    end
end
