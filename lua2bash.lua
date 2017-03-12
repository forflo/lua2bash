parser = require "lua-parser.parser"
pp = require "lua-parser.pp"
dbg = require "debugger"

--dbg = function () return end

require "lua2bash-emit-stmt"
require "lua2bash-emit-exp"
require "lua2bash-util"
require "lua2bash-scope"

if #arg ~= 1 then
    print("Usage: lua2bash.lua <string>")
    os.exit(1)
end

local ast, error_msg = parser.parse(arg[1], "example.lua")

if not ast then
    print(error_msg)
    os.exit(1)
end

-- print(alreadyDefined({ {name = "g", scope = { x = "" }}  }, "x"))

env = {}
env.scopeStack = {} -- rechts => neuer
env.tempPrefix = "ERG"
env.functionPrefix = "AFUN"
env.ergCnt = 0
env.tablePrefix = "ATBL"
env.varPrefix = "VAR"
env.indentSize = 4
env.columnCount = -env.indentSize
env.tablePath = ""
env.scopeStack = {}
env.funcArglist = {}
env.globalIdCount = 0
-- scopeStack = {{name = "global", scope = {<varname> = "<location>"}},
--               {name = "anon1", scope = {}}, ...}

lines = emitBlock(ast, env, {})

for k,v in ipairs(lines) do
    print(v)
end

os.exit(0)
