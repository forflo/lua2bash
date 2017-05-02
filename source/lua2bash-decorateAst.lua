local util = require("lua2bash-util")
local traverser = require("lua2bash-traverser")
local staticChecker = require("lua2bash-staticChecker")
local datastructs = require("lua2bash-")

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
        util.isExpNode,
        false) -- no recursion

    -- adds the field local assignments to each block node
    traverser.traverse(
        ast,
        function(block, _)
            local localAssignments =
                util.imap(
                    block,
                    function(statement)
                        if statement.tag == "Local" then
                            return statement
                        else
                            return nil
                        end
                end)
            local globalAssignments =
                util.imap(
                    block,
                    function(statement)
                        if statement.tag == "Set" then
                            return statement
                        else
                            return nil
                        end
                    end)
            block.localAssignments = localAssignments
            block.globalAssignments = globalAssignments
        end,
        util.isBlockNode,
        false)

    -- Determines constants
    -- complexity of this call probably O(n^2). Not good, but
    -- simple and I don't care about performance here

    traverser.traverse(
        ast,
        function(block, _)
            assert(block.localAssignments, "Block misses decoration: localAssign")
            local localAssigns = block.localAssignments
        end,
        util.isBlockNode,
        true)

    return ast
end


function decorator.makeScopeTree(ast)
    local localAssignments =
        util.imap(
            ast,
            function(statement)
                if statement.tag == "Local" then
                    return statement
                else
                    return nil
        end end)
    local assignments =
        util.imap(
            ast,
            function(statement)
                if statement.tag == "Set" then
                    return statement
                else
                    return nil
        end end)
    local spaghettiStack
    traverser.traverse(
        ast,
        function(node, _)
            -- start
            if node == ast then
                spaghettiStack = datastructs.SpaghettiStack(
                    nil, localAssignments, assignments, "Block")
                return
            end

            if util.isBlockNode(node) then
                local tempStack = datastructs.SpaghettiStack(
                    spaghettiStack, localAssignments(node),
                    assignments(node), "Block")
                spaghettiStack = tempStack
            else

            end
        end,
        util.isNode,
        true)
end



return decorator
