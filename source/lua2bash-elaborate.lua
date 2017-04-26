local ab = require("lua2bash-ast-builder")

local elaborater = {}

function elaborater.elaborateForIn(ast)
    return ast -- TODO:
end

function elaborater.elaborateForNum(ast)
    if #ast == 4 then -- if no increment provided
        ast[5] = ast[4]
        ast[4] = ab.numberLit(1)
    end
    local block = ast[5]
    local loopIterator = ast[1]
    local var, limit, step = ast[2], ast[3], ast[4]
    local errorCall = ab.callStmt(ab.id'error')

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
                errorCall),
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
                        ab.op(
                            ab.operator['or'],
                            ab.op(
                                ab.operator['and'],
                                ab.op(
                                    ab.operator.ge,
                                    ab.id'step',
                                    ab.numberLit(0)),
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
                                    ab.id'step',
                                    ab.id'limit'))),
                        ab.block(
                            ab.breakStmt())),
                    ab.localAssignment(
                        ab.nameList(loopIterator),
                        ab.expList(ab.id'var')),
                    table.unpack(block))))
end

return elaborater
