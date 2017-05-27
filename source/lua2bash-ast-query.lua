local util = require("lua2bash-util")
local traverser = require("lua2bash-traverser")
local datatypes = require("lua2bash-datatypes")

local astQuery = {}

function astQuery.firstNodeOfType()

end

function astQuery.nthStatement(n, block)
    assert(util.isBlockNode(block), "Is no Block node!")
    return block[n]
end

function astQuery.ifCondition(ifStmt) return ifStmt[1] end
function astQuery.ifTrueBlock(ifStmt) return ifStmt[2] end
function astQuery.ifFalseBlock(ifStmt) return ifStmt[3] end

function astQuery.nthName(n, namelist) return namelist[n] end
function astQuery.nthExp(n, explist) return explist[n] end

function astQuery.localElist(localAssign)
    util.assertAstHasTag(localAssign, "Local")
    return localAssign[2]
end
function astQuery.localNlist(localAssign)
    util.assertAstHasTag(localAssign, "Local")
    return localAssign[1]
end

function astQuery.Nlist(n, namelist)
    util.assertAstHasTag(namelist, "NameList")
    return namelist[n]
end
function astQuery.Elist(n, explist)
    util.assertAstHasTag(explist, "ExpList")
    return explist[n]
end

function astQuery.nthParameter(n, call)
    util.assertAstHasTag(call, "Call")
    assert(#call >= n, "Parameter does not exist")
    return call[n]
end

-- An AstWalker is a tiny abstraction that provides
-- a way of stepping into an AST a little more
-- verbosely than something cryptic like ast[1][2][1][4][3][2]
-- Each step modifies the current position in the AST
-- and returns a self reference. Thus it is possible
-- to chain the steppers.
-- Usage Example:
-- local ast = parse[[do print'foo'; do print(1+2); end; end]]
-- Given we need to get the expression ast of [[1+2]]
-- We might do ast[1][2][1][2]
-- or astQuery.AstWalk(ast):Statement(1):Statement(2):Statement(1):Parameter(1)
-- I find the latter version to be much more readable because it gives
-- one a better grasp about the structure of the path being traversed.
function astQuery.AstWalk(ast)
    local t = {}
    t._node = ast
    function t:currentNode() return self._node end
    function t:setNode(v) self._node = v; return self end
    function t:Statement(n)
        return self:setNode(
            astQuery.nthStatement(
                n, t:currentNode()))
    end
    function t:Parameter(n)
        return self:setNode(
            astQuery.nthParameter(
                n, t:currentNode()))
    end
    function t:ExpList()
        return self:setNode(
            astQuery.localElist(
                t:currentNode()))
    end
    function t:NameList()
        return self:setNode(
            astQuery.localNlist(
                t:currentNode()))
    end
    function t:Expression(n)
        return self:setNode(
            astQuery.Elist(
                n, t:currentNode()))
    end
    function t:Name(n)
        return self:setNode(
            astQuery.Nlist(
                n, t:currentNode()))
    end
    -- synonym
    function t:Node() return self:currentNode() end
    return t
end

-- Encapsulates copies of parent stacks (see lua2bash-traverser module)
-- This is done so that one can view parent stacks as paths through the
-- AST more easily withough having to think about whether to increment
-- the stack index by one or decrementing it by one in order to go up or down.
function astQuery.AstPath()
    local t = { }
    t._genericIterator = nil
    function t:initByStack(parentStack)
        self._genericIterator = parentStack:deepCopy():genericIIterator()
        return self
    end
    -- Go up one step in the AST path
    function t:goUp()
        self._genericIterator:advance(-1)
        return self
    end
    -- Go down one step in the AST path
    function t:goDown()
        self._genericIterator:advance(1)
        return self
    end
    function t:goTop()
        self._genericIterator:setMin()
        return self
    end
    function t:goBottom()
        self._genericIterator:setMax()
        return self
    end
    function t:depth()
        return self._genericIterator:length()
    end
    function t:Node()
        return self._genericIterator:currentObj()
    end
    return t
end

-- usage entry point
function astQuery.astQuery(astRoot)
    assert(astRoot, 'no valid ast root given')
    local this = {}
    this._astRoot = astRoot
    this._combinators = astQuery.astQueryCombinators(astRoot)
    -- mtab fancyness
    local mtab = {}
    mtab.__index = function(indexee, key)
        return indexee._combinators[key]
    end
    mtab.__call = function(callee, startingNode)
        return callee:starting(startingNode)
    end

    function this:starting(s)
        return astQuery.astQueryObj(self._astRoot, s, self._combinators)
    end

    setmetatable(this, mtab)
    return this
end

-- AstQuery predicate combinators and AstQuery predicate
-- generators always are directly related to the root of the
-- AST to query. Thus, astRoot needs to be given as constructor parameter
function astQuery.astQueryCombinators(astRoot)
    local t = {}
    t._ast = astRoot

    -- predicates, predicate generators and predicate combinators
    function t.tag(tag)
        assert(type(tag) == 'string', 'Wrong argument type')
        return datatypes.Predicate(
            function(node, _, _, _)
                return traverser.isNode(node) and node.tag == tag
        end)
    end

    function t.all()
        return datatypes.Predicate(function(_, _, _, _) return true end)
    end

    function t.none()
        return datatypes.Predicate(function(_, _, _, _) return false end)
    end

    -- aliases for t.all and none
    t.accept = t.all
    t.reject = t.none
    t.tru = t.all
    t.fls = t.none

    function t.value(predOrValue)
        if type(predOrValue) == 'function' then
            return t.valuePredicate(predOrValue)
        else
            return t.valueVal(predOrValue)
        end
    end

    function t.valueVal(value)
        return datatypes.Predicate(
            function(node, _, _, _)
                return not traverser.isNode(node) and node == value
        end)
    end

    function t.valuePredicate(plainPred)
        return datatypes.Predicate(
            function(node, _, _, _)
                if not traverser.isNode(node) then
                    return plainPred(node)
                else
                    return false
                end
        end)
    end

    function t.isExp()
        return datatypes.Predicate(
            function(node, _, _, _)
                return traverser.isNode(node) and util.isExpNode(node)
        end)
    end

    function t.isStmt()
        return datatypes.Predicate(
            function(node, _, _, _)
                if not traverser.isNode(node) then return false end
                if node.tag == 'Call' then return false
                else return util.isStmtNode(node) end
        end)
    end

    function t.isBlock()
        return datatypes.Predicate(
            function(node, _, _, _)
                return traverser.isNode(node) and util.isBlockNode(node)
        end)
    end

    function t.isLiteral()
        return datatypes.Predicate(
            function(node, _, _, _)
                return traverser.isNode(node) and util.isConstantNode()
        end)
    end

    function t.isTerminal()
        return t.hasChilds(0)
    end

    function t.isNthSibling(n)
        return datatypes.Predicate(
            function(node, _, siblingNumberStack, _)
                return traverser.isNode(node) and siblingNumberStack:top() == n
        end)
    end

    -- nodes are always tables
    function t.hasChilds(childCount)
        return datatypes.Predicate(
            function(node, _, _, _)
                return
                    traverser.isNode(node)
                    and childCount == #util.ifilter(
                        node, util.predicates.isTable)
        end)
    end

    function t.hasValue(value)
        return datatypes.Predicate(
            function(node, parentStack, sibNumStack, scopeStack)
                return
                    traverser.isNode(node)
                    and t.hasChilds(0)(
                        node, parentStack,
                        sibNumStack, scopeStack)
                    and node[1] == value
            end)
    end

    -- debug combinator
    function t.debug()
        return datatypes.Predicate(
            function(node, parentStack, sibNumStack, scopeStack)
                require'debugger'()
                return true
            end)
    end

    -- sibling combinators
    function t.nthSibling(n, predicate)
        return datatypes.Predicate(
            function(_, parentStack, _, _)
                local immediateParent, siblingsNode = parentStack:top(), nil
                if immediateParent then
                    siblingsNode = immediateParent[n]
                end
--                local a, b, c, d =
 --                   traverser.seekTraverserState(t._ast, siblingsNode)
  --              require'debugger'()
                return predicate(
                    traverser.seekTraverserState(t._ast, siblingsNode))
        end)
    end

    -- shortcuts
    t.fstSibling = util.bind(1, t.nthSibling)
    t.sndSibling = util.bind(2, t.nthSibling)
    t.trdSibling = util.bind(3, t.nthSibling)
    t.forthSibling = util.bind(4, t.nthSibling)
    t.fifthSibling = util.bind(5, t.nthSibling)

    function t.forallLeftSiblings(predicate)
        return datatypes.Predicate(
            function(node, parentStack, siblingNumStack, scopeStack)
                local currentSiblingNum = siblingNumStack:top()
                return t.forallSiblingsBetween(
                    1, currentSiblingNum - 1, predicate)(
                    node, parentStack, siblingNumStack, scopeStack)
        end)
    end

    function t.forallSiblingsBetween(from, to, predicate)
        return datatypes.Predicate(
            function(node, parentStack, siblingNumStack, scopeStack)
                assert(from >= 1, 'Invalid lower bound')
                local result = true
                for i = from, to do
                    result = result and t.nthSibling(
                        i, predicate)(
                        node, parentStack, siblingNumStack, scopeStack)
                end
                return result
        end)
    end

    function t.existsSiblingsBetween(from, to, predicate)
        return datatypes.Predicate(
            function(node, parentStack, siblingNumStack, scopeStack)
                assert(from >= 1, 'Invalid lower bound: ' .. from)
                local result = false
                for i = from, to do
                    result = result or t.nthSibling(
                        i, predicate)(
                        node, parentStack, siblingNumStack, scopeStack)
                end
                return result
        end)
    end

    function t.forallRightSiblings(predicate)
        return datatypes.Predicate(
            function(node, parentStack, siblingNumStack, scopeStack)
                local currentSiblingNum = siblingNumStack:top()
                local maxSiblingNum = #parentStack:top()
                return t.forallSiblingsBetween(
                    currentSiblingNum + 1, maxSiblingNum, predicate)(
                    node, parentStack, siblingNumStack, scopeStack)
        end)
    end

    function t.previousSibling(predicate)
        return datatypes.Predicate(
            function(node, parentStack, siblingNumStack, scopeStack)
                local currentSiblingNum = siblingNumStack:top()
                return t.existsSiblingsBetween(
                    predicate, 1, currentSiblingNum - 1)(
                    node, parentStack, siblingNumStack, scopeStack)
        end)
    end

    function t.nextSibling(predicate)
        return datatypes.Predicate(
            function(node, parentStack, siblingNumStack, scopeStack)
                local currentSiblingNum = siblingNumStack:top()
                local max = #(parentStack:top())
                return t.existsSiblingsBetween(
                    predicate, currentSiblingNum + 1, max)(
                    node, parentStack, siblingNumStack, scopeStack)
        end)
    end

    ----
    -- child combinators
    -- [1] since we assume 'predicate' to handle nodes that are
    -- nil correctly, we can just call it
    function t.nthChild(n, predicate)
        return datatypes.Predicate(
            function(node, _, _, _)
                local seekNode
                if traverser.isNode(node) then
                    seekNode = node[n]
                else
                    seekNode = nil
                end
                return predicate(traverser.seekTraverserState(t._ast, seekNode))
        end)
    end

    t.fstChild = util.bind(1, t.nthChild)
    t.sndChild = util.bind(2, t.nthChild)
    t.thdChild = util.bind(3, t.nthChild)

    -- if you want to query for print(x + y)
    -- local ast = +{ print(x+y) }
    -- local Q = astQuery.treeQuery
    -- Q(ast)
    --   :filter 'Call'
    --   :where(
    --     t.firstChilds(
    --       t.tag'Id',
    --       t.tag'Op' & t.firstChildsSatisfy(
    --         t.value'add', t.tag'Id', t.tag'Id')))
    function t.firstChilds(...)
        local predicates = table.pack(...)
        return datatypes.Predicate(
            function(node, parentStk, siblingNumStk, scopeStack)
                local result = true
                for i = 1, #predicates do
                    result = result and
                        t.nthChild(i, predicates[i])(
                            node, parentStk, siblingNumStk, scopeStack)
                end
                return result
        end)
    end

    -- helper function used by forall childs
    function t.foldChilds(operation, startvalue, predicate)
        return datatypes.Predicate(
            function(node, parentStack, siblingStack, scopeStack)
                local result = true
                local function terminator(_, _, _, _)
                    return result == startvalue end
                local function preFunc(n, parStk, sibStk, scopeStk)
                    result = operation(
                        result, predicate(n, parStk, sibStk, scopeStk))
                end
                if parentStack ~= nil then
                    parentStack = parentStack:deepCopy()
                end
                if siblingStack ~= nil then
                    siblingStack = siblingStack:deepCopy()
                end
                if scopeStack ~= nil then
                    scopeStack = scopeStack:deepCopy()
                end
                traverser.traverseScoped(
                    node, preFunc, util.identity,
                    util.bind(true, util.identity), terminator,
                    parentStack, siblingStack, scopeStack)
                return result
            end)
    end

    t.forallChilds = util.binder(t.foldChilds, {util.operator.logAnd, false})
    t.existsChilds = util.binder(t.foldChilds, {util.operator.logOr, true})

    ----
    -- parent combinators
    -- if there is no nth parent => false
    function t.nthParent(n, predicate)
        return datatypes.Predicate(
            function(_, parentStack, _, _)
                local parentsNode = parentStack:getNthTop(n)
                return predicate(
                    traverser.seekTraverserState(t._ast, parentsNode))
        end)
    end

    t.parent = util.bind(1, t.nthParent)
    t.grandParent = util.bind(2, t.nthParent)
    t.greatGrandParent = util.bind(3, t.nthParent)

    -- not intended to use publicly, use forallParents or oneOfParents!
    function t.foldParents(operation, startValue, predicate)
        return datatypes.Predicate(
            function(node, parentStack, siblingNumberStack, scopeStack)
                -- TODO: is this conventionally OK to just return false
                -- in case of the root node?
                local numOfParents = parentStack:getn()
                if numOfParents == 0 then return false end
                return util.ifold(
                    util.imap(
                        util.iota(numOfParents),
                        function(num)
                            return t.nthParent(num, predicate)(
                                node, parentStack,
                                siblingNumberStack, scopeStack)
                    end),
                    operation,
                    startValue)
        end)
    end

    -- forall x in parentStack: predicate(x)
    t.forallParents = util.bind(
        true, util.bind(util.operator.logAnd, t.foldParents))

    -- exists x in parentStack: predicate(x)
    t.oneOfParents = util.bind(
        false, util.bind(util.operator.logOr, t.foldParents))

    -- ifelse(ps(n), pT(n), pF(n)) ==
    -- if ps(n) then return pT(n) else return pF(n)
    -- Can be thought about as boolean multiplexer
    -- mux(ps(n), pF(n), pT(n)); Muxer semantics are
    -- if ps(n) == false => pF(n)
    function t.ifelse(selector, predTrue, predFalse)
        return (predTrue & selector) | (predFalse & (~selector))
        -- alternatively:
        -- return predTrue:land(selector):lor(predFalse:land(selector:negate()))
    end

    -- First matches the subtree at 'node' against setPredicate
    -- and puts each of the resutlting nodes into the predicate
    -- generator. The resulting predicates will be folded using
    -- the and operation and start value true
    function t.forall(setPredicate, predicateGenerator)
        return datatypes.Predicate(
            function(node, parentStack, siblingNumberStack, scopeStack)
                local Q = astQuery.astQuery
                local args = {node, parentStack, siblingNumberStack, scopeStack}
                local predicates =
                    util.imap(
                        Q(t._ast):starting(node):where(setPredicate):list(),
                        predicateGenerator)
                local saturatedPredicates =
                    util.imap(
                        predicates,
                        util.bind(args, util.flip(util.binder)))
                return
                    util.ifold(
                        util.imap( -- evaluated predicates
                            saturatedPredicates,
                            util.call),
                        util.operator.logAnd,
                        true)
            end)
    end

    -- scope predicates
    function t.occurrenceOf(binder)

    end

    -- AST structure related short cuts
    function t.number(predicate)
        return t.tag'Number' & t.fstChild(predicate)
    end

    return t
