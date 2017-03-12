function pushScope(env, o, n, s)
    env.scopeStack[#env.scopeStack + 1] =
        {occasion = o, name = n, scope = (s or {})}
end

function popScope(env)
    table.remove(env.scopeStack, #env.scopeStack)
end

function scopeAddGlobal(id, value, scopeStack)
    if #scopeStack < 1 then
        print("scopeAddGlobal(): invalid size of scopeStack!")
        os.exit(1)
    end

    globalScope = scopeStack[1].scope
    globalScope.id = value
end

function scopePrint(scopeStack)
    if scopeStack == nil then
        msgdebug("Error! Got nil")
        return
    end

    dbg()

    for k, v in pairs(scopeStack) do
        print(string.format("scope[%s] with name %s (occasion: %s) contains:",
                            k, v.name, v.occasion))
        for k2, v2 in pairs(v.scope) do
            print(string.format("  %s = %s", k2, v2))
        end
    end
end

function scopeGetScopeNamelistScopeStack(scopeStack)
    result = {}
    for i = 1, #scopeStack do
        result[#result + 1] = scopeStack[i].name
    end
    return result
end

function findScope(scopeStack, scopeName)
    for k, v in pairs(scopeStack) do
        if v.name == scopeName then
            return v
        end
    end

    -- if no stack was found, nil will be given
    return nil
end
