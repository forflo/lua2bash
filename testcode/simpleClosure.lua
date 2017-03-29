f = {};
x = 2;

while x > 0 do
    local upval = 1;
    f[x] = function()
        upval = upval + 1;
        print(upval)
    end;

    x = x-1;
end;

f[1](); -- prints 2
f[1](); -- prints 3
f[2](); -- prints 2
