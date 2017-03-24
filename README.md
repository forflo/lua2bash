# What?

Yes, this is a lua to BASH translator.
It takes lua code and gives you BASH code.

# Why?

Because BASH runs everywhere by default and lua is awesome.

# What is possible

Here a few things that work right now

## Closures and first class functions

Yes, this is real. Closures have come to the bash.
Well, at least the following trivial example works
as expected. I am, however, not even remotely sure
whether the target code will always behave in correct,
closure-semantic ways.

But here is the test code...

```lua
f = {};
x = 2;

while x > 0 do
    local upval = 1;
    f[x] = function()
        upval = upval + 1;
        print(upval)
    end;

    x = x-1;
end;

f[1](); -- prints 2
f[1](); -- prints 3
f[2](); -- prints 2
```

And here, ladies and gentlemen, is the corresponding BASH
code (only successfully tested on 4.4.12(1)-release).

Transpilation command: `$ lua lua2bash.lua "$(<tc/simpleClosure.lua)" | bash`

```bash
# Begin of Scope: G
if [ -z $E2 ]; then                                 # environment counter
    E2=0;                                           # environment counter
else                                                # environment counter
    ((E2++))                                        # environment counter
fi                                                  # environment counter
# f = {}
# {}
eval TB${E2}3=\(TB${E2}3 Table\)
eval TL${E2}_4=\(\${TB${E2}3} \${TB${E2}3[1]}\)
eval V${E2}G_f=LD1V${E2}G_f
eval LD1V${E2}G_f=\(\${TL${E2}_4} \${TL${E2}_4[1]}\)
# x = 2
eval TL${E2}_5=\(2 NUM\)
eval TL${E2}_6=\(\${TL${E2}_5} \${TL${E2}_5[1]}\)
eval V${E2}G_x=LD1V${E2}G_x
eval LD1V${E2}G_x=\(\${TL${E2}_6} \${TL${E2}_6[1]}\)
eval TL${E2}_9=\(0 NUM\)
eval TL${E2}_10=\(\${!V${E2}G_x} $(eval echo \\\${\${V${E2}G_x}[1]})\)
eval TL${E2}_8=\("\$((\${TL${E2}_9}<\${TL${E2}_10}))" \${TL${E2}_10[1]}\)
eval TL_11=\(\${TL${E2}_8} \${TL${E2}_8[1]}\)
while [ "${TL_11}" != 0 ]; do
    # Begin of Scope: GS12
    if [ -z $E13 ]; then                                # environment counter
        E13=0;                                          # environment counter
    else                                                # environment counter
        ((E13++))                                       # environment counter
    fi                                                  # environment counter
    eval TL${E13}_14=\(1 NUM\)
    eval TL${E13}_15=\(\${TL${E13}_14} \${TL${E13}_14[1]}\)
    eval V${E13}GS12_upval=LD1V${E13}GS12_upval
    eval LD1V${E13}GS12_upval=\("\${TL${E13}_15}" \${TL${E13}_15[1]}\)
    # f[x] = function() upval = upval+1; print(upval); end
    # Closure defintion
    eval TL${E13}_18=\(BF16 ${E13}\)
    # Environment Snapshotting
    eval TL${E13}_19=\(\${!V${E13}GS12_upval} $(eval echo \\\${\${V${E13}GS12_upval}[1]})\)
    eval TL${E13}_20=\(\${TL${E13}_19} \${TL${E13}_19[1]}\)
    eval V${E13}GS12F16_upval=LD1V${E13}GS12F16_upval
    eval LD1V${E13}GS12F16_upval=\("\${TL${E13}_20}" \${TL${E13}_20[1]}\)
    eval V${E13}GS12F16_print=LD1V${E13}GS12F16_print
    eval LD1V${E13}GS12F16_print=\("\${DUMMY}" \${DUMMY[1]}\)
    function BF16 {
        E13=$1
        # Begin of Scope: GS12F16S21
        if [ -z $E22 ]; then                                # environment counter
            E22=0;                                          # environment counter
        else                                                # environment counter
            ((E22++))                                       # environment counter
        fi                                                  # environment counter
        # upval = upval+1
        eval TL${E22}_25=\(\${!V${E13}GS12F16_upval} $(eval echo \\\${\${V${E13}GS12F16_upval}[1]})\)
        eval TL${E22}_26=\(1 NUM\)
        eval TL${E22}_24=\("\$((\${TL${E22}_25}+\${TL${E22}_26}))" \${TL${E22}_26[1]}\)
        eval TL${E22}_27=\(\${TL${E22}_24} \${TL${E22}_24[1]}\)
        eval LD1V${E13}GS12F16_upval=\(\${TL${E22}_27} \${TL${E22}_27[1]}\)
        # print(upval)
        eval TL${E22}_28=\(\${!V${E13}GS12F16_upval} $(eval echo \\\${\${V${E13}GS12F16_upval}[1]})\)
        eval echo \${TL${E22}_28}
        E17=$1
    }
    eval TL${E13}_29=\(\${TL${E13}_18} \${TL${E13}_18[1]}\)
    eval TL${E13}_30=\(\${!V${E2}G_f} $(eval echo \\\${\${V${E2}G_f}[1]})\)
    eval TL${E13}_31=\(\${!V${E2}G_x} $(eval echo \\\${\${V${E2}G_x}[1]})\)
    eval $(eval echo \${TL${E13}_30}\${TL${E13}_31})=\(\${TL${E13}_29} \${TL${E13}_29[1]}\)
    # x = x-1
    eval TL${E13}_34=\(\${!V${E2}G_x} $(eval echo \\\${\${V${E2}G_x}[1]})\)
    eval TL${E13}_35=\(1 NUM\)
    eval TL${E13}_33=\("\$((\${TL${E13}_34}-\${TL${E13}_35}))" \${TL${E13}_35[1]}\)
    eval TL${E13}_36=\(\${TL${E13}_33} \${TL${E13}_33[1]}\)
    eval LD1V${E2}G_x=\(\${TL${E13}_36} \${TL${E13}_36[1]}\)
    eval TL${E2}_39=\(0 NUM\)
    eval TL${E2}_40=\(\${!V${E2}G_x} $(eval echo \\\${\${V${E2}G_x}[1]})\)
    eval TL${E2}_38=\("\$((\${TL${E2}_39}<\${TL${E2}_40}))" \${TL${E2}_40[1]}\)
    eval TL_11=\${TL${E2}_38}
    true  # to prevent empty block
done
# f[1]()
eval TL${E2}_41=\(\${!V${E2}G_f} $(eval echo \\\${\${V${E2}G_f}[1]})\)
eval TL${E2}_42=\(1 NUM\)
eval TL${E2}_43=\($(eval echo \\\${\${TL${E2}_41}\${TL${E2}_42}}) $(eval echo \\\${\${TL${E2}_41}\${TL${E2}_42}[1]})\)
eval \${TL${E2}_43} \${TL${E2}_43[1]}
# f[1]()
eval TL${E2}_44=\(\${!V${E2}G_f} $(eval echo \\\${\${V${E2}G_f}[1]})\)
eval TL${E2}_45=\(1 NUM\)
eval TL${E2}_46=\($(eval echo \\\${\${TL${E2}_44}\${TL${E2}_45}}) $(eval echo \\\${\${TL${E2}_44}\${TL${E2}_45}[1]})\)
eval \${TL${E2}_46} \${TL${E2}_46[1]}
# f[2]()
eval TL${E2}_47=\(\${!V${E2}G_f} $(eval echo \\\${\${V${E2}G_f}[1]})\)
eval TL${E2}_48=\(2 NUM\)
eval TL${E2}_49=\($(eval echo \\\${\${TL${E2}_47}\${TL${E2}_48}}) $(eval echo \\\${\${TL${E2}_47}\${TL${E2}_48}[1]})\)
eval \${TL${E2}_49} \${TL${E2}_49[1]}
```

