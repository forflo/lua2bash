local util = require("lua2bash-util")
local datastructs = require("lua2bash-datatypes")

local traverser = {}

-- traverses a syntax tree and calls func with the current
-- node for every node. func gets the ast and the environment.
-- func will only called if predicate returns true for the
-- current node
function traverser.traverse(ast, func, environment, predicate, recur, parentStack)
    parentStack = parentStack or datastructs.Stack()
    if type(ast) ~= "table" then return end
    if predicate(ast) then
        func(ast, environment, parentStack)
        -- don't traverse this subtree.
        -- the function func takes care of that
        if not recur then
            return
        end
    end
    for _, node in ipairs(ast) do
        parentStack:push(ast)
        traverser.traverse(
            node, func, environment,
            predicate, recur, parentStack)
        parentStack:pop()
    end
end

function traverser.nodePredicate(typ)
    return function(node)
        if node.tag == typ then return true
        else return false end
    end
end

function traverser.isExpNode(node)
    local expTags = {
        "Op", "Id", "True", "False", "Nil", "Number", "String", "Table",
        "Function", "Call", "Pair", "Paren", "Index"
    }
    return util.exists(expTags, node.tag, util.operator.equ)
end

function traverser.getUsedSymbols(ast)
    local visitor = function(astNode, env)
        env[astNode[1]] = true
    end
    local result = {}
    traverser.traverse(ast, visitor, result, traverser.nodePredicate("Id"), true)
    return util.tableGetKeyset(result)
end

return traverser
