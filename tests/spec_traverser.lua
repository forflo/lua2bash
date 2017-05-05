local astQuery = require("lua2bash-astQuery")
local parser = require("lua-parser.parser")
--local dbg = require("debugger")
local util = require("lua2bash-util")
local decorator = require("lua2bash-decorateAst")
local traverser = require("lua2bash-traverser")
local datastructs = require("lua2bash-datatypes")

describe(
    "traverser test",
    function()
        randomize(true)

        -- TODO: transfer into spec_util
        it("tests whether deep copy works",
           function()
               local t1 = {1, {2, 3, {4, 5, {6, 7}}}}
               local t2 = {a = 1, b = 2, c = { t1 }}
               local t1cpy = util.tableDeepCopy(t1)
               local t2cpy = util.tableDeepCopy(t2)
               assert.are.same(t1, t1cpy)
               assert.are.same(t2, t2cpy)
        end)

        it("tests creation of a simple spaghetti tree",
           function()
               local scopes =
               [[do
                   local a = 1;
                   do
                     local b = a;
                   end;
                   do
                     local c = a;
                     a = a + 1;
                     print(1 * 3) end; end]]
               local ast, _ = parser.parse(scopes)
               local counter, scopeTrees = 0, {}
               assert.Truthy(ast)
               traverser.traverse(
                   ast,
                   function(block, _)
                       local scopeTree =
                           traverser.traverseBottomUp(
                               block,
                               function(_, bottomResults)
                                   return { table.unpack(bottomResults) }
                               end,
                               util.isBlockNode)
                       counter = counter + 1 -- just for assertion
                       scopeTrees[#scopeTrees + 1] =
                           require'ml'.tstring(scopeTree)
                       block.scopeTree = scopeTree
                   end,
                   util.isBlockNode,
                   true)
               assert.Truthy(ast)
               assert.True(counter == 4)
               assert.are.same(
                   util.join(scopeTrees, ''),
                   "{{{},{}}}{{},{}}{}{}")
        end)

        -- TODO: tranver into spec_astQuery
        it("tests whether ast path works",
           function()
               local code =
               [[do
                   local a=1;
                   do
                       print(1 * 3)
                   end; end]]
               local ast, _ = parser.parse(code)
               assert.Truthy(ast)

               local visitor = function(node, parentStack)
                   assert.Truthy(node)
                   assert.Truthy(parentStack)
                   assert.True(parentStack:getn() > 0)
                   local path = astQuery.AstPath():initByStack(parentStack)
                   local walk = astQuery.AstWalk(ast)
                   assert.Truthy(path)
                   assert.True(path:depth() == 4)
                   assert.are.same(path:goTop():Node(), walk:Node())
                   assert.are.same(path:goDown():Node(), walk:Statement(1):Node())
                   assert.are.same(path:goDown():Node(), walk:Statement(2):Node())
               end
               traverser.traverse(
                   ast, visitor, traverser.nodePredicate('Op'), false)
        end)

        it("tests the normal top down traverser",
           function()
               -- smoke test
               local code =
               [[do
                   local a=1;
                   do
                       print(a + 1)
                   end; end]]
               local ast, _ = parser.parse(code)
               assert.Truthy(ast)

               local visitor = function(callNode, parentStack)
                   assert.Truthy(callNode)
                   assert.Truthy(parentStack)
                   assert.True(parentStack:getn() > 0)
                   local walk = astQuery.AstWalk(ast)
                   util.zipIteratorWith(
                       parentStack:genericIIterator():IIterator(),
                       assert.are.same,
                       datastructs.Stack()
                           :push(walk:Node())
                           -- implicit block surrounding the AST
                           :push(walk:Statement(1):Node())
                           :push(walk:Statement(2):Node())
                           :push(walk:Statement(1):Node())
                           :genericIIterator()
                           :IIterator())
               end
               traverser.traverse(
                   ast, visitor, traverser.nodePredicate('Op'), false)
        end)

        it("tests the bottom up traverser",
           function()
               -- smoke test
               local code =
               [[do local a=1; do print(a) end; do print(a+1) end end]]
               local ast, _ = parser.parse(code)
               assert.Truthy(ast)
               local visitor = function(node, bottomResult)
                   return node.tag .. '{' .. bottomResult .. '}'
               end
               local joinFunc = util.bind('', util.flip(util.join))
               local result = traverser.traverseBottomUp(
                   ast, visitor, function() return true end, joinFunc)
               assert.Truthy(result)
               assert.are.same(
                   [[Block{Do{Local{NameList{Id{a}}ExpList{Number{1}}}Do{Call]]
                       .. [[{Id{print}Id{a}}}Do{Call{Id{print}Op{addId{]]
                       .. [[a}Number{1}}}}}}]],
                   result)

               -- implement deep table copy
               local nestedOrig = {1, {2, {3, {4, {5, {6, {7, 8, 9}}}}}}}
               local copier = function(_, bottomResult)
                   return bottomResult
               end
               local nestedCopy = traverser.traverseBottomUp(
                   nestedOrig, copier, util.bind(true, util.identity))
               assert.are.same(nestedOrig, nestedCopy)
        end)
end)
