# What?

Yes, this is a lua to BASH translator.
It takes lua code and gives you BASH code.

# Why?

Because BASH runs everywhere by default and lua is awesome.

# What is possible

Here a few things that work right now

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
