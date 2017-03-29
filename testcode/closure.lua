funs = {}
x = 3
do 
    local x = 4
    funs[1] = function() x = x + 1; return x end
    local x = 40
    funs[2] = function() x = x + 1; return x end
end 

funs[1]() -- must be 5
funs[2]() -- must be 41
funs[1]() -- must be 6
funs[2]() -- must be 42

print(x)  -- must be 3
