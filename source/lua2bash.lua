local parser = require "lua-parser.parser"
local util = require "lua2bash-util"
local orchestration = require("lua2bash-orchestration")

if #arg ~= 1 then
    print("Usage: lua2bash.lua <string>")
    os.exit(1)
end

local ast, error_msg = parser.parse(arg[1], "example.lua")

if not ast then
    print(error_msg)
    os.exit(1)
end

local codeEmitter = orchestration.newEmitter(ast)

print(util.join(codeEmitter(), '\n'))

os.exit(0)
