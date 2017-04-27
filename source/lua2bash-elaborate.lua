local ab = require("lua2bash-ast-builder")

local elaborater = {}

function elaborater.elaborateForIn(ast)
    return ast -- TODO:
end

-- from the language reference manual
-- for v = e1, e2, e3 do block end
-- =>
-- do
--   local var, limit, step = tonumber(e1), tonumber(e2), tonumber(e3)
--   if not (var and limit and step) then error() end
--   var = var - step
--   while true do
--     var = var + step
--     if (step >= 0 and var > limit) or (step < 0 and var < limit) then
--       break
--     end
--     local v = var
--     <block>
--   end
-- end
function elaborater.elaborateForNum(ast)
    if #ast == 4 then -- if no increment provided
        ast[5] = ast[4]
        ast[4] = ab.numberLit(1)
    end
    local block = ast[5]
    local loopIterator = ast[1]
    local var, limit, step = ast[2], ast[3], ast[4]
    local errorCallBlock = ab.block(ab.callStmt(ab.id'error'))

    -- build up new expanded AST
    return
        ab.doStmt(
            ab.localAssignment(
                ab.nameList(
                    ab.id('var'),
                    ab.id('limit'),
                    ab.id('step')),
                ab.expList(var, limit, step)),
            ab.ifStmt(
                ab.op(
                    ab.operator['not'],
                    ab.auxNaryAnd(
                        ab.id'var',
                        ab.id'limit',
                        ab.id'step')),
                errorCallBlock),
            ab.globalAssignment(
                ab.varList(ab.id'var'),
                ab.expList(
                    ab.op(
                        ab.operator.sub,
                        ab.id'var',
                        ab.id'step'))),
            ab.whileLoop(
                ab.trueLit(),
                ab.block(
                    ab.globalAssignment(
                        ab.varList(ab.id'var'),
                        ab.expList(
                            ab.op(
                                ab.operator.add,
                                ab.id'var',
                                ab.id'step'))),
                    ab.ifStmt(
                        -- (step >= 0 and var > limit) or (step < 0 and var < limit)
                        -- where step >= 0 => 0 <= step
                        ab.op(
                            ab.operator['or'],
                            ab.op(
                                ab.operator['and'],
                                ab.op(
                                    ab.operator.le,
                                    ab.numberLit(0),
                                    ab.id'step'),
                                ab.op(
                                    ab.operator.gt,
                                    ab.id'var',
                                    ab.id'limit')),
                            ab.op(
                                ab.operator['and'],
                                ab.op(
                                    ab.operator.lt,
                                    ab.id'step',
                                    ab.numberLit(0)),
                                ab.op(
                                    ab.operator.lt,
                                    ab.id'var',
                                    ab.id'limit'))),
                        ab.block(
                            ab.breakStmt())),
                    ab.localAssignment(
                        ab.nameList(loopIterator),
                        ab.expList(ab.id'var')),
                    table.unpack(block))))
end

-- for var_1, ···, var_n in explist do block end
-- translates to
-- do
--     local f, s, var = explist
--     while true do
--         local var_1, ···, var_n = f(s, var)
--         if var_1 == nil then break end
--         var = var_1
--         block
--     end
-- end
function elaborater.elaborateForIn(ast)
    local forInNameList , forInExpList = ast[1], ast[2]
    local forInStatements = ast[3]
    local firstName = forInNameList[1]

    return ab.doStmt(
        ab.localAssignment(
            ab.nameList(ab.id'f', ab.id's', ab.id'var'),
            forInExpList),
        ab.whileLoop(
            ab.trueLit(),
            ab.block(
                ab.localAssignment(
                    forInNameList,
                    ab.callStmt(
                        ab.id'f', ab.id's', ab.id'var')),
                ab.ifStmt(
                    ab.op(
                        ab.operator.eq, firstName, ab.nilLit()),
                    ab.block(ab.breakStmt())),
                ab.globalAssignment(
                    ab.nameList(ab.id'var'),
                    ab.expList(firstName)),
                table.unpack(forInStatements))))
end

return elaborater
