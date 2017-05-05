local util = require("lua2bash-util")
local datastructs = require("lua2bash-datatypes")

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

return astQuery
