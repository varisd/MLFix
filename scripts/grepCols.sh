#!/bin/bash

columns=$(zcat -f $2 | head -1 | tr "\t" "\n" | grep -En "($1)" | cut -d: -f1 | tr "\n" "," | sed 's/,$//')

zcat -f $2 | cut -f$columns
