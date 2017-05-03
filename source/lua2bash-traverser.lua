local util = require("lua2bash-util")
local datastructs = require("lua2bash-datatypes")

local traverser = {}

-- traverses a syntax tree and calls func with the current
-- node for every node. func gets the ast and the environment.
-- func will only called if predicate returns true for the
-- current node
function traverser.traverseWorker(
        ast, func, predicate, recur, parentStack)
    if type(ast) ~= "table" then return end
    if predicate(ast) then
        func(ast, parentStack)
        -- don't traverse this subtree.
        -- the function func takes care of that
        if not recur then
            return
        end
    end
    for _, node in ipairs(ast) do
        parentStack:push(ast)
        traverser.traverseWorker(
            node, func, predicate, recur, parentStack)
        parentStack:pop()
    end
end

-- regular top down traversal
function traverser.traverse(
        ast, func, targetPredicate, recurOnTrue)
    traverser.traverseWorker(
        ast, func, targetPredicate, recurOnTrue,
        datastructs.Stack())
    return ast
end

-- depth first traversal
-- @func - the function to call if predicate(<currentNode>) is true
--     Gets called with <currentNode> and with the result of @joinFunc
-- @joinFunc - The traverser always calls itself recursively on all
--     nested tables (if any) before it calles @func.
--     Thus, for n nested tables inside @ast, there are n results
--     from the recursion itself. @joinFunc provides a means to join
--     those results before they get passed to @func
function traverser.traverseBottomUp(
        ast, func, predicate, joinFunc)
    joinFunc = joinFunc or util.identity
    local recursionResult
    if type(ast) ~= "table" then return ast end
    recursionResult = util.imap(
        ast,
        function(node)
            return traverser.traverseBottomUp(
                node, func, predicate, joinFunc) end)
    if predicate(ast) then
        return func(ast, joinFunc(recursionResult))
    else
        return nil
    end
end

function traverser.nodePredicate(typ)
    return function(node)
        if node.tag == typ then return true
        else return false end
    end
end

function traverser.getUsedSymbols(ast)
    local result = {}
    local visitor = function(astNode, _)
        local varName = astNode[1]
        result[varName] = true
    end
    traverser.traverse(ast, visitor, traverser.nodePredicate("Id"), true)
    return util.tableGetKeyset(result)
end

return traverser
