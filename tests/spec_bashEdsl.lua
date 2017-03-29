describe(
    "general bash EDSL tests #BDSL",
    function()
        setup("loads libraries", function()
                  util = require("lua2bash-util")
        end)

        randomize(true)
        b = require "../source/bashEdsl"

        it("tests whether package was loaded correctly",
           function()
               assert.Truthy(b)
        end)

        it("tests verbatim parameters #VP",
           function()
               assert.True(b.c("foo")() == "foo")
        end)

        it("tests a simple parameter expansion use cases #PE",
           function()
               assert.are.equal(b.pE("foo")(), [[${foo}]])
        end)

        it("tests another simple parameter expansion use case #PE",
           function()
               local str = b.pE(b.pE("foo"))()
               assert.are.equal(str, [[\${${foo}}]])
        end)

        it("tests parameter expansion use cases #PE",
           function()
               local str = b.e(b.pE("foo") .. b.pE(b.pE("bar")))()
               assert.are.equal(str, [[eval ${foo}\${${bar}}]] ) end)

        it("test parentheses generation #PA",
           function()
               local str = (b.p(b.p("foo")) .. util.iterate(b.p, "bar", 3))()
               assert.are.equal(str, [[\((foo)\)\\\(\((bar)\)\\\)]])

        end)

        it("test arithmetic expansion #AE",
           function()
               local str = b.e(b.aE("1+2"))()
               assert.are.equal(str, [[$((1+2))]])
        end)

        it("test all quoting #AQ",
           function()
               local str = b.e(b.c"plain " .. b.a("!(%:$%[])",1))()
               assert.are.equal(str, [[plain \!\(\%\:\$\%\[\]\)]])
        end)
end)
