local util = require("lua2bash-util")
local traverser = require("lua2bash-traverser")
local staticChecker = require("lua2bash-staticChecker")

local decorator = {}

function decorator.decorate(ast)
    -- every root expression sub-AST shall be decorated
    -- by an additional attribute called isStatic whose
    -- value be determined by the isStatic predicate
    traverser.traverse(
        ast,
        function(node)
            node.isStatic = staticChecker.isStatic(node)
        end,
        traverser.isExpNode,
        false) -- no recursion
    return ast
end

return decorator