## Complex expressions
```lua
print(({1,2,{42,3}})[3][({1,2})[2]])
```

translates to

```bash
ERG_2=("NUM" 'VAL_ERG_2')
VAL_ERG_2='2'
ATBL_3=("TBL" 'VAL_ATBL_3')
VAL_ATBL_3='ATBL_3'
ERG_4=("NUM" 'VAL_ERG_4')
VAL_ERG_4='1'
ATBL_3_1=("VAR" 'VAL_ATBL_3_1')
VAL_ATBL_3_1="${!ERG_4[1]}"
ERG_5=("NUM" 'VAL_ERG_5')
VAL_ERG_5='2'
ATBL_3_2=("VAR" 'VAL_ATBL_3_2')
VAL_ATBL_3_2="${!ERG_5[1]}"
ERG_6=("VAR" 'VAL_ERG_6')
VAL_ERG_6=''
eval ${ERG_6[1]}=\${!${!ATBL_3[1]}_${!ERG_2[1]}[1]}
ERG_7=("NUM" 'VAL_ERG_7')
VAL_ERG_7='3'
ATBL_8=("TBL" 'VAL_ATBL_8')
VAL_ATBL_8='ATBL_8'
ERG_9=("NUM" 'VAL_ERG_9')
VAL_ERG_9='1'
ATBL_8_1=("VAR" 'VAL_ATBL_8_1')
VAL_ATBL_8_1="${!ERG_9[1]}"
ERG_10=("NUM" 'VAL_ERG_10')
VAL_ERG_10='2'
ATBL_8_2=("VAR" 'VAL_ATBL_8_2')
VAL_ATBL_8_2="${!ERG_10[1]}"
ATBL_3_8=("TBL" 'VAL_ATBL_8')
VAL_ATBL_3_8='ATBL_8'
ERG_11=("NUM" 'VAL_ERG_11')
VAL_ERG_11='42'
ATBL_8_3_1=("VAR" 'VAL_ATBL_8_3_1')
VAL_ATBL_8_3_1="${!ERG_11[1]}"
ERG_12=("NUM" 'VAL_ERG_12')
VAL_ERG_12='3'
ATBL_8_3_2=("VAR" 'VAL_ATBL_8_3_2')
VAL_ATBL_8_3_2="${!ERG_12[1]}"
ERG_13=("VAR" 'VAL_ERG_13')
VAL_ERG_13=''
eval ${ERG_13[1]}=\${!${!ATBL_8[1]}_${!ERG_7[1]}_${!ERG_6[1]}[1]}
echo ${!ERG_13[1]}
```

