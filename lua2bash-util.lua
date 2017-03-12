-- adds indentation and optionally a comment
function augmentLine(env, line, comment)
    if comment then comment = " # " .. comment end
    return string.format("%s%s %s",
                         string.rep(" ", env.columnCount),
                         line,
                         comment or "")
end

function imap(tbl, func)
    local result = {}
    for k,v in ipairs(tbl) do
        result[#result + 1] = func(v)
    end

    return result
end

function join(strings, char)
    local result = strings[1]
    if #strings == 1 then return strings[1] end
    for i=2, #strings do
            result = result .. char .. strings[i]
    end
    return result
end

function derefLocation(location)
    return string.format("${!%s[1]}", location)
end

function getUniqueId(env)
    env.globalIdCount = env.globalIdCount + 1
    return env.globalIdCount
end

function getScopePath(ast, env)
    local scopeNames = {}

    for i = 1, #env.scopeStack do
        scopeNames[#scopeNames + 1] = env.scopeStack[i].name
    end

    --dbg()
    --result must be string
    return ""
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

function tableIAdd(left, right)
    if (left == nil) then return right end
    if (right == nil) then return left end

    result = {}
    for k,v in ipairs(left) do
        result[#result + 1] = v
    end
    for k,v in ipairs(right) do
        result[#result + 1] = v
    end

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

-- annotates the AST adding the member containsFuncs to all
-- function nodes. This field can either be true or falsea. If
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
