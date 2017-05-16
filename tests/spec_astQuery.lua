local aB = require("lua2bash-ast-builder")
local Q = require("lua2bash-ast-query").treeQuery
local util = require("lua2bash-util")
local ser = require("lua2bash-serialize-ast")
local parser = require("lua-parser.parser")

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
                g = function(m)
                    againNest = function(f) return f end
                    return m
                end
                return g(x)
            end
        end

        print(1+2)
        print(3*4)
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
               local amount, lower, upper = 1000, 1, 1000
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
                   :where(tQ.nthChild(1, tQ.isExp()))

               -- This demonstrates the three different ways to
               -- count how often we had a match
               query:foreach(function() count1 = count1 + 1 end)
               for _ in query:iterator() do count2 = count2 + 1 end
               count3 = #(query:list())

               assert.True(count1 == amount)
               assert.are.same(count1, count2, count3)
               print(count1, count2, count3)

               tQ = Q(ast)
               assert.True(
                   #tQ
                       :filter('While')
                       :where(tQ.nthChild(1, tQ.isStmt()))
                       :list() == 0)

               tQ = Q(ast)
               assert.True(#(tQ
                       :filter('While')
                       :where(tQ.nthChild(1, tQ.isExp()))
                       :where(tQ.nthChild(2, tQ.isStmt()))
                           :list()) == 0)

               tQ = Q(ast)
               assert.True(
                   #(tQ
                         :filter('While')
                         :where(tQ.nthChild(1, tQ.isExp()))
                         :where(
                             tQ.nthChild(
                                 2, tQ.nthChild(1, tQ.hasTag'Forin')))
                         :list()) == 0)

               tQ = Q(ast)
               assert.True(
                   #(tQ
                         :filter('While')
                         :where(tQ.nthChild(1, tQ.isExp()))
                         :where(
                             tQ.nthChild(
                                 2, tQ.nthChild(1, tQ.hasTag'Local')))
                         :list()) == 1000)
        end)
end)
