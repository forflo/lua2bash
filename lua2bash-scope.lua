function pushScope(env, occasion, name)
    if #env.scopeStack == 0 then
        scopePath = name
    else
        scopePath = env.scopeStack[#env.scopeStack].pathPrefix .. "_" .. name
    end

    env.scopeStack[#env.scopeStack + 1] =
        { occasion = occasion, name = name,
          environmentCounter = "ENV_" .. scopePath,
          pathPrefix = scopePath, scope = { } }
end

function popScope(env)
    table.remove(env.scopeStack, #env.scopeStack)
end

function topScope(env)
    return env.scopeStack[#env.scopeStack]
end

function scopeGetScopeNamelistScopeStack(scopeStack)
    result = {}
    for i = 1, #scopeStack do
        result[#result + 1] = scopeStack[i].name
    end
    return result
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
