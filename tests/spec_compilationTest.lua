local bp = require("lua-shepi")
local parser = require("lua-parser.parser")
local dbg = require("debugger")
local util = require("lua2bash-util")
local emitter = require("lua2bash-emit")
local orchestration = require("lua2bash-orchestration")

local function evaluateByLua(filename)
    local luaProc = bp.cmd("lua", "-")
    local fileContent = bp.cat('cat', filename)()
    return luaProc(fileContent)
end

local function evaluateByBash(filename)
    local ast, error_msg = parser.parse(io.open(filename):read("a"))
    assert.Truthy(ast)
    assert.is.True(type(ast) == "table")
    assert.is.True(ast.tag == "block")
    local result, emitter = nil, orchestration.newEmitter(ast)
    local bashProc = bp.cmd('bash')
    -- TODO: check whether we need the trailing new line
    result = bashProc(util.join(emitter(), '\n') .. '\n')
    return result
end

describe(
    "Compiler test",
    function()
        randomize(true)

        setup("build table of file names",
              function()
                  testcode = {
                      simpleExp = "testcode/simpleExpressions.lua",
                      tableExp = "testcode/tableExpressions.lua",
                      closure = "testcode/closure.lua",
                      closureUp = "testcode/closureUp.lua",
                      for1 = "testcode/for1.lua",
                      realClosure = "testcode/realClosure.lua",
                      scoping = "testcode/scoping.lua",
                      simpleClosure = "testcode/simpleClosure.lua"
                  }
        end)

        it("tests whether scoping is implemented correctly",
           function()
               assert.are.same(
                   evaluateByLua(testcode.scoping),
                   evaluateByBash(testcode.scoping))
        end)

        it("test whether a few simple expressions can be compiled correctly",
           function()
               assert.are.same(
                   evaluateByLua(testcode.simpleExp),
                   evaluateByBash(testcode.simpleExp))
        end)

        it("test whether a simple closure can be compiled correctly",
           function()
               local bashR = evaluateByBash(testcode.simpleClosure)
               local luaR = evaluateByLua(testcode.simpleClosure)
               assert.is.True(#bashR > 0)
               assert.are.same(bashR, luaR)
        end)
end)
