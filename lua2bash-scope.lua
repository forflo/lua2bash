function pushScope(env, o, n, s)
    env.scopeStack[#env.scopeStack + 1] =
        { occasion = o, name = n, scope = {} }
end

function popScope(env)
    table.remove(env.scopeStack, #env.scopeStack)
end

function topScope(env)
    return env.scopeStack[#env.scopeStack]
end

-- scope = { varX = { redefCount = 1, value = ""}, varY = {}}
function scopeAddLocal(varname, value, env)
    local entry = topScope(env).scope[varname] or {}
    if entry.redefCount == nil then entry.redefCount = 0 end

    entry.value = value

    topScope(env).scope[varname] = entry
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
                return true, {idx, attribs}
            end
        end
    end

    return false, nil
end

function getEntry(env, varName)
    for _, scope in pairs(env.scopeStack) do
        for varname, _ in pairs(scope.scope) do
            if varname == varName then
                return scope.scope[varname]
            end
        end
    end

    return nil
end

function findScope(env, scopeName)
    for k, v in pairs(env.scopeStack) do
        if v.name == scopeName then
            return v
        end
    end

    -- if no stack was found, nil will be given
    return nil
end
