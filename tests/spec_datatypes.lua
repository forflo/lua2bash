local datatypes = require("lua2bash-datatypes")

describe(
    "datatypes test",
    function()
        randomize(true)

        it("Tests predicate datatypes",
           function()
               local even = function(x) return x % 2 == 0 end
               local odd = function(x) return x % 2 ~= 0 end

               local evenP = datatypes.Predicate(even)
               local oddP = datatypes.Predicate(odd)
               local ored = evenP | oddP
               local anded = evenP & oddP
               local negated1, negated2 = ~evenP, ~oddP

               for i = 2,100,2 do
                   assert.True(evenP(i))
                   assert.False(oddP(i))
                   assert.True(ored(i))
                   assert.False(anded(i))
                   assert.True(negated2(i))
                   assert.False(negated1(i))
               end

               for i = 1, 100, 2 do
                   assert.False(evenP(i))
                   assert.True(oddP(i))
                   assert.True(ored(i))
                   assert.False(anded(i))
                   assert.False(negated2(i))
                   assert.True(negated1(i))
               end
        end)
end)
