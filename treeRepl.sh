#!/bin/bash

while read i; do
    echo -- AST: --
    lua lua2tree.lua "$i"
done
