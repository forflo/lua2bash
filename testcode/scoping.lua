x = 3
do
    local x = 4
    local y = 1
    local y = 2
    print(x) -- must be 4
    print(y) -- must be 2
    do
        print(x)
        print(y)
        foo = 42
        do
            foo = foo - 1
        end
    end
end

print(x) -- must be 3
--print(y) -- must be nil
print(foo)
