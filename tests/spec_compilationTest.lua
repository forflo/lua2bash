local testUtil = {}
local parser = require "lua-parser.parser"
local pp = require "lua-parser.pp"
local dbg = require "debugger"
local serializer = require "lua2bash-serialize-ast"
local util = require "lua2bash-util"
local scope = require "lua2bash-scope"
local datatypes = require("lua2bash-datatypes")
local b = require "bashEdsl"
require "lua2bash-emit-stmt"
require "lua2bash-emit-exp"

testUtil.config = {}
testUtil.config.tempVarPrefix = "TV" -- Temp Variable
testUtil.config.tempValPrefix = "TL" -- Temp vaLue
testUtil.config.environmentPrefix = "E"
testUtil.config.functionPrefix = "AFUN"
testUtil.config.tablePrefix = "TB" -- TaBle
testUtil.config.varPrefix = "V" -- Variable
testUtil.config.valPrefix = "L" -- vaLue
testUtil.config.indentSize = 4

function testUtil.evaluateByLua(filename)
    local result

    return result
end

function testUtil.evaluateByBash(filename)
    local result

    return result
end

describe(
    "Compiler test",
    function()
        randomize(true)

        setup("build table of file names",
              function()
                  testcode = {
                      "testcode/closure.lua",
                      "testcode/closureUp.lua",
                      "testcode/for1.lua",
                      "testcode/realClosure.lua",
                      "testcode/scoping.lua",
                      "testcode/simpleClosure.lua"
                  }
        end)

        it("test whether test codes can be compiled correctly",
           function()
               for _, v in pairs(testcode) do
                   local luaResult = testUtil.evaluateByLua(testcode[1])
                   local bashResult = testUtil.evaluateByBash(testcode[1])
               end
        end)
end)
