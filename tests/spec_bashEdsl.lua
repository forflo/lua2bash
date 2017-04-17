describe(
    "general bash EDSL tests #BDSL",
    function()
        randomize(true)

        setup("loads libraries",
              function()
                  util = require("lua2bash-util")
                  b = require "../source/bashEdsl"
        end)

        it("tests whether package was loaded correctly",
           function()
               assert.Truthy(b)
        end)

        it("tests verbatim parameters #VP",
           function()
               assert.True(b.string("foo")() == "foo")
        end)

        it("tests a simple parameter expansion use cases #PE",
           function()
               assert.are.equal(b.paramExpansion("foo")(), [[${foo}]])
               assert.are.equal(
                   b.paramExpansion(b.string("foo"))(), [[${foo}]])
        end)

        it("tests another simple parameter expansion use case #PE",
           function()
               local str = b.paramExpansion(b.paramExpansion("foo"))()
               assert.are.equal(str, [[\${${foo}}]])
        end)

        it("tests parameter expansion use cases #PE",
           function()
               local str =
                   b.eval(
                       b.paramExpansion("foo")
                           .. b.paramExpansion(
                               b.paramExpansion("bar")))()
               assert.are.equal(str, [[eval ${foo}\${${bar}}]] ) end)

        it("test parentheses generation #PA",
           function()
               local str =
                   (b.parentheses(b.parentheses("foo"))
                        .. util.iterate(b.parentheses, "bar", 3))()
               assert.are.equal(str, [[\((foo)\)\\\(\((bar)\)\\\)]])
        end)

        it("test different kinds of parentheses",
           function()
               local str = b.parentheses(
                   b.paramExpansion("foo")
                       .. b.paramExpansion(
                           b.paramExpansion("bar")))()
               local strN = b.parentheses(
                   b.paramExpansion("foo")
                       .. b.paramExpansion(
                           b.paramExpansion("bar")))
                   :noDependentQuoting()()
               assert.are.same(str, [[\\\(${foo}\${${bar}}\\\)]])
               assert.are.same(strN, [[\(${foo}\${${bar}}\)]])
        end)

        it("test arithmetic expansion #AE",
           function()
               local str = b.eval(b.arithExpansion("1+2"))()
               assert.are.equal(str, [[$((1+2))]])
        end)

--        it("test all quoting #AQ",
--           function()
--               local str = b.eval(b.string"plain " .. b.a("!(%:$%[])", 1))()
--               assert.are.equal(str, [[plain \!\(\%\:\$\%\[\]\)]])
--        end)
end)
