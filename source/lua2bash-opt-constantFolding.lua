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
        -- delete all previous childs
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
    traverser.traverse(root, foldingVisitor, traverser.isExpNode, false)
    return root
end

return constantFolder
