add = function(x, y)
    return x + y
end

addC = function(x)
    return function(y)
        return x + y
    end
end

print(add(1,2))
print(addC(1)(2))
