describe(
    "Test data structures",
    function()
        randomize(true)

        setup("builds a symbol table with three scopes " ..
                  "each of which containing three symbols",
              function()
                  compiler = require("lua2bash-datatypes")
                  scope = require("lua2bash-scope")
                  stack = compiler.Stack()
                  scope1 = compiler.Scope(compiler.occasions.BLOCK,
                                          "global", 0, "global")
                  stack:push(scope1)
                  scope2 = compiler.Scope(compiler.occasions.FOR, "S1", 1,
                                          scope.getPathPrefix(stack) .. "S1")
                  stack:push(scope2)
                  scope3 = compiler.Scope(compiler.occasions.IF, "I1", 2,
                                          scope.getPathPrefix(stack) .. "I1")
                  stack:push(scope3)
                  stack:map(function(scope)
                          local symbol1 = compiler.Symbol(1, 1)
                          local symbol2 = compiler.Symbol(2, 1)
                          local symbol3 = compiler.Symbol(3, 1)
                          scope:getSymbolTable():addNewSymbol("x", symbol1)
                          scope:getSymbolTable():addNewSymbol("y", symbol2)
                          scope:getSymbolTable():addNewSymbol("z", symbol3)
                  end)
        end)

        it("test whether the names are set correctly",
           function()
               local names = stack:map(function(s) return s:getName() end)
               local correctNames = {"global", "S1", "I1"}
               assert.are.same(correctNames, names)
        end)

        it("tests whether the scope paths are calculated correctly",
           function()
               local paths = stack:map(function(s) return s:getPath() end)
               local correctPaths = {"global", "globalS1", "globalS1I1"}
               assert.are.same(correctPaths, paths)
        end)

        it("tests whether bottom is queried correctly",
           function()
               local occasion = stack:bottom():getOccasion()
               local name = stack:bottom():getName()
               assert.Truthy(occasion)
               assert.are.equal(name, "global")
        end)

        it("test whether top can be queried correctly",
           function()
               local occasion = stack:top():getOccasion()
               local name = stack:top():getName()
               assert.Truthy(occasion)
               assert.are.equal(name, "I1")
        end)
end)
