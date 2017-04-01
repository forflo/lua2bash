#!/bin/bash

while read i; do
    echo -- compiled code: --
    lua lua2bash.lua "$i"
    echo -- result --
    eval "$(lua lua2bash.lua "$i")"
done
