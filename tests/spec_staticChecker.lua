local sC = require("lua2bash-staticChecker")
local parser = require("lua-parser.parser")
local aQ = require("lua2bash-astQuery")

local testcode = {
    { "local a = - (1 + 2 * 3 - 4 % 2) < 4", true},
    { "local a = 'foo' .. 'bar' .. 2 == 'foobar2' ~= 'baz'", true},
    { "local a = #('foo' .. (3 // 4 / 5 * 6))", true },
    { "local a = ({1,2,3,4})[1] << 11 >> 10", true },
    { "local a = - (1 + NOPE * 3 - 4 % 2) < 4", false},
    { "local a = 'foo' .. 'bar' .. NOPE == 'foobar2' ~= 'baz'", false},
    { "local a = #('foo' .. (3 // 4 / NOPE * 6))", false },
    { "local a = ({1,2,3,4})[1] << NOPE >> 10", false },
}

describe(
    "static checker test",
    function()
        randomize(true)

        it("tests simple expressions",
           function()
               for _, tuple in pairs(testcode) do
                   local code, awaitedResult = tuple[1], tuple[2]
                   local ast, _ = parser.parse(code)
                   assert.Truthy(ast)
                   local walk = aQ.AstWalk(ast)
                   local exp = walk:Statement(1):ExpList():Expression(1):Node()
                   assert.are.same(sC.isStaticExp(exp), awaitedResult)
               end
        end)
end)
