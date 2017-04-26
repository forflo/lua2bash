local ab = require("lua2bash-ast-builder")
local util = require("lua2bash-util")
local ser = require("lua2bash-serialize-ast")
local parser = require("lua-parser.parser")
local elaborater = require("lua2bash-elaborate")

describe(
    "Elaboration tests",
    function()
        randomize(true)

        it("tests ForNum elaboration",
           function()
               local forNum = "for i = 1,10,2 do print(i) end"
               local forNumAst = parser.parse(forNum)
               assert.truthy(forNumAst)
               local elaborated = elaborater.elaborateForNum(forNumAst[1])
               print(ser.serBlock(forNumAst))
               print(util.tostring(elaborated))
               print(ser.serBlock(elaborated))
               assert.are.same(
                   elaborater.elaborateForNum(forNumAst[1]),
                   "foo, bar, foo2")
        end)

        it("test forIn elaboration",
           function()
               local forIn = "for k, v in ipairs({1,2,3}) do print(k, v) end"
               local forInAst = parser.parse(forIn)
               assert.truthy(forInAst)
        end)
end)
