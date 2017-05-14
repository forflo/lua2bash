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

        it("tests the function pullFirst",
           function()
               local pack = function(...) return { ... } end
               local input = {1, 2, 3, 4, 5, 6, 7, 8, 9}
               local result1 = {2, 1, 3, 4, 5, 6, 7, 8, 9}
               local result2 = {3, 1, 2, 4, 5, 6, 7, 8, 9}
               local result3 = {8, 1, 2, 3, 4, 5, 6, 7, 9}
               local result4 = {9, 1, 2, 3, 4, 5, 6, 7, 8}
               assert.are.same(
                   util.pullFirst(pack, 1)(table.unpack(input)), input)
               assert.are.same(
                   util.pullFirst(pack, 2)(table.unpack(result1)), input)
               assert.are.same(
                   util.pullFirst(pack, 3)(table.unpack(result2)), input)
               assert.are.same(
                   util.pullFirst(pack, 8)(table.unpack(result3)), input)
               assert.are.same(
                   util.pullFirst(pack, 9)(table.unpack(result4)), input)
        end)

        it('tests the bind function in combination with pullFirst and rotate',
           function()
               local output = {1, 2, 3}
               local func1 = util.bind(3, util.bindRotR(util.pack, 1))
               local func2 = util.bind(1, func1)
               local func3 = util.bind(2, func2)
               local tf1 = util.bind(2, util.bindRotL(util.pack, 1))

               local composed1 = util.bind(2, util.pullFirst(util.pack, 2))
               local composed2 = util.bind(3, util.pullFirst(composed1, 3))
               local composed3 = util.bind(1, util.pullFirst(composed2, 1))

               local composed12 = util.bind(3, util.pullFirst(util.pack, 3))
               local composed22 = util.bind(1, util.pullFirst(util.pack, 1))

               assert.are.same(composed1(1,3), {1,2,3})
               assert.are.same(composed2(1), {1,2,3})
               assert.are.same(composed3(), {1,2,3})
               assert.are.same(composed12(1,2), {1,2,3})
               assert.are.same(composed22(2,3), {1,2,3})
               assert.are.same(func1(1, 2), {1, 2, 3})
               assert.are.same(func3(), {1,2,3})
               assert.are.same(tf1(3, 1), {1,2,3})
        end)

        it("test the function tostring and toflatstring",
           function()
               local t = {1, {2, {3, {4, 5}}}}
               local str = '{[1]=1,[2]={[1]=2,[2]={[1]=3,[2]={[1]=4,[2]=5}}}}'
               assert.are.same(util.toflatstring(t), str)
               assert.are.False(util.tostring(t) == str)
        end)
end)
