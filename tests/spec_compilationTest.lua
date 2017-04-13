local bp = require("lua-shepi")
local b = require("bashEdsl")
local parser = require("lua-parser.parser")
local pp = require("lua-parser.pp")
local dbg = require("debugger")
local serializer = require("lua2bash-serialize-ast")
local util = require("lua2bash-util")
local scope = require("lua2bash-scope")
local datatypes = require("lua2bash-datatypes")
local emitter = require("lua2bash-emit")

-- lua library for reading and writing to processes!!
local function evaluateByLua(filename)
    local luaProc = bp.cmd("lua", "-")
    local fileContent = bp.cat('cat', filename)()
    return luaProc(fileContent)
end

local function evaluateByBash(filename)
    local result
    local ast, error_msg = parser.parse(io.open(filename):read("a"))
    emitter.emitBlock(0, ast, config, stack, lines)
    local bashProc = bp.cmd('bash')
    return bashProc(util.join(lines, '\n'))
end

describe(
    "Compiler test",
    function()
        randomize(true)

        setup("build table of file names",
              function()
                  config = {}
                  config.tempVarPrefix = "TV" -- Temp Variable
                  config.tempValPrefix = "TL" -- Temp vaLue
                  config.environmentPrefix = "E"
                  config.functionPrefix = "AFUN"
                  config.tablePrefix = "TB" -- TaBle
                  config.varPrefix = "V" -- Variable
                  config.valPrefix = "L" -- vaLue
                  config.indentSize = 4

                  lines = {}
                  stack = datatypes.Stack()
                  stack:push(
                      datatypes.Scope(
                          datatypes.occasions.BLOCK,
                          "G",
                          util.getUniqueId(),
                          "G"))

                  testcode = {
                      simpleExp = "testcode/simpleExpressions.lua",
                      closure = "testcode/closure.lua",
                      closureUp = "testcode/closureUp.lua",
                      for1 = "testcode/for1.lua",
                      realClosure = "testcode/realClosure.lua",
                      scoping = "testcode/scoping.lua",
                      simpleClosure = "testcode/simpleClosure.lua"
                  }
        end)

        it("test whether a few simple expressions can be compiled correctly",
           function()
               assert.are.same(
                   evaluateByLua(testcode.simpleExp),
                   evaluateByBash(testcode.simpleExp))
        end)

        it("test whether a simple closure can be compiled correctly",
           function()
               assert.are.same(
                   evaluateByLua(testcode.simpleClosure),
                   evaluateByBash(testcode.simpleClosure))
        end)
end)
