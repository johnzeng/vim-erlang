#!/bin/sh

for i in $@
do 
    echo "${i}:"
    diff ${i} ${i}.swp
done
