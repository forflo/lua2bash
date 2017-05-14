local util = require('lua2bash-util')

-- getRotN(1) => {{1}}
-- getRotN(2) => {{1,2}, {2,1}}
-- getRotN(3) => {{1,2,3}, {2,3,1}, {3,1,2}}
-- ...
local function getRotN(number)
    local working = {}
    for i = 1, number do
        working[i] = {}
        local count = 1
        for j in util.range(number + 2 - i, number) do
            working[i][count] = j
            count = count + 1
        end
        for j in util.range(1, number + 1 - i) do
            working[i][count] = j
            count = count + 1
        end
    end
    return working
end

describe(
    "Tests some functions in util",
    function()
        randomize(true)

        -- for reference:
        -- assert.are.same(expected, passedin)
        it("Tests function parameter rotators",
           function()
               local testfunc = function(...) return { ... } end

               for testset in util.iterMap(util.iota(50), getRotN) do
                   for k = 1, #testset do
                       assert.are.same(
                           util.iterate(
                               util.rotR, testfunc, k)(
                               table.unpack(testset[1])),
                           testset[k % #testset + 1])
                       assert.are.same(
                           util.rotR(testfunc, k)(
                               table.unpack(testset[1])),
                           testset[k % #testset + 1])

                       -- tests whether right and left rotation
                       -- are the inverse operation of each other
                       local randRot = math.random(1,1000)
                       local rightRot = util.rotR(testfunc, randRot)
                       local leftRot = util.rotL(rightRot, randRot)
                       assert.are.same(
                           leftRot(table.unpack(testset[k])),
                           testset[k])
                   end
               end
        end)

        it("test the function iterator",
           function()
               local succ = function(x) return x + 1 end
               assert.are.same(util.iterate(succ, 0, 0), nil)
               assert.are.same(util.iterate(succ, 0, 3), 3)
               assert.are.same(util.iterate(succ, 10, 42), 52)
               assert.are.same(util.selfCompose(succ, 0)(0), nil)
               assert.are.same(util.selfCompose(succ, 3)(0), 3)
               assert.are.same(util.selfCompose(succ, 10)(42), 52)
        end)
end)
