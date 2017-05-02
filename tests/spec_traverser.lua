local bp = require("lua-shepi")
local parser = require("lua-parser.parser")
local dbg = require("debugger")
local util = require("lua2bash-util")
local traverser = require("lua2bash-traverser")

describe(
    "traverser test",
    function()
        randomize(true)

        it("tests the normal top down traverser",
           function()
        end)

        it("tests the bottom up traverser",
           function()
               -- smoke test
               local code =
               [[do local a=1; do print(a) end; do print(a+1) end end]]
               local ast, err = parser.parse(code)
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