end

-- declarative tree query EDSL
-- tailored to our AST format
function astQuery.astQueryObj(astRoot, startingNode, combinators)
    assert(astRoot and startingNode, 'no valid ast or starting given')
    local t = {}
    t._astRoot = astRoot
    t._startingNode = startingNode
    t._predicate = datatypes.Predicate(util.bind(true, util.identity))
    t._listMonad = nil

    -- getter
    function t:astRoot() return self._astRoot end
    function t:combinators() return self._combinators end
    function t:startingNode() return self._startingNode end
    function t:predicate() return self._predicate end
    function t:resultList() return self._listMonad end
    -- setter
    function t:setPredicate(pred) self._predicate = pred; return self end
    function t:setStartingNode(node) self._startingNode = node; return self end
    function t:setResultList(list)
        self._listMonad = datatypes.listMonad(list)
        return self
    end

    function t:filter(tag)
        assert(type(tag) == 'string', 'Not string!')
        return astQuery.astQueryObj(
            self:astRoot(), self:startingNode(), self:combinators())
            :setPredicate(
                datatypes.Predicate(
                    util.predForall(self:predicate(), combinators.tag(tag))))
    end

    function t:where(predicate)
        return astQuery.astQueryObj(
            self:astRoot(), self:startingNode(), self:combinators())
            :setPredicate(
                datatypes.Predicate(
                    util.predForall(self:predicate(), predicate)))
    end

    function t:list()
        local result = {}
        local accumulate = function(e)
            result[#result + 1] = e
        end
        local _, parentStack, siblingStack, scopeStack =
            traverser.seekTraverserState(self:astRoot(), self:startingNode())
        traverser.traverseScoped(
            self:startingNode(), accumulate, util.identity,
            self:predicate():unpack(), util.bind(false, util.identity),
            parentStack, siblingStack, scopeStack)
        return result
    end

    function t:iterator()
        return datatypes.listMonad(self:list()):iterator()
    end

    function t:select(func)
        return datatypes.listMonad(self:list()):select(func)
    end

    function t:foreach(func)
        return datatypes.listMonad(self:list()):foreach(func)
    end

    function t:selectMany(func)
        return datatypes.listMonad(self:list()):selectMany(func)
    end

    function t:aggregate(operation, acc)
        return datatypes.listMonad(self:list()):aggregate(operation, acc)
    end

    function t:map(_) --TODO:
        return self end

    function t:mapRemap(_)
        --TODO:
        return self
    end

    return t
end


return astQuery
