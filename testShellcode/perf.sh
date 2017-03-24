loopnum=1000
test = 'foo bar'

time for ((i=0; i<1000; i++)); do
    echo $test > /dev/null
done


time for ((i=0; i<1000; i++)); do
    eval echo $test > /dev/null
done

time for ((i=0; i<1000; i++)); do
    echo $(eval echo $test) > /dev/null
done
