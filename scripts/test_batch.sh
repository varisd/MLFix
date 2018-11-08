#!/bin/bash

test_file=$1
output_dir=$2

# test models
for model_file in `ls models | grep "pkl$"`; do
    mem=30g
    output_file="${model_file/pkl/eval.out}"
    if [[ $model_file == extra_trees* || $model_file == random_forest* ]]; then mem=100g; fi
    ~bojar/tools/shell/qsubmit --mem=$mem "scripts/test_model.py models/$model_file $test_file > ${output_dir}/${output_file}"
    echo $output_file
done
