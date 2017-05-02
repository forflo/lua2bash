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
        function(node, _)
            -- we can safely ignore the fact that this might also
            -- be run on call nodes that are mere statements
            -- it is left to the static checker to decide
            -- whether those calls have side effects or not.
            -- In case of a side effect, the calls will remain untouched
            node.isStatic = staticChecker.isStatic(node)
        end,
        traverser.isExpNode,
        false) -- no recursion

    return ast
end


return decorator