which correctly evaluates to `3`

## Scoping

I tried to correctly implement luas scoping rules. However, I'm not 100% convinced yet, that I didn't miss something. Anyways, here some sample code that gets translated to sound bash code.

```lua
x = 3
do
    local x = 4
    local y = 1
    local y = 2
    print(x) -- must be 4
    print(y) -- must be 2
end

print(x) -- must be 3
print(y) -- must be nil
```

which translates to
```bash
ERG_3=("NUM" 'VAL_ERG_3')
VAL_ERG_3='3'
RHS_1=("VAR" 'RHS_1_VAL')
RHS_1_VAL="${!ERG_3[1]}"
VAR_G_x=("" 'VAL_DEF1_VAR_G_x')
VAL_DEF1_VAR_G_x="${!RHS_1[1]}"
# do
    ERG_6=("NUM" 'VAL_ERG_6')
    VAL_ERG_6='4'
    RHS_1=("VAR" 'RHS_1_VAL')
    RHS_1_VAL="${!ERG_6[1]}"
    VAR_G_Scope_4_x=("VAR" 'VAL_DEF1_VAR_G_Scope_4_x')
    VAL_DEF1_VAR_G_Scope_4_x="${!RHS_1[1]}"
    ERG_8=("NUM" 'VAL_ERG_8')
    VAL_ERG_8='1'
    RHS_1=("VAR" 'RHS_1_VAL')
    RHS_1_VAL="${!ERG_8[1]}"
    VAR_G_Scope_4_y=("VAR" 'VAL_DEF1_VAR_G_Scope_4_y')
    VAL_DEF1_VAR_G_Scope_4_y="${!RHS_1[1]}"
    ERG_10=("NUM" 'VAL_ERG_10')
    VAL_ERG_10='2'
    RHS_1=("VAR" 'RHS_1_VAL')
    RHS_1_VAL="${!ERG_10[1]}"
    VAL_DEF2_VAR_G_Scope_4_y="${!RHS_1[1]}"
    VAR_G_Scope_4_y[1]='VAL_DEF2_VAR_G_Scope_4_y'
    echo ${!VAR_G_Scope_4_x[1]}
    echo ${!VAR_G_Scope_4_y[1]}
# end
echo ${!VAR_G_x[1]}
echo ${!VAR_NIL[1]}
```

and correctly evaluates to `4\n2\n3\n\n`.

# Prerequisites

In order to be able to run lua2bash, you'll need the following items installed on your computer.

- lua
- luarocks
- the luarocks package `lua-parser`
