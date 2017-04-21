parser = require "lua-parser.parser"
pp = require "lua-parser.pp"
dbg = require "debugger"
serializer = require "lua2bash-serialize-ast"
emitter = require "lua2bash-emit"
util = require "lua2bash-util"
scope = require "lua2bash-scope"
datatypes = require("lua2bash-datatypes")
b = require "bashEdsl"
orch = require("lua2bash-orchestration")

if #arg ~= 1 then
    print("Usage: lua2bash.lua <string>")
    os.exit(1)
end

local ast, error_msg = parser.parse(arg[1], "example.lua")

if not ast then
    print(error_msg)
    os.exit(1)
end

local lines, stack, config = {}, orch.newStack(), orch.newConfig()
emitter.emitBootstrap(0, config, stack, lines)
emitter.emitBlock(0, ast, config, stack, lines)

print(util.join(lines, '\n'))

os.exit(0)
