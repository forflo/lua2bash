local sC = require("lua2bash-staticChecker")
local s = require("lua2bash-serialize-ast")
local parser = require("lua-parser.parser")
local pp = require("lua-parser.pp")
local aQ = require("lua2bash-astQuery")

local testcode = {
    "local a = - (1 + 2 * 3 - 4 % 2) < 4",
    "local a = 'foo' .. 'bar' .. 2 == 'foobar2' ~= 'baz'",
    "local a = #('foo' .. (3 // 4 / 5 * 6))",
    "local a = ({1,2,3,4})[1] << 11 >> 10"
}

describe(
    "static checker test",
    function()
        randomize(true)

        it("tests simple expressions",
           function()
               for _, code in pairs(testcode) do
                   local ast, _ = parser.parse(code)
                   assert.Truthy(ast)
                   local walk = aQ.AstWalk(ast)
                   print(s.serialize(ast))
                   print(pp.dump(ast))
                   local exp = walk:Statement(1):ExpList():Expression(1):Node()
                   --assert.True(sC.isStaticExp(exp))
               end
        end)
end)
