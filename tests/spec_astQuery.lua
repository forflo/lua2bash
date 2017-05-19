local aB = require("lua2bash-ast-builder")
local Q = require("lua2bash-ast-query").treeQuery
local util = require("lua2bash-util")
local ser = require("lua2bash-serialize-ast")
local parser = require("lua-parser.parser")
local pp = require'lua-parser.pp'
local astQuery = require('lua2bash-ast-query').astQuery

local testCode = [[
do
    do local y = x local f = y end -- some dummy code
    do
        f = function(x)
            if x == nil then return x + 1
            elseif x == 3 then return x + 3
            else
                print(x+y)
                g = function(m)
                    print(please+dontfindme)
                    print(6 + 6)
                end
            end
        end
        print(1+2) print(a+b)
        print(8*4) print(a*z)
        print(5+3) print(5*a)
    end
end]]

local scopeCode = [[
do
    local x = 3
    do local y = x local f = y end -- some dummy code
    do
        local y = 4
        f = function(x)
            if x == nil then return x + 1
            elseif x == 3 then return x + 3
            else
                print(x+y)
                g = function(m)
                    print(please+dontfindme)
                    print(6 + 6)
                end
            end
        end
        print(1+2) print(a+b)
        print(8*4) print(a*z)
        print(5+3) print(5*a)
    end
end]]

local scopeCodeSimple = [[do local x = 42 end]]

describe(
    "Ast Query test",
    function()
        randomize(true)

        it('tests queries using different starting points',
           function()
               local ast, _ = parser.parse(scopeCode)
               local Q = astQuery(ast)
               local result = ''

               for declaration in Q(ast):filter'Local':iterator() do
                   for id in Q(declaration):where(Q.tag'Id'):iterator() do
                       result = result .. ser(id)
                   end
               end
               assert.are.same(result, 'xyxfyy')
        end)

        it('tests queries using different starting points',
           function()
               local ast, _ = parser.parse(scopeCode)
               local Q = astQuery(ast)

               for declaration in Q(ast):filter'Local':iterator() do
                   for id in Q(declaration)
                       :where(Q.parent(Q.tag'NameList'))
                       :iterator()
                   do
                       local serId = ser(id)
                       for constant in
                           Q(declaration)
                           :where(
                               Q.forallRightSiblings(
                                   (Q.tag'Set' & Q.fstChild(
                                        Q.tag'VarList' & Q.existsChilds(
                                            Q.fstChild(Q.value(serId))))):negate()
                                       & Q.forallChilds(
                                           ~(Q.tag'Set' & Q.fstChild(
                                                Q.tag'VarList' & Q.existsChilds(
                                                    Q.fstChild(Q.value(serId))))))))
                           :iterator()
                       do
                           print(constant)
                       end
                   end
               end
        end)

--        it("tests isTerminal predicate",
--           function()
--               local amount, lower, upper = 20, 1, 1000
--               local terminals = { }
--               local ast = nil
--               for i = 1, amount do
--                   local assignment
--                   terminals[i] = aB.numberLit(math.random(lower, upper))
--                   assignment =
--                       aB.localAssignment(
--                           aB.nameList(aB.id'x'),
--                           aB.expList(terminals[i]))
--                   ast = aB.doStmt(
--                       aB.whileLoop(
--                           aB.trueLit(),
--                           aB.block(
--                               assignment,
--                               aB.breakStmt())),
--                       assignment,
--                       ast)
--               end
--               ast = aB.block(ast)
--               -- print(require'ml'.tstring(ast))
--               -- local serializedAst = ser(ast)
--               -- print(serializedAst)
--
--               local count1, count2, count3 = 0, 0, 0
--               local tQ = Q(ast)
--
--               local query = tQ
--                   :filter('While')
--                   :where(tQ.isValidNode() & tQ.nthChild(1, tQ.isExp()))
--               -- This demonstrates the three different ways to
--               -- count how often we had a match
--               query:foreach(function() count1 = count1 + 1 end)
--               for _ in query:iterator() do count2 = count2 + 1 end
--               count3 = #(query:list())
--               assert.True(count1 == amount)
--               assert.are.same(count1, count2, count3)
--               print(count1, count2, count3)
--
--               assert.True(
--                   #tQ
--                       :filter('While')
--                       :where(tQ.nthChild(1, tQ.isStmt()))
--                       :list() == 0)
--
--               assert.True(#(tQ
--                       :filter('While')
--                       :where(tQ.nthChild(1, tQ.isExp()))
--                       :where(tQ.nthChild(2, tQ.isStmt()))
--                           :list()) == 0)
--
--               assert.True(
--                   #(tQ
--                         :filter('While')
--                         :where(tQ.nthChild(1, tQ.isExp()))
--                         :where(
--                             tQ.nthChild(
--                                 2, tQ.nthChild(1, tQ.tag'Forin')))
--                         :list()) == 0)
--
--               assert.True(
--                   #(tQ
--                         :filter('While')
--                         :where(tQ.nthChild(1, tQ.isExp()))
--                         :where(
--                             tQ.nthChild(
--                                 2, tQ.nthChild(1, tQ.tag'Local')))
--                         :list()) == amount)
--
--               assert.True(
--                   #(tQ
--                         :filter 'While'
--                         :where(
--                             tQ.fstChild(tQ.isExp()) &
--                             tQ.sndChild(tQ.fstChild(tQ.tag'Local')))
--                         :list()) == amount)
--
--               assert.True(
--                   #(tQ
--                         :filter 'While'
--                         :where(
--                             tQ.firstChilds(
--                                 tQ.isExp(),
--                                 tQ.fstChild(tQ.tag'Local')))
--                         :list()) == amount)
--
--               -- tests for all nodes that do not have a
--               -- fourth and fifth sibling
--
--               -- syntax tree: { `Local{ { `Id "a", `Id "b", `Id "c",
--               --   `Id "d", `Id "e" }, { `Number "1" } } }
--               local ast, _ =
--                   parser.parse([[local a, b, c, d, e = 1;]])
--
--               Q = treeQuery(ast)
--               local nodeCount =
--                   #Q
--                   :where(
--                       Q.isValidNode()
--                           & Q.forthSibling(~ Q.isValidNode())
--                           & Q.fifthSibling(~ Q.isValidNode()))
--                   :list()
--
--               assert.True(nodeCount == 5)
--
--               local AST, _ = parser.parse(testCode)
--               local even = function(value) return value % 2 == 0 end
--               Q = treeQuery(AST)
--               Q
--                   :filter 'Call'
--                   :where(
--                       Q.firstChilds(
--                           Q.tag'Id',
--                           Q.tag'Op' & Q.firstChilds(
--                               Q.value('add') | Q.value('mul'),
--                               Q.tag'Id' |
--                                   Q.number(Q.value(even)) |
--                                   Q.number(Q.value(5)),
--                               Q.tag'Id' |
--                                   Q.number(Q.value(even)))))
--                   :where(Q.parent(Q.isBlock()))
--                   :where(~Q.grandParent(Q.tag'Function'))
--                   :foreach(util.composeV(print, ser))
--        end)
end)
