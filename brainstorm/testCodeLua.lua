function c(x)
    local temp = x
    func = function(y)
        print("before: " .. temp)
        temp = temp + 1
        return x + y
    end
    func(0)
    print("after: " .. temp)
    return func
end

t = c(0) -->
t(1)     -->

t = c(1)
t(1)

function c(x)
    local temp = 3
    func = function (y)
        print("before: " ..temp)
        temp = temp + 1
        return x + y
    end
    func(0)
    print("after: " .. temp)
    return func
end

t = c(0) -->
t(1) -->

t = c(1)
t(1)

-- a="foo"
-- VAR_a=("STR", 'VAL_VAR_A')
-- VAL_VAR_a="foo"

-- a=3
-- VAR_a=("NUM", 'VAL_VAR_A')
-- VAL_VAR_a="3"

-- a={1,2,3}
-- ATBL_1=("TBL", 'ATBL_1')
-- ATBL_1_1=("NUM", '')
-- ATBL_1_1[1]=1
-- ATBL_1_2=("NUM", '')
-- ATBL_1_2[1]=1
-- ATBL_1_3=("NUM", '')
-- ATBL_1_3[1]=1

-- VAR_a=("TBL", 'ATBL_1')


-- b=42
-- a=function (x) b = b + 1; return x + b end;
-- c=b(3)
-- u = function (a)
--   return function (b)
--     return a + b
--   end
-- end

-- # b=42
-- RHS_1=("NUM" '')
-- ERG_1=("NUM" '42')
-- RHS_1[1]=${ERG_1[1]}
-- VAR_b=("NUM", 'VAL_VAR_b')
-- VAL_VAR_b=${RHS_1[1]}     # ${!VAR_b[1]}
-- # a=function ...
-- AFUN_1=("FUN" 'BFUN_1')
-- AFUN_1_RET=("VAR" 'AFUN_1_VAL_RET')
-- AFUN_1_LOCAL_VAR_x=("VAR" 'AFUN_1_VAL_VAR_x')
-- AFUN_1_ENV_VAR_b=("STR" 'VAL_VAR_b')
-- function BFUN_1 () {
--     BFUN_1_VAR_x=("VAR" 'BFUN_1_VAL_VAR_x')
--     eval BFUN_1_VAL_VAR_x="\${!$1}"
--     E1=1
--     E2=${!AFUN_1_ENV_VAR_b[1]}
--     eval ${AFUN_1_ENV_VAR_b[1]}=$((E1+E2)) #b=b+1
--     E3=$((${!AFUN_1_ENV_VAR_b[1]}+${!AFUN_1_VAR_x})) # x+b
--     eval ${!AFUN_1_RET[1]}=${!AFUN_1_ENV_VAR_b[1]} # return
--
--}
-- E10=3
-- BFUN_1 E10
-- VAR_c=("NUM", 'VAL_VAR_c')
-- VAL_VAR_C=${!AFUN_1_RET[1]} = c=b(3)

-- Variablen = 2-Tupel: (1) "Typ" (2) Location
-- Location is eine Id: ID='<String>'
