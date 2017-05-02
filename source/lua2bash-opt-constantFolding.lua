local util = require("lua2bash-util")
local serializer = require("lua2bash-serialize-ast")
local traverser = require("lua2bash-traverser")
local dbg = require("debugger")

local constantFolder = {}
-- rudimentary constant folder
-- uses loadstring to evaluate terms

local function foldingVisitor(node)
    local foldable = node.isStatic
    if foldable then
        local eval, errMsg = loadstring('return ' .. serializer.serialize(node))
        assert(eval, errMsg)
        local result = eval()
        -- delete all tags and previous childs
        --dbg()
        for k, _ in pairs(node) do
            node[k] = nil
        end
        -- add result of folded expression
        node.tag = util.typeToType[type(result)]
        node.pos = -1 -- dummy value
        if not (result == nil or result == true or result == false) then
            node[1] = result
        else
            node.tag = util.typeToType[tostring(result)]
        end
    end
end

function constantFolder.foldConst(root)
    traverser.traverse(root, foldingVisitor, util.isExpNode, false)
    return root
end

local function propagateVisitor(node, _)
    assert(node.localAssignments, "AST decoration is missing: localAssigns")
    assert(node.globalAssignments, "AST decoration is missing: globAssigns")

end

-- This constant propagation algorithm works in one go even for
-- more complicated cascading constants such as:
----
-- local a=3
-- do
--   local b=a
--   do
--     local u, c = foo.a, b
--     print(c) -- c will become 3
--   end
-- end
----
-- However, it must be repeated every time after constant folding
-- happens because only this might cause new constants to appear
function constantFolder.propagate(root)
    traverser.traverse(root, propagateVisitor, util.isBlockNode, true)
end

return constantFolder
