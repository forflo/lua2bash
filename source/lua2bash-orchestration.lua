local datatypes = require("lua2bash-datatypes")
local util = require("lua2bash-util")
local emitter = require("lua2bash-emit")

local orchestration = {}

function orchestration.newConfig()
    local config = {}
    config.tempVarPrefix = "TV" -- Temp Variable
    config.tempValPrefix = "TL" -- Temp vaLue
    config.scopePrefix = "S"
    config.functionPrefix = "AFUN"
    config.tablePrefix = "TB" -- TaBle
    config.varPrefix = "V" -- Variable
    config.valPrefix = "L" -- vaLue
    config.tableElementCounter = "TE"
    config.bootstrap = {
        nilVarName = "VARNIL",
        retVarName = "VALRETURNED",
        stackPointer = "STACKPOINTER"
    }
    config.defaultMtabNumbers = "MTABNUM"
    config.defaultMtabStrings = "MTABSTR"
    config.defaultMtabFunctions = "MTABFUN"
    config.defaultMtabTables = "MTABTBL"
    config.defaultMtabNil = "MTABNIL"
    config.skalarTypes = {
        nilType = "NIL",
        tableType = "TBL",
        numberType = "NUM",
        stringType = "STR",
        functionType = "FUN",
        booleanType = "BOOL"
    }
    config.indentSize = 4
    config.counter = {}
    for _, v in pairs({"scope", "table", "env", "func", "tempval"}) do
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

function orchestration.newEmitter(ast)
    return function()
        local stack, config = orchestration.newStack(), orchestration.newConfig()
        local lines = {}
        emitter.emitBootstrap(0, config, stack, lines)
        emitter.emitBlock(0, ast, config, stack, lines)
        return lines
    end
end

return orchestration
