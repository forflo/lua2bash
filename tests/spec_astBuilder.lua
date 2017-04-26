local ab = require("lua2bash-ast-builder")
local ser = require("lua2bash-serialize-ast")

describe(
    "Ast builder test",
    function()
        randomize(true)

        it("tests auxNamelist",
           function()
               assert.are.same(
                   ser.serNamelist(ab.auxNameList("foo", "bar", "foo2")),
                   "foo, bar, foo2")
        end)

        it("tests auxNaryAnd",
           function()
               assert.are.same(
                   ser.serExp(ab.auxNaryAnd(ab.id('foo'), ab.id'bar', ab.id'foo2')),
                   "foo and bar and foo2")
        end)
end)
