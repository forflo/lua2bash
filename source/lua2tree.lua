local parser = require "lua-parser.parser"
local pp = require "lua-parser.pp"

dbg = require "debugger"
util = require "lua2bash-util"
serializer = require "lua2bash-serialize-ast"

if #arg ~= 1 then
    print("Usage: parse.lua <string>")
    os.exit(1)
end

local ast, error_msg = parser.parse(arg[1], "example.lua")
if not ast then
    print(error_msg)
    os.exit(1)
end


pp.dump(ast,1)
pp.print(ast)

require "lua2bash-serialize-ast"

print(serializer.serBlock(ast))

os.exit(0)
