local sC = require("lua2bash-staticChecker")
local parser = require("lua-parser.parser")
local aQ = require("lua2bash-astQuery")
local f = require("lua2bash-opt-constantFolding")
local d = require("lua2bash-decorateAst")

local statements =
"local a = - (1 + 2 * 3 - 4 % 2) < 4;" ..
"local a = 'foo' .. 'bar' .. 2 == 'foobar2' ~= 'baz';" ..
"local a = #('foo' .. (3 // 4 / 5 * 6));"..
"local a = ({1,2,3,4})[1] << 11 >> 10;"..
"local a = - (1 + NOPE * 3 - 4 % 2) < 4;"..
"local a = 'foo' .. 'bar' .. NOPE == 'foobar2' ~= 'baz';"..
"local a = #('foo' .. (3 // 4 / NOPE * 6));"..
"local a = ({1,2,3,4})[1] << NOPE >> 10;"

local loop = [[
    for i = -1 + 2, 10 + 32 + 42 do
        print(4 - 2 // 2)
    end
]]

describe(
    "constant folding test",
    function()
        randomize(false)

        it("tests constant folding inside loops",
           function()
               local ast, _ = parser.parse(loop)
               assert.Truthy(ast)
               local decorated = d.decorate(ast)
               assert.Truthy(decorated)
               local folded = f.foldConst(decorated)
               assert.Truthy(folded)

        end)

        it("tests simple statement list AST ",
           function()
               local ast, _ = parser.parse(statements)
               local statementsResults = {
                   { tag = "True", pos = -1 },
                   { tag = "True", pos = -1 },
                   { tag = "Number", pos = -1, [1] = 6 },
                   { tag = "Number", pos = -1, [1] = 2 },
               }
               assert.Truthy(ast)
               local decorated = d.decorate(ast)
               assert.Truthy(decorated)
               local folded = f.foldConst(decorated)
               assert.Truthy(folded)
               for i = 1, #statementsResults do
                   assert.are.same(
                       statementsResults[i],
                       aQ.AstWalk(folded)
                           :Statement(i)
                           :ExpList()
                           :Expression(1):Node())
               end
        end)
end)
