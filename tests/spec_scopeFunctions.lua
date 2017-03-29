describe(
    "Test data structures",
    function()
        randomize(true)

        setup("builds a symbol table with three scopes " ..
                  "each of which containing three symbols",
              function()
                  config = {}
                  config.tempVarPrefix = "TV" -- Temp Variable
                  config.tempValPrefix = "TL" -- Temp vaLue
                  config.environmentPrefix = "E"
                  config.functionPrefix = "AFUN"
                  config.tablePrefix = "TB" -- TaBle
                  config.varPrefix = "V" -- Variable
                  config.valPrefix = "L" -- vaLue
                  config.indentSize = 4

                  compiler = require("lua2bash-comp")
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
                  local helperC = 0
                  dummySymbol = compiler.Symbol(1, 1)
                  local varNames = {
                      {"a", "b", "c"},
                      {"b", "c", "d"},
                      {"d", "x", "a"}
                  }
                  stack:map(function(scope)
                          helperC = helperC + 1
                          scope:getSymbolTable():addNewSymbol(
                              varNames[helperC][1], dummySymbol)
                          scope:getSymbolTable():addNewSymbol(
                              varNames[helperC][2], dummySymbol)
                          scope:getSymbolTable():addNewSymbol(
                              varNames[helperC][3], dummySymbol)
                  end)
        end)

        it("tests whether whereInScope will calculate the right results",
           function()
               local entries = scope.whereInScope(stack, "a")
               assert.are.same({
                       { exists = true,
                         symbol = dummySymbol,
                         scope = stack:bottom() },
                       { exists = false,
                         symbol = nil,
                         scope = stack:getNth(2) },
                       { exists = true,
                         symbol = dummySymbol,
                         scope = stack:top() } }, entries)
        end)

        it("test whether getMostCurrentBinding really only " ..
               "returns the most current binding",
           function()
               local result = scope.getMostCurrentBinding(stack, "d")
               assert.are.same({ exists = true,
                                 symbol = dummySymbol,
                                 scope = stack:top() }, result)
        end)

        it("tests whether setGlobal really updates a symbol",
           function()
               scope.setGlobal(config, stack, "goo")
               local result = scope.getMostCurrentBinding(stack, "goo")
               assert.Truthy(result.symbol)
               assert.True(result.exists)
               assert.are.equal(result.scope, stack:bottom())

               assert.are.same([[V${E0}globalS1I1goo]],
                               result.symbol:getEmitVarname())

               scope.setGlobal(config, stack, "goo")
               local result2 = scope.getMostCurrentBinding(stack, "goo")
               assert.are.not_equal(result.symbol, result2.symbol)
        end)

        it("tests whether setLocalFirstTime does set correctly first time",
           function()
               scope.setLocalFirstTime(config, stack, "moo")
        end)
end)
