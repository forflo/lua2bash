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

-- declarative tree query EDSL
-- tailored to our AST format
function astQuery.treeQuery(ast, boxedPred)
    assert(ast, 'no valid ast given')
    local t = {}
    t._ast = ast
    t._predicate = boxedPred or
        datatypes.Predicate(util.bind(true, util.identity))

    function t:ast() return self._ast end
    function t:predicate() return self._predicate end

    function t:filter(tag)
        assert(type(tag) == 'string', 'Not string!')
        return astQuery.treeQuery(
            self:ast(),
            datatypes.Predicate(
                util.predForall(self:predicate(), t.hasTag(tag))))
    end

    function t:where(predicate)
        return astQuery.treeQuery(
            self:ast(),
            datatypes.Predicate(
                util.predForall(self:predicate(), predicate)))
    end

    function t:list()
        local result = {}
        local accumulate = function(e)
            result[#result + 1] = e
        end
        traverser.traverseScoped(
            self._ast, accumulate,
            util.identity, self:predicate():unpack())
        return result
    end

    -- so you can write
    -- for i in Q(ast) :where('Call') :iterator() do
    -- end
    function t:iterator()
        return util.iter(self:list())
    end

    function t:foreach(func)
        traverser.traverseScoped(
            self._ast, func, util.identity,
            self:predicate():unpack())
    end


    function t:map(func)
        --TODO:

        return self
    end

    function t:mapRemap(func)
        --TODO:

        return self
    end

    -- predicates, predicate generators and predicate combinators
    function t.hasTag(tag)
        assert(type(tag) == 'string', 'Wrong argument type')
        return datatypes.Predicate(
            function(node, _, _, _)
                return node ~= nil and node.tag == tag
        end)
    end

    function t.isExp()
        return datatypes.Predicate(
            function(node, _, _, _)
                return node ~= nil and util.isExpNode(node)
        end)
    end

    function t.isStmt()
        return datatypes.Predicate(
            function(node, _, _, _)
                if node == nil then return false end
                if node.tag == 'Call' then return false
                else return util.isStmtNode(node) end
        end)
    end

    function t.isBlock()
        return datatypes.Predicate(
            function(node, _, _, _)
                return node ~= nil and util.isBlockNode(node)
        end)
    end

    function t.isLiteral()
        return datatypes.Predicate(
            function(node, _, _, _)
                return node ~= nil and util.isConstantNode()
        end)
    end

    function t.isTerminal()
        return t.hasChilds(0)
    end

    function t.isValidNode()
        return function(node, _, _, _)
            return node ~= nil and node.tag ~= nil
        end
    end

    function t.isNthSibling(n)
        return datatypes.Predicate(
            function(node, _, siblingNumberStack, _)
                return node ~= nil and siblingNumberStack:top() == n
        end)
    end

    -- nodes are always tables
    function t.hasChilds(childCount)
        return datatypes.Predicate(
            function(node, _, _, _)
                return
                    node ~= nil
                    and childCount == #util.ifilter(
                        node, util.predicates.isTable)
        end)
    end

    function t.hasValue(value)
        return datatypes.Predicate(
            function(node, parentStack, sibNumStack, scopeStack)
                return
                    node ~= nil
                    and t.hasChilds(0)(
                        node, parentStack,
                        sibNumStack, scopeStack)
                    and node[1] == value
            end)
    end

    -- sibling combinators
    function t.nthSibling(n, predicate)
        return datatypes.Predicate(
            function(_, parentStack, siblingNumStack, _)
                if parentStack:top()[n] == nil then
                    return predicate(nil, parentStack, nil, nil)
                end
                local immediateParent = parentStack:top()
                local siblingsNode = immediateParent[n]
                local siblingsNumStack = siblingNumStack:copyPop()
                local siblingsScopeStack =
                    traverser.seekTraverserState(t._ast, siblingsNode)
                return predicate(
                    siblingsNode, parentStack,
                    siblingsNumStack:push(n), siblingsScopeStack)
        end)
    end
    -- shortcuts
    t.fstSibling = util.bind(1, t.nthSibling)
    t.sndSibling = util.bind(2, t.nthSibling)
    t.trdSibling = util.bind(3, t.nthSibling)
    t.forthSibling = util.bind(4, t.nthSibling)
    t.fifthSibling = util.bind(4, t.nthSibling)

    function t.allLeftSiblings(predicate)
        return datatypes.Predicate(
            function(node, parentStack, siblingNumStack, scopeStack)
                local currentSiblingNum = siblingNumStack:top()
                return t.forallSiblingsBetween(
                    predicate, 1, currentSiblingNum - 1)(
                    node, parentStack, siblingNumStack, scopeStack)
        end)
    end

    function t.forallSiblingsBetween(predicate, from, to)
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

    function t.existsSiblingsBetween(predicate, from, to)
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

    function t.allRightSiblings(predicate)
        return datatypes.Predicate(
            function(node, parentStack, siblingNumStack, scopeStack)
                local currentSiblingNum = siblingNumStack:top()
                local maxSiblingNum = #parentStack:top()
                return t.forallSiblingsBetween(
                    predicate, currentSiblingNum + 1, maxSiblingNum)(
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
                return predicate(traverser.seekTraverserState(t._ast, node[n]))
        end)
    end

    -- if you want to query for print(x + y)
    -- local ast = +{print(x+y)}
    -- local Q = astQuery.treeQuery
    -- Q(ast)
    --   :filter 'Call'
    --   :filter(
    --     t.firstChildsSatisfy(
    --       t.hasTag'Id',
    --       t.hasTag'Op' and t.firstChildsSatisfy(
    --         t.has_value'add', t.hasTag'Id', t.hasTag'Id')))
    function t.firstChilds(...)
        local predicates = table.pack(...)
        return datatypes.Predicate(
            function(node, parentStk, siblingNumStk, scopeStack)
                local result = true
                for i in 1, #predicates do
                    result = result and
                        t.nthChild(i, predicates[i])(
                            node, parentStk, siblingNumStk, scopeStack)
                end
                return result
        end)
    end

    ----
    -- parent combinators
    -- if there is no nth parent => false
    function t.nthParent(n, predicate)
        return datatypes.Predicate(
            function(_, parentStack, _, _)
                local parentsNode = parentStack:getNth(n)
                return predicate(
                    traverser.seekTraverserState(t._ast, parentsNode))
        end)
    end

    t.parent = util.bind(1, t.nthParent)
    t.grandParent = util.bind(2, t.nthParent)
    t.greatGrandParent = util.bind(3, t.nthParent)

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

    return t
end

return astQuery
