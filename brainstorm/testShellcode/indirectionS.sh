for ((i=0; i<100; i++)); do
# Begin of Scope: G 
if [ -z $E2 ]; then                                 # environment counter
    E2=0;                                           # environment counter
else                                                # environment counter
    ((E2++))                                        # environment counter
fi                                                  # environment counter
# a = {{1, 2}, {3, 4}} 
# {{1, 2}, {3, 4}} 
eval TB${E2}3=\(TB${E2}3 Table\) 
eval TB${E2}4=\(TB${E2}4 Table\) 
eval TL${E2}_5=\(1 NUM\) 
eval TB${E2}41=\(\${TL${E2}_5} \${TL${E2}_5[1]}\) 
eval TL${E2}_6=\(2 NUM\) 
eval TB${E2}42=\(\${TL${E2}_6} \${TL${E2}_6[1]}\) 
eval TB${E2}31=\(\${TB${E2}4} \${TB${E2}4[1]}\) 
eval TB${E2}7=\(TB${E2}7 Table\) 
eval TL${E2}_8=\(3 NUM\) 
eval TB${E2}71=\(\${TL${E2}_8} \${TL${E2}_8[1]}\) 
eval TL${E2}_9=\(4 NUM\) 
eval TB${E2}72=\(\${TL${E2}_9} \${TL${E2}_9[1]}\) 
eval TB${E2}32=\(\${TB${E2}7} \${TB${E2}7[1]}\) 
eval TL${E2}_10=\(\${TB${E2}3} \${TB${E2}3[1]}\) 
eval V${E2}G_a=LD1V${E2}G_a 
eval LD1V${E2}G_a=\(\${TL${E2}_10} \${TL${E2}_10[1]}\) 
# print(a[1][2]) 
eval TL${E2}_11=\(\${!V${E2}G_a} $(eval echo \\\${\${V${E2}G_a}[1]})\) 
eval TL${E2}_12=\(1 NUM\) 
eval TL${E2}_13=\($(eval echo \\\${\${TL${E2}_11}\${TL${E2}_12}}) $(eval echo \\\${\${TL${E2}_11}\${TL${E2}_12}[1]})\) 
eval TL${E2}_14=\(2 NUM\) 
eval TL${E2}_15=\($(eval echo \\\${\${TL${E2}_13}\${TL${E2}_14}}) $(eval echo \\\${\${TL${E2}_13}\${TL${E2}_14}[1]})\) 
eval echo \${TL${E2}_15} 
# a[1] = {42, 44} 
# {42, 44} 
eval TB${E2}16=\(TB${E2}16 Table\) 
eval TL${E2}_17=\(42 NUM\) 
eval TB${E2}161=\(\${TL${E2}_17} \${TL${E2}_17[1]}\) 
eval TL${E2}_18=\(44 NUM\) 
eval TB${E2}162=\(\${TL${E2}_18} \${TL${E2}_18[1]}\) 
eval TL${E2}_19=\(\${TB${E2}16} \${TB${E2}16[1]}\) 
eval TL${E2}_20=\(\${!V${E2}G_a} $(eval echo \\\${\${V${E2}G_a}[1]})\) 
eval TL${E2}_21=\(1 NUM\) 
eval $(eval echo \${TL${E2}_20}\${TL${E2}_21})=\(\${TL${E2}_19} \${TL${E2}_19[1]}\) 
# print(a[1][2]) 
eval TL${E2}_22=\(\${!V${E2}G_a} $(eval echo \\\${\${V${E2}G_a}[1]})\) 
eval TL${E2}_23=\(1 NUM\) 
eval TL${E2}_24=\($(eval echo \\\${\${TL${E2}_22}\${TL${E2}_23}}) $(eval echo \\\${\${TL${E2}_22}\${TL${E2}_23}[1]})\) 
eval TL${E2}_25=\(2 NUM\) 
eval TL${E2}_26=\($(eval echo \\\${\${TL${E2}_24}\${TL${E2}_25}}) $(eval echo \\\${\${TL${E2}_24}\${TL${E2}_25}[1]})\) 
eval echo \${TL${E2}_26} 
done
