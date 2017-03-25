function CreateScope(config)
    -- empty object
    local result = {}
    local envPrefix = config.environmentPrefix
    -- init
    function result:init(occasion, name, pathPrefix)
        result.occasion = occasion
        result.name = name
        result.scope = {}
        environmentCounter = envPrefix .. getUniqueId(config)
        result.pathPrefix = pathPrefix
    end
    -- sets scope at the top for the first time
    function result:setFirstTime(idString)
        
    end
    --
    return result
end

function pushScope(env, occasion, name)
    local joinChar = ''
    local envId = getUniqueId(env)
    if #env.scopeStack == 0 then
        scopePath = name
    else
        scopePath = env.scopeStack[#env.scopeStack].pathPrefix
            .. joinChar .. name
    end
    env.scopeStack[#env.scopeStack + 1] =
        { occasion = occasion,
          name = name,
          environmentCounter = env.environmentPrefix .. envId,
          pathPrefix = scopePath,
          scope = { } }
end

function scopeSetLocalFirstTime(ast, env, scope, idString)
    local redefCountStr = "D1"
    local currentPathPrefix = getScopePath(env)
    local emitVN = env.varPrefix .. "${" .. scope.environmentCounter .. "}"
        .. "" .. currentPathPrefix .. "_" .. idString
    scope.scope[idString] = {
        value = 0,
        redefCount = 1,
        emitCurSlot = env.valPrefix .. redefCountStr .. emitVN,
        emitVarname = emitVN
    }
end

function scopeSetLocalAgain(ast, env, varAttr)
    local definitionInfix = "D"
    local currentPathPrefix = getScopePath(env)
    varAttr.redefCount = varAttr.redefCount + 1
    varAttr.emitCurSlot = env.valPrefix .. definitionInfix .. varAttr.redefCount
        .. varAttr.emitVarname
end

function scopeSetGlobal(env, idString)
    local definitionInfix = "D1"
    local emitVN = env.varPrefix .. "${" .. env.scopeStack[1].environmentCounter
        .. "}" .. "G_" .. idString
    env.scopeStack[1].scope[idString] = {
        value = 0,
        redefCount = 1,
        emitCurSlot = env.valPrefix .. definitionInfix .. emitVN,
        emitVarname = emitVN
    }
end

function getScopePath(env)
    local scopeNames = {}
    local joinChar = ''
    for i = 1, #env.scopeStack do
        scopeNames[#scopeNames + 1] = env.scopeStack[i].name
    end
    --dbg()
    return join(scopeNames, joinChar)
end

function popScope(env)
    table.remove(env.scopeStack, #env.scopeStack)
end

function topScope(env)
    return env.scopeStack[#env.scopeStack]
end

function isInSameScope(env, varName)
    local topScope = env.scopeStack[#env.scopeStack].scope

    for k, v in pairs(topScope) do
        if k == varName then
            return true, v -- v is a table
        end
    end

    return false, nil
end

-- table reverse
function isInSomeScope(env, varName)
    for idx, scope in pairs(tableReverse(env.scopeStack)) do
        for varname, attribs in pairs(scope.scope) do
            if (varname or "") == varName then
                return true, {scope, attribs}
            end
        end
    end

    return false, nil
end
