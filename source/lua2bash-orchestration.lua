local datatypes = require("lua2bash-datatypes")
local util = require("lua2bash-util")

local orchestration = {}

function orchestration.newConfig()
    local config = {}
    config.tempVarPrefix = "TV" -- Temp Variable
    config.tempValPrefix = "TL" -- Temp vaLue
    config.environmentPrefix = "E"
    config.functionPrefix = "AFUN"
    config.tablePrefix = "TB" -- TaBle
    config.varPrefix = "V" -- Variable
    config.valPrefix = "L" -- vaLue
    config.nilVarName = "VARNIL"
    config.indentSize = 4
    config.counter = {}
    for _, v in pairs({"scope", "table", "env", "func"}) do
        config.counter[v] = util.getCounter(1)
    end
    return config
end

function orchestration.newStack()
    local stack = datatypes.Stack()
--TODO: ID
    stack:push(
        datatypes.Scope(
            datatypes.occasions.BLOCK, "G",
            util.getUniqueId(), "G"))
    return stack
end

return orchestration
