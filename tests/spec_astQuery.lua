local aQ = require("lua2bash-ast-builder")
local ser = require("lua2bash-serialize-ast")
local parser = require("lua-parser.parse")

local testCode = [[
do
    local x =
        (function(x)
                local x = x
                return x + 1
         end)(41)

    do
        local y = x
        local f = y
    end

    do
        f = function(x)
            if x == nil then
                return x + 1
            elseif x == 3 then
                return x + 3
            else
                g = function(m)
                    againNest = function(f) return f end
                    return m
                end
                return g(x)
            end
        end

        print(1+2)
        print(3*4)
        print(4)
    end
end
    ]]

describe(
    "Ast Query test",
    function()
        randomize(true)

        it("tests normal node predicates",
           function()
               local Q = aQ.treeQuery
               local ast, _ = parser.parse(testCode)
        end)

        it("",
           function()
        end)
end)
