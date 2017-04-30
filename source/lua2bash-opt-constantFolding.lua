local util = require("lua2bash-util")
local staticChecker = require("lua2bash-staticChecker")
local serializer = require("lua2bash-serialize-ast")

local constantFolder = {}
-- rudimentary constant folder
-- uses loadstring to evaluate terms

local function foldingVisitor(node)
    local foldable = staticChecker(node)
    if foldable then
        local eval, errMsg = loadstring('return ' .. serializer.serialize(node))
        assert(eval, errMsg)
        local result = eval()
        node.tag = util.typeToType[type(result)]
        if not (result == nil or result == true or result == false) then
            node[1] = result
        end
    end
end

function constantFolder.foldConst(root)
    util.traverse(root, foldingVisitor, nil, util.isExpNode, false)
end

return constantFolder
