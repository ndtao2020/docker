#!/bin/sh

# create any intermediate directories that don't exist
mkdir -p $1

if [ ! -f "$2" ]; then
    cp $3 $2
else
    cp $2 $3
fi;
