local sC = require("lua2bash-staticChecker")
local parser = require("lua-parser.parser")
local aQ = require("lua2bash-astQuery")

local testcode = {
    sE1 = "local a = - (1 + 2 * 3 - 4 % 2) < 4",
    sE2 = "local a = 'foo' .. 'bar' .. 2 == 'foobar2' ~= 'baz'",
    sE3 = "local a = #('foo' .. (3 // 4 / 5 * 6))",
    sE4 = "local a = ({1,2,3,4})[1] << 11 >> 10"
}

describe(
    "static checker test",
    function()
        randomize(true)

        it("tests simple expressions",
           function()
               for _, code in pairs(testcode) do
                   local ast, errMsg = parser.parse(code)
                   assert.Truthy(ast)
                   -- better than ast[1][2][1]
                   local walkTo = aQ.AstWalk(ast)
                   local exp =
                       walkTo:Statement(1):ExpList():Expression(1):unpack()
               end
        end)
end)
