#!/bin/bash

root_dir=$1
files=`find ./$root_dir -name "*results" -print`

#echo "Filename: Instances Accuracy Precision Recall F1-Measure TruePos TrueNeg FalsePos FalseNeg WrongPos\n"
for f in $files; do
    grep "Final Evaluation" $f > /dev/null && echo "${f}:" `tail -1 $f`
    #echo "${f}:" `tail -1 $f`
done
