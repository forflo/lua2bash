local util = require("lua2bash-util")
local traverser = require("lua2bash-traverser")
local staticChecker = require("lua2bash-staticChecker")
local datastructs = require("lua2bash-datatypes")
local astQuery = require("lua2bash-astQuery")

local decorator = {}

function decorator.decorate(ast)

    decorator.decorateWithStatic(ast)
    decorator.decorateWithPaths(ast)

    return ast
end

function decorator.decorateWithStatic(ast)
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
        util.isExpNode,
        false) -- no recursion
end

function decorator.decorateWithPaths(ast)
    traverser.traverse(
        ast,
        function(node, parentStack)
            node.path = astQuery.AstPath():initByStack(parentStack)
        end,
        function(_) return true end,
        true)
end

-- TODO: This is very inefficient (O(n^2)). Make it linear
-- with respect to time and storage!
-- Decorates with scopeTrees aka spaghetti trees
-- but precalculated
-- depends on decorator.decorateWithPaths
function decorator.decorateWithScopeTrees(ast)
    traverser.traverse(
        ast,
        function(block, _)
            -- TODO: are these lines really unnecessary
            -- local temp = astQuery.AstPath(parentStack)
            -- local immediateParent = temp:goBottom():Node()
            local scopeTree =
                traverser.traverseBottomUp(
                    block,
                    function(b, bottomResults)
                        return {
                            localAssigns = decorator.localAssignments(b),
                            globalAssigns = decorator.assignments(b),
                            table.unpack(bottomResults)
                        }
                    end,
                    util.isBlockNode,
                    util.identity)
            -- scopeTree.scopeReason = immediateParent.tag
            block.scopeTree = scopeTree
        end,
        util.isBlockNode,
        true)
end

-- non-recursive
function decorator.localAssignments(ast)
    return
        util.imap(
            ast,
            function(statement)
                if statement.tag == "Local" then
                    return statement
                else
                    return nil
        end end)
end

-- non-recursive
function decorator.assignments(ast)
    return
        util.imap(
            ast,
            function(statement)
                if statement.tag == "Set" then
                    return statement
                else
                    return nil
        end end)
end

return decorator
