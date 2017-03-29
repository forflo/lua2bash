f = {};
x = 2;

add = function(x)
    return function(y)
        return x + y
    end 
end

c1 = add(1)
c2 = add(2)

print(c1(1)) -- prints 2
print(c1(3)) -- prints 4
print(c2(3)) -- prints 5
print(c1(3)) -- prints 4

c2 = add(42)
print(c1(42)) -- prints 84
