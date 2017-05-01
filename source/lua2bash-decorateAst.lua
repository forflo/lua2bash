local util = require("lua2bash-util")
local staticChecker = require("lua2bash-staticChecker")

local decorator = {}

function decorator.decorate(ast)
    -- every root expression sub-AST shall be decorated
    -- by an additional attribute called isStatic whose
    -- value be determined by the isStatic predicate
    util.traverse(
        ast,
        function(node)
            node.isStatic = staticChecker.isStatic(node)
        end,
        nil, -- no environment
        util.isExpNode,
        false) -- no recursion
end

return decorator
