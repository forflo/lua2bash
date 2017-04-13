parser = require "lua-parser.parser"
pp = require "lua-parser.pp"
dbg = require "debugger"

config = {}
config.tempVarPrefix = "TV" -- Temp Variable
config.tempValPrefix = "TL" -- Temp vaLue
config.environmentPrefix = "E"
config.functionPrefix = "AFUN"
config.tablePrefix = "TB" -- TaBle
config.varPrefix = "V" -- Variable
config.valPrefix = "L" -- vaLue
config.indentSize = 4

serializer = require "lua2bash-serialize-ast"
emitter = require "lua2bash-emit-stmt"
util = require "lua2bash-util"
scope = require "lua2bash-scope"
datatypes = require("lua2bash-datatypes")
b = require "bashEdsl"

if #arg ~= 1 then
    print("Usage: lua2bash.lua <string>")
    os.exit(1)
end

local ast, error_msg = parser.parse(arg[1], "example.lua")

if not ast then
    print(error_msg)
    os.exit(1)
end

lines = {}
stack = datatypes.Stack()
--TODO: ID
stack:push(datatypes.Scope(
               datatypes.occasions.BLOCK, "G",
               util.getUniqueId(), "G"))
emitter.emitBlock(0, ast, config, stack, lines)

for k,v in ipairs(lines) do
    print(v)
end

--tbl = linearizePrefixTree(parser.parse("x=x[1]('c')[1]('c2', 3)('c3')")[1][2][1])
--for k,v in ipairs(tbl) do
--    io.write(v.typ .. ' ') io.write(tostring(v.exp) .. '\n')
--end
-- annotates the AST adding the member containsFuncs to all
-- function nodes. This field can either be true or false. If
-- it is true, the subtree will contain at least one other function
-- subtree, otherwise one can be sure that there is no other function
-- declaration
-- traverser(ast,
--           function (node)
--               local env = {count = 0}
--               local predicate = function (x) return true end -- traverse all
--               local counter = function (node, env)
--                   if node.tag == "Function" then
--                       env.count = env.count + 1
--                   end
--               end
--
--               traverser(node, counter, env, predicate, true)
--               if env.count > 1 then
--                   node.containsFuncs = true
--               else
--                   node.containsFuncs = false
--               end
--
--           end, nil,
--           function (node)
--               if node.tag == "Function" then
--                   return true
--               else
--                   return false
--               end
--           end, true)

os.exit(0)
