local testUtil = {}
local bp = require "lua-shepi"
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

-- lua library for reading and writing to processes!!
function testUtil.evaluateByLua(filename)
    local luaProc = bp.cmd("lua", "-")
    local fileContent = bp.cat('cat', filename)()
    return luaProc(fileContent)
end

function testUtil.evaluateByBash(filename)
    local result
    local ast, error_msg = parser.parse(filename)


    return result
end

describe(
    "Compiler test",
    function()
        randomize(true)

        setup("build table of file names",
              function()
                  testcode = {
                      closure = "testcode/closure.lua",
                      "testcode/closureUp.lua",
                      for1 = "testcode/for1.lua",
                      realClosure = "testcode/realClosure.lua",
                      scoping = "testcode/scoping.lua",
                      simpleClosure = "testcode/simpleClosure.lua"
                  }
        end)

        it("test whether a simple closure can be compiled correctly",
           function()
               assert.are.same(testUtil.evaluateByLua(testcode.simpleClosure),
                               testUtil.evaluateByBash(testcode.simpleClosure))
        end)
end)
