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
function astQuery.treeQuery(ast)
    assert(ast, 'no valid ast given')
    local t = {}
    t._ast = ast
    t._predicate = util.bind(true, util.identity)

    function t:filter(p)
        if type(p) == 'string' then
            self:forAll(self._predicate, t.hasTag(p))
        else
            self:forAll(self._predicate, p)
        end
        return self
    end

    function t:where(p)
        return self:filter(p)
    end

    function t:oneOf(...)
        self._predicate = util.predOneOf(...)
        return self
    end

    function t:forAll(...)
        self._predicate = util.predForall(...)
        return self
    end

    function t.lAnd(...)
        return util.predForall(...)
    end

    function t:list()
        local result = {}
        local accumulate = function(e) result[#result + 1] = e end
        traverser.traverseScoped(
            self._ast, accumulate, util.identity, self._predicate)
        return result
    end

    -- so you can write
    -- for i in Q(ast) :filter('Call') :iterator() do
    -- end
    function t:iterator()
        return util.iter(self:list())
    end

    function t:foreach(func)
        traverser.traverseScoped(
            self._ast, func, util.identity, self._predicate)
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
        return function(node, _, _, _)
            assert(node.tag, 'Node does not have a tag attribute')
            return node.tag == tag
        end
    end

    function t.isExp()
        return function(node, _, _, _)
            assert(node.tag, 'Node does not have a tag attribute')
            return util.isExpNode(node)
        end
    end

    function t.isStmt()
        return function(node, _, _, _)
            assert(node.tag, 'Node does not have a tag attribute')
            if node.tag == 'Call' then return false
            else return util.isStmtNode(node) end
        end
    end

    function t.isBlock()
        return function(node, _, _, _)
            assert(node.tag, 'node does not have a tag attribute')
            return util.isBlockNode(node)
        end
    end

    function t.isLiteral()
        return function(node, _, _, _)
            assert(node.tag, 'node does not have a tag attribute')
            return util.isConstantNode()
        end
    end

    function t.isTerminal()
        return t.hasNChilds(0)
    end

    function t.isNthSibling(nth)
        return function(_, _, siblingNumberStack, _)
            return (siblingNumberStack:top() == nth)
        end
    end

    -- nodes are always tables
    function t.hasNChilds(childCount)
        return function(node, _, _, _)
            return childCount == #util.ifilter(
                node, util.predicates.isTable)
        end
    end

    function t.hasValue(value)
        return function(node, _, _, _)
            return t.hasNChilds(0) and
                node[1] == value
        end
    end

    -- combinators
    function t.parent(predicate)
        return function(_, parentStack, siblingNumberStack)
            local immediateParent = parentStack:top()
            local newParentStack = parentStack:copyPop()
            local newSiblingStack = siblingNumberStack:copyPop()
            return predicate(immediateParent, newParentStack, newSiblingStack)
        end
    end

    function t.nthSibling(n, predicate)
        return function(_, parentStack, siblingNumStack)
            local immediateParent = parentStack:top()
            assert(immediateParent[n], 'Sibling does not exist: '
                       .. immediateParent.tag .. " " .. n)
            local sibling = immediateParent[n]
            local newNumStack = siblingNumStack:copyPop()
            return predicate(sibling, parentStack, newNumStack:push(n))
        end
    end

    function t.forallLeftSibling(predicate)
        return function(node, parentStack, siblingNumStack)
            local currentSiblingNum = siblingNumStack:top()
            return t.forallSiblingsBetween(
                predicate, 1, currentSiblingNum - 1)
            (node, parentStack, siblingNumStack)
        end
    end

    function t.forallSiblingsBetween(predicate, from, to)
        return function(node, parentStack, siblingNumStack)
            assert(from >= 0 and to <= #parentStack:top(),
                   "Invalid boundaries. Sibling count is: " .. #parentStack:top())
            local result = true
            for i = from, to do
                result = result and t.nthSibling(
                    i, predicate)(node, parentStack, siblingNumStack)
            end
            return result
        end
    end

    function t.existsSiblingsBetween(predicate, from, to)
        return function(node, parentStack, siblingNumStack)
            assert(from >= 0 and to <= #parentStack:top(),
                   "Invalid boundaries. Sibling count is: " .. #parentStack:top())
            local result = false
            for i = from, to do
                result = result or t.nthSibling(
                    i, predicate)(node, parentStack, siblingNumStack)
            end
            return result
        end
    end

    function t.forallRightSiblings(predicate)
        return function(node, parentStack, siblingNumStack)
            local currentSiblingNum = siblingNumStack:top()
            local maxSiblingNum = #parentStack:top()
            assert(currentSiblingNum <= maxSiblingNum,
                   'CurrentSiblingNum was bigger than maximum!')
            return t.forallSiblingsBetween(
                predicate, currentSiblingNum + 1, maxSiblingNum)
            (node, parentStack, siblingNumStack)
        end
    end

    function t.holdsForOneLeftSibling(predicate)
        return function(node, parentStack, siblingNumStack)
            local currentSiblingNum = siblingNumStack:top()
            return t.existsSiblingsBetween(predicate, 1, currentSiblingNum - 1)
            (node, parentStack, siblingNumStack)
        end
    end

    function t.holdsForOneRightSibling(predicate)
        return function(node, parentStack, siblingNumStack)
            local currentSiblingNum = siblingNumStack:top()
            local max = #(parentStack:top())
            return t.existsSiblingsBetween(predicate, currentSiblingNum + 1, max)
            (node, parentStack, siblingNumStack)
        end
    end

    -- if there is no nth child in the current node the predicate
    -- will automatically return false
    function t.nthChild(n, predicate)
        return function(node, parentStack, siblingNumberStack, _)
            if node[n] == nil then
                return false
            else
                local newNode, result = node[n], nil
                parentStack:push(node)
                siblingNumberStack:push(n)
                -- here call to actual predicate
                result = predicate(newNode, parentStack, siblingNumberStack, _)
                siblingNumberStack:pop()
                parentStack:pop()
                return result -- TODO: this ok?
            end
        end
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
    function t.firstChildsSatisfy(...)
        local predicates = table.pack(...)
        return function(node, parentStk, siblingNumStk)
            local result = true
            for i in 1, #predicates do
                result = result and
                    t.nthChild(i, predicates[i])(node, parentStk, siblingNumStk)
            end
            return result
        end
    end

    function t.nthParent(n, predicate)
        return function(_, parentStack, siblingNumberStack)
            assert(parentStack:getn(n), 'there is no nth parent: ' .. n)
            local newNode = parentStack:getNth(n)
            local newParentStack = parentStack:copyNPop(n)
            local newSiblingStack = siblingNumberStack:copyNPop(n)
            return predicate(newNode, newParentStack, newSiblingStack)
        end
    end

    -- returns a predicate that is true if and only if
    -- predicate returns true for all parents
    function t.forallParents(predicate)
        return function(node, parentStack, siblingNumberStack)
            util.ifold(
                util.imap(
                    util.iota(parentStack:getn()),
                    function(num)
                        return t.nth_parent(num, predicate)
                        (node, parentStack, siblingNumberStack)
                end),
                util.operator.logAnd,
                true)
        end
    end

    function t.existsParents(predicate)
        return function(node, parentStack, siblingNumberStack)
            util.ifold(
                util.imap(
                    util.iota(parentStack:getn()),
                    function(num)
                        return t.nth_parent(num, predicate)
                        (node, parentStack, siblingNumberStack)
                end),
                util.operator.logOr,
                true)
        end
    end
    return t
end

return astQuery
