describe(
    "Test of serializer module",
    function()
        randomize(true)

        setup("Just library loading and this kind of necessary stuff",
              function()
                  serializer = require("lua2bash-serialize-ast")
                  parser = require("lua-parser.parser")
                  assert.Truthy(serializer)
        end)

        it("tests serialization of simple expressions",
           function()
               local sE = {
                   "a=1+2",
                   "a=1+2*3/4//5|6^2 and (2+3)-4",
                   "a=({1,2,3,4})[2^({1,2,3})[2]]",
                   "a=(function(x) return x + 1 end)(3)",
                   "a=b()[3][1](1,2,3,4)[b() + 3]"
               }
               local expected = {
                   "a = 1 + 2; ",
                   "a = 1 + 2 * 3 / 4 // 5 | 6 ^ 2 and (2 + 3) - 4; ",
                   "a = ({1, 2, 3, 4})[2 ^ ({1, 2, 3})[2]]; ",
                   "a = (function(x) return x + 1; end)(3); ",
                   "a = b()[3][1](1, 2, 3, 4)[b() + 3]; "
               }

               for i = 1, #sE do
                   local ast, error_msg = parser.parse(sE[i])
                   assert.Truthy(ast)
                   local serializedAst = serializer.serBlock(ast)
                   assert.Truthy(serializedAst)
                   assert.are.same(serializedAst, expected[i])
               end
        end)

        it("tests serialization of simple statements",
           function()
               -- TODO:
        end)

        it("tests serialization of compound statements",
           function()
               -- TODO:
        end)
end)
