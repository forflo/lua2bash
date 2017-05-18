local aB = require("lua2bash-ast-builder")
local Q = require("lua2bash-ast-query").treeQuery
local util = require("lua2bash-util")
local ser = require("lua2bash-serialize-ast")
local parser = require("lua-parser.parser")
local pp = require'lua-parser.pp'
local treeQuery = require('lua2bash-ast-query').treeQuery

local testCode = [[
do
    local x =
        (function(x)
                local x = x
                return x + 1
         end)(41)

    do
        local y = x
        local f = y
    end

    do
        f = function(x)
            if x == nil then
                return x + 1
            elseif x == 3 then
                return x + 3
            else
                print(x+y)
                g = function(m)
                    againNest = function(f) return f end
                    return m
                end
                return g(x)
            end
        end

        print(1+2)
        print(a+b)
        print(3*4)
        print(5+3)
        print(4)
    end
end
    ]]

describe(
    "Ast Query test",
    function()
        randomize(true)

        it("tests isTerminal predicate",
           function()
               local amount, lower, upper = 20, 1, 1000
               local terminals = { }
               local ast = nil
               for i = 1, amount do
                   local assignment
                   terminals[i] = aB.numberLit(math.random(lower, upper))
                   assignment =
                       aB.localAssignment(
                           aB.nameList(aB.id'x'),
                           aB.expList(terminals[i]))
                   ast = aB.doStmt(
                       aB.whileLoop(
                           aB.trueLit(),
                           aB.block(
                               assignment,
                               aB.breakStmt())),
                       assignment,
                       ast)
               end
               ast = aB.block(ast)
               -- print(require'ml'.tstring(ast))
               -- local serializedAst = ser(ast)
               -- print(serializedAst)

               local count1, count2, count3 = 0, 0, 0
               local tQ = Q(ast)

               local query = tQ
                   :filter('While')
                   :where(tQ.isValidNode() & tQ.nthChild(1, tQ.isExp()))
               -- This demonstrates the three different ways to
               -- count how often we had a match
               query:foreach(function() count1 = count1 + 1 end)
               for _ in query:iterator() do count2 = count2 + 1 end
               count3 = #(query:list())
               assert.True(count1 == amount)
               assert.are.same(count1, count2, count3)
               print(count1, count2, count3)

               assert.True(
                   #tQ
                       :filter('While')
                       :where(tQ.nthChild(1, tQ.isStmt()))
                       :list() == 0)

               assert.True(#(tQ
                       :filter('While')
                       :where(tQ.nthChild(1, tQ.isExp()))
                       :where(tQ.nthChild(2, tQ.isStmt()))
                           :list()) == 0)

               assert.True(
                   #(tQ
                         :filter('While')
                         :where(tQ.nthChild(1, tQ.isExp()))
                         :where(
                             tQ.nthChild(
                                 2, tQ.nthChild(1, tQ.hasTag'Forin')))
                         :list()) == 0)

               assert.True(
                   #(tQ
                         :filter('While')
                         :where(tQ.nthChild(1, tQ.isExp()))
                         :where(
                             tQ.nthChild(
                                 2, tQ.nthChild(1, tQ.hasTag'Local')))
                         :list()) == amount)

               assert.True(
                   #(tQ
                         :filter 'While'
                         :where(
                             tQ.fstChild(tQ.isExp()) &
                             tQ.sndChild(tQ.fstChild(tQ.hasTag'Local')))
                         :list()) == amount)

               assert.True(
                   #(tQ
                         :filter 'While'
                         :where(
                             tQ.firstChilds(
                                 tQ.isExp(),
                                 tQ.fstChild(tQ.hasTag'Local')))
                         :list()) == amount)

               -- tests for all nodes that do not have a
               -- fourth and fifth sibling

               -- syntax tree: { `Local{ { `Id "a", `Id "b", `Id "c",
               --   `Id "d", `Id "e" }, { `Number "1" } } }
               local ast, _ =
                   parser.parse([[local a, b, c, d, e = 1;]])

               Q = treeQuery(ast)
               local nodeCount =
                   #Q
                   :where(
                       Q.isValidNode()
                           & Q.forthSibling(~ Q.isValidNode())
                           & Q.fifthSibling(~ Q.isValidNode()))
                   :list()

               assert.True(nodeCount == 5)

               local tcAst, _ = parser.parse(testCode)

               Q = treeQuery(tcAst)
               local prints =
                   Q
                   : filter 'Call'
                   : where(
                       Q.firstChilds(
                           Q.hasTag'Id',
                           Q.hasTag'Op' & Q.firstChilds(
                               Q.hasTag'Id',
                               Q.hasTag'Id'))):list()
               print(pp.dump(tcAst))
               print(#prints)
               for k, v in ipairs(prints) do
                   print(ser(v))
               end
        end)
end)
