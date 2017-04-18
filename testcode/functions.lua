add = function(x, y)
    return x + y
end

addC = function(x)
    return function(y)
        return x + y
    end
end

arg1 = function(x, y, z, u)
    local x = 300
    print(x, y, z, u)
end

(function(x) print(x) end)(3)
(function(x,y,z) print(x,y,z) end)(3,2,1)
--(function(x,y,z) print(x,y,z) end)(3,2)

print(add(1,2))
print(addC(1)(2))

arg1(1,2,3,4)
