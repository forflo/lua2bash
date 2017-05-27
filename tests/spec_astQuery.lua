local aB = require("lua2bash-ast-builder")
local Q = require("lua2bash-ast-query").treeQuery
local util = require("lua2bash-util")
local ser = require("lua2bash-serialize-ast")
local parser = require("lua-parser.parser")
local datatypes = require("lua2bash-datatypes")
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
        x, y, f = 2
        g = function(x)
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
    end
end]]

local scopeCodeSimple = [[do local x = 42 end]]

local forallChildsCode = [[
    do
      print(x)
      print(y+1)
    end
    do
      local x = 1
      local x = 2
    end
]]

describe(
    "Ast Query test",
    function()
        randomize(true)

        it("tests queries using the forallchilds predicate",
           function()
               local ast, _ = parser.parse(forallChildsCode)
               local Q = astQuery(ast)
               local count1 =
                   #Q(ast):filter'Do':where(Q.forallChilds(Q.all())):list()
               assert.True(count1 == 2)
               local count2 =
                   #Q(ast):filter'Do':where(Q.forallChilds(~Q.tag'Call')):list()
               print(count2)
               assert.True(count2 == 1)
        end)

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

        it("tests the forall qualifier",
           function()
               local ast, _ = parser.parse(scopeCode)
               local Q = astQuery(ast)

               for constant in Q(ast):filter'Local':where(
                   Q.forall(
                       Q.grandParent(Q.tag'NameList'),
                       function(IDSTRING)
                           return Q.forallRightSiblings(
                               Q.ifelse(
                                   Q.tag'Set',
                                   Q.fstChild(
                                       Q.tag'VarList' & Q.forallChilds(
                                           Q.fstChild(~Q.value( IDSTRING )))),
                                   Q.tru())
                               &
                               Q.forallChilds(
                                   Q.ifelse(
                                       Q.tag'Set',
                                       Q.fstChild(
                                           Q.tag'VarList' & Q.forallChilds(
                                               Q.fstChild(~Q.value( IDSTRING )))),
                                       Q.tru()))) end))
               :iterator() do
                   print(ser(constant))
               end
        end)

local idQuery = [[
do
    local x = 3
    do
        local y = x
        local f = y
        local a, b, c = 1, 2, 3
    end -- some dummy code
end]]

local scopeCodeF = [[
do
    local x = 3
    do local y = x local f = y end -- some dummy code
    do
        local y = 4
        x, y, f = 2
        g = function(x)
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
    end
end]]

        it('tests manual forall qualification',
           function()
--               local ast, _ = parser.parse(idQuery)
--               local Q = astQuery(ast)
--               local result
--
--               result = Q(ast)
--                   :filter'Local'
--                   :selectMany(
--                       function(binder)
--                           return Q(binder)
--                               :where(Q.grandParent(Q.tag('NameList')))
--                               :list()
--                              end)
--                   :select(util.bind(1, util.identity))
--                   :aggregate(util.operator.add, 0)
--                   :index(1)
--               assert.True(result == 6)
--
--               result = Q(ast)
--                   :filter'Local'
--                   :selectMany(
--                       function(binder)
--                           return Q(binder)
--                               :where(Q.grandParent(Q.tag('NameList')))
--                               :select(
--                                   function(id)
--                                       return {binder = binder, id = id}
--                                      end)
--                               :list()
--                              end)
--                   :select(util.bind(1, util.identity))
--                   :aggregate(util.operator.add, 0)
--                   :index(1)
--               assert.True(result == 6)

               local ast, _ = parser.parse(scopeCodeF)
               local Q = astQuery(ast)

               result = Q(ast)
                   :filter'Local'
                   :selectMany(
                       function(binder)
                           return
                               Q(binder)
                               :where(Q.grandParent(Q.tag('NameList')))
                               :selectMany(
                                   function(id)
                                       print(id, ser(binder))
                                       return
                                           astQuery(ast)
                                           :starting(binder)
                                           :filter'Local'
                                           :where(
                                               Q.forallRightSiblings(
                                                   Q.ifelse(
                                                       Q.tag'Set',
                                                       Q.fstChild(
                                                           Q.tag'VarList' & Q.forallChilds(
                                                               Q.fstChild(~Q.value( id )))),
                                                       Q.tru())
                                                       &
                                                       Q.forallChilds(
                                                           --Q.debug() &
                                                           Q.ifelse(
                                                               Q.tag'Set',
                                                               Q.fstChild(
                                                                   Q.tag'VarList' & Q.forallChilds(
                                                                       Q.fstChild(~Q.value( id )))),
                                                               Q.tru()))))
                                           :list()
                                          end)
                               :list()
                              end)
                   :foreach(util.composeV(print, ser))
                   :list()
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
