local ab = require("lua2bash-ast-builder")
local util = require("lua2bash-util")
local ser = require("lua2bash-serialize-ast")
local parser = require("lua-parser.parser")
local parserDump = require("lua-parser.pp")
local elaborater = require("lua2bash-elaborate")

local forNumElaboration =
[[do local var, limit, step = 1, 10, 2; if not (var and limit]] ..
[[ and step) then error(); end; var = var - step; while (true) ]] ..
[[do var = var + step; if 0 <= step and var > limit or step < 0 and]] ..
[[ var < limit then break; end; local i = var; print(i); end; end]]

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
               assert.are.same(
                   ser.serDo(elaborated),
                   forNumElaboration)
        end)

        it("test forIn elaboration",
           function()
               local forIn = "for k, v in ipairs({1,2,3}) do print(k, v) end"
               local forInAst = parser.parse(forIn)
               assert.truthy(forInAst)
        end)
end)
