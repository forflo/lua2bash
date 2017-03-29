-- RHS_0=1; RHS_1=2; RHS_2=3;
-- SCL_a="$(RHS_0)"; SCL_b="$(RHS_1)"; SCL_c=$(RHS_2);
a, b, c = 1, 2, 3

-- RHS_0="$(SCL_b)"; RHS_1="$(SCL_a)";
-- SCL_a="$(RHS_0)"; SCL_b="$(RHS_1)";
a, b = b, a

-- varlist `=` explist
-- immer die form
-- RHS_0=`eval`; RHS_1=`eval`;

--
a[0] = 3

t = {1, 2, 3}
t.foo = "bar"
t.moo = {"a", "b", "c"}
t[0] = {1,2,3}
-- => t = {{1,2,3},2,3,["foo"]="bar",["moo"]={"a", "b", "c"}}

VAR_t=("TBL" "")
VAR_t_1=("INT" "1")
VAR_t_2=("INT" "2")
VAR_t_3=("INT" "3")

VAR_t_foo=("STR" "bar")

VAR_t__moo_1=("STR" "a")
VAR_t__moo_2=("STR" "b")
VAR_t__moo_3=("STR" "c")

VAR_t_1=("TBL" "")
VAR_t_1_1=("INT" 1)
VAR_t_1_2=("INT" 2)
VAR_t_1_3=("INT" 3)

t = function (x, y, z)
    print x
    print y
    print z
    return 0
end
t(1,2,3)

ANON_0=("FUN" 'function anon_0 {
    echo ${ANON_0_ENV_x}; ...; ANON_0_ENV_RET="0" };')
declare -Ag ANON_0_ENV
ANON_0_ENV_RET=("" "")
ANON_0_ENV_x=("" "")
ANON_0_ENV_y=("" "")
ANON_0_ENV_z=("" "")

VAR_t=("")
eval "${VAR_t[1]} 1 2 3"

t = {function (x,y,z) print x; print y; print z; end, 123}
t[1]("foo", "bar", "moo")

VAR_t=("TBL" "")
VAR_t_1=("FUN" 'function t { echo $1; echo $2; echo $3; }; ')
VAR_t_2=("INT" "123")
eval "${VAR_t_1[1]} foo bar moo"




(function (x)
    return (function (y)
        print(x)
        print(y)
    end)
end)(1)(2)

ANON_1_ENV_RET=
ANON_1_ENV_x=
ANON_1_ENV_UPSCOPE
ANON_1=("FUN" 'function anon_1 { ANON_1_ENV_RET=; };')

ANON_0_ENV_RET=
ANON_0_ENV_y
ANON_0_ENV_UPSCOPE="ANON_1_ENV"
ANON_0=("FUN" 'function anon_0 { echo };')



-- function a()
-- a is function
f = a(1)[0]
