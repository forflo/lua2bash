local util = require("lua2bash-util")
local datastructs = require("lua2bash-datatypes")

local traverser = {}

-- traverses a syntax tree and calls func with the current
-- node for every node. func gets the ast and the environment.
-- func will only called if predicate returns true for the
-- current node
function traverser.traverseWorker(
        node, tuples, parentStack, terminator, siblingNumberStack)
    -- determine whether to abort or continue the recursion
    local continueNext, abortRecursion = true, false
    if terminator(node, parentStack, siblingNumberStack) then
        return abortRecursion
    end
    if traverser.isNode(node) == false then
        return continueNext
    end
    -- Determine what functions to call
    local preFuncs, postFuncs, count = {}, {}, 0
    for tuple in util.iter(tuples) do
        local pRes = tuple:first()(node, parentStack, siblingNumberStack)
        if pRes then
            --dbg()
            preFuncs[#preFuncs + 1] = tuple:elem(2)
            postFuncs[#postFuncs + 1] = tuple:elem(3)
            count = count + 1
        end
    end
    -- if count > 1 then
    -- print('more than one functions will be run!: ' .. count) end
    --
    -- function call before recursion.
    local noRecurSubtree = false
    for _, preFunc in ipairs(preFuncs) do
        noRecurSubtree = noRecurSubtree or (
            preFunc(node, parentStack, siblingNumberStack) == 'norecur')
    end
    if noRecurSubtree == true then
        return continueNext
    end
    -- recursion into subtree
    local currentSiblingIdx, nodeIterator = 1, util.statefulIIterator(node)
    local childNode, continue = nodeIterator(), true
    while childNode ~= nil and continue do
        parentStack:push(node)
        siblingNumberStack:push(currentSiblingIdx)
        continue = traverser.traverseWorker(
            childNode, tuples, parentStack,
            terminator, siblingNumberStack)
        parentStack:pop()
        siblingNumberStack:pop()
        --
        childNode = nodeIterator()
        currentSiblingIdx = currentSiblingIdx + 1
    end
    -- function call after recursion
    for _, postFunc in ipairs(postFuncs) do
        postFunc(node, parentStack, siblingNumberStack)
    end
    return continueNext
end

function traverser.isNode(obj)
    if type(obj) == "table" then return true
    else return false end
end

-- regular top down traversal
function traverser.traverse(ast, func, targetPredicate)
    local defaultTerminator = util.bind(false, util.identity)
    local initialParentStack = datastructs.Stack()
    local initialSiblingStack = datastructs.Stack():push(1)
    local tuples = { datastructs.Tuple(targetPredicate, func, util.identity) }
    traverser.traverseWorker(
        ast, tuples, initialParentStack,
        defaultTerminator, initialSiblingStack)
    return ast
end

-- Predicate gets the 4 arguments:
--   node, parentStack, siblingNumberStack and scopeStack
-- If it holds true first preFunc will be called. If the call
-- returns true, all subtrees of the current node will be traversed
-- otherwise the traversal of the subtree will not be done.
-- After that, postFunc will be executed.
-- Both, preFunc and postFunc get the same arguments as predicate
function traverser.traverseScoped(ast, preFunc, postFunc, predicate, terminator)
    local defaultTerminator = terminator or util.bind(false, util.identity)
    local initialParentStack = datastructs.Stack()
    local initialSiblingStack = datastructs.Stack():push(1)
    local scopeStack = datastructs.Stack()
    -- construct new predicate that contains scopeStack as upvalue
    local scopedPredicate = function(node, parentStack, siblingNumStack)
        return predicate(node, parentStack, siblingNumStack, scopeStack)
    end
    local scopedPreFunc = function(node, parentStack, siblingNumStack)
        return preFunc(node, parentStack, siblingNumStack, scopeStack)
    end
    local scopedPostFunc = function(node, parentStack, siblingNumStack)
        return postFunc(node, parentStack, siblingNumStack, scopeStack)
    end
    -- Handles creation and destruction of the scope stack
    local scopePush = function(_, _, _)
        scopeStack:push(datastructs.BinderTable())
    end
    local scopePop = function(_, _, _) scopeStack:pop() end
    -- Expression node handling
    local preExp = function(node, _, _)
        if node.tag == 'Function' then
            local varNames = util.imap(node[1], util.bind(1, util.index))
            local binderTable =
                datastructs.BinderTable():addBindings(node, varNames)
            scopeStack:push(binderTable)
        end
        return 'recur' -- traverse further
    end
    local postExp = function(node, _, _)
        if node.tag == 'Function' then
            scopeStack:pop()
        end
    end
    -- Statement node handling
    local preStmt = function(node, _, _)
        local tag = node.tag
        if tag == 'Local' then
            -- only after the subtree of local is traversed
            -- the new variables become visible!
            return 'recur'
        elseif tag == 'Forin' then
            -- names must be a list of strings
            local varNames = util.imap(node[1], util.bind(1, util.index))
            local newBinderTable =
                datastructs.BinderTable():addBindings(node, varNames)
            scopeStack:push(newBinderTable)
            return 'recur'
        elseif tag == 'Fornum' then
            local varName = node[1][1]
            local newBinderTable =
                datastructs.BinderTable():addBinding(node, varName)
            scopeStack:push(newBinderTable)
            return 'recur'
        elseif tag == 'Repeat' then
            -- TODO: implement this special case!
            return 'norecur'
        else
            return 'recur'
        end
    end
    local postStmt = function(node, _, _)
        local tag = node.tag
        if tag == 'Forin' or tag == 'Fornum' then
            scopeStack:pop()
        elseif tag == 'Local' then
            local varNames = util.imap(node[1], util.bind(1, util.index))
            scopeStack:top():addBindings(node, varNames)
        end
    end
    -- Since only one predicate in tuples (see below) can return true
    -- Call nodes are only considered expression nodes for this matter
    local stmtPred = function(node, _, _, _)
        if node.tag == 'Call' then return false
        else return util.isStmtNode(node) end
    end
    local expPred = util.isExpNode
    local blockPred = util.isBlockNode
    -- This is the configuration list for the traverser
    local tuples = {
        datastructs.Tuple(stmtPred, preStmt, postStmt),
        datastructs.Tuple(expPred, preExp, postExp),
        datastructs.Tuple(blockPred, scopePush, scopePop),
        datastructs.Tuple(scopedPredicate, scopedPreFunc, scopedPostFunc)
    }
    -- now call the regular traverser with the modified functions
    return traverser.traverseWorker(
        ast, tuples, initialParentStack,
        defaultTerminator, initialSiblingStack)
end

-- TODO: This is inefficient immediate following scope
-- stacks can be calculated much more efficiently
-- returns the parent stack, sibling stack and scope stack
-- at the position when 'node' is reached
function traverser.seekTraverserState(ast, node)
    if node == nil then return nil, nil, nil, nil end
    local resultParentStack, resultSiblingStack, resultScopeStack
    local terminate = false
    local function terminator(_, _, _, _) return terminate end
    local function predicate(traversalNode)
        if traversalNode == node then
            terminate = true
            return true
        else
            return false
        end
    end
    local function pre(_, parentStack, siblingStack, scopeStack)
        resultParentStack = parentStack:deepCopy()
        resultSiblingStack = siblingStack:deepCopy()
        resultScopeStack = scopeStack:deepCopy()
    end
    traverser.traverseScoped(ast, pre, util.identity, predicate, terminator)
    return node, resultParentStack, resultSiblingStack, resultScopeStack
end

-- depth first traversal
-- @func - the function to call if predicate(<currentNode>) is true
--     Gets called with <currentNode> and with the result of @joinFunc
-- @joinFunc - The traverser always calls itself recursively on all
--     nested tables (if any) before it calles @func.
--     Thus, for n nested tables inside @ast, there are n results
--     from the recursion itself. @joinFunc provides a means to join
--     those results before they get passed to @func
function traverser.traverseBottomUp(
        ast, func, predicate, joinFunc)
    joinFunc = joinFunc or util.identity
    local recursionResult
    if type(ast) ~= "table" then return ast end
    recursionResult = util.imap(
        ast,
        function(node)
            return traverser.traverseBottomUp(
                node, func, predicate, joinFunc) end)
    if predicate(ast) then
        return func(ast, joinFunc(recursionResult))
    else
        return nil
    end
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
