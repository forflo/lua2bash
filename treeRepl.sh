#!/bin/bash

while read i; do
    echo -- AST: --
    lua source/lua2tree.lua "$i"
done
