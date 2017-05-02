local util = require("lua2bash-util")
local datastructs = require("lua2bash-datatypes")

local traverser = {}

-- traverses a syntax tree and calls func with the current
-- node for every node. func gets the ast and the environment.
-- func will only called if predicate returns true for the
-- current node
function traverser.traverseWorker(
        ast, func, predicate, recur, parentStack)
    parentStack = parentStack or datastructs.Stack()
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
        traverser.traverse(node, func, predicate, recur, parentStack)
        parentStack:pop()
    end
end

function traverser.traverse(
        ast, func, targetPredicate, recurOnTrue)
    traverser.traverseWorker(ast, func, targetPredicate, recurOnTrue, nil)
    return ast
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
