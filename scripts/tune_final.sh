#!/bin/bash

#scripts/tune_batch.sh test_dir knn "n_neighbors=" "seq 0 20"

## CHECK THESE VARIABLES ##
# targets - what to predict
# target_dir - where to store the eval results
# input_file - leave it be (most of the time)
# base_file - baseline predictions
# sel/selector - switch if needed

function die() {
    echo $1
    exit
}

mem=5g

# experiment dir: must contain $input_file and $base_file
dir=$1

model=$2
m_params=$3
selector=$4
sel_params=$5

# seq command generating all the parameter values
m_val_generator=$6
sel_val_generator=$7

#targets="new_node_number new_node_gender"
targets="wrong_form_3"
#targets="new_node_case"
#targets="new_node_number new_node_case"
#targets="new_node_gender new_node_number new_node_case"
#targets="new_node_gender new_node_animateness new_node_number new_node_case"

#target_dir="tuning/wrong_form_3.final"
#target_dir="tuning/case.final"
#target_dir="tuning/cn.final"
#target_dir="tuning/cng.final"
#target_dir="tuning/cnga.final"

target_dir="tuning/german.wf.final"

echo $m_val_generator | grep -q "^seq" || die "Parameter \$6 must be a sequence generator"
m_values=`$6`

echo $sel_val_generator | grep -q "^seq" || die "Parameter \$7 must be a sequence generator"
sel_values=`$7`
#sel_values=$7

#input_file=${dir}/all_edits.tsv.gz

#input_file=${dir}/all_edits_wrongonly.tsv.gz
#input_file=${dir}/all_edits_dropped.tsv.gz
#base_file=${dir}/base.case.tsv.gz
#base_file=${dir}/base.new_node_case.tsv.gz
#base_file=${dir}/base.cn.tsv.gz
#base_file=${dir}/base.cng.tsv.gz
#base_file=${dir}/base.cnga.tsv.gz

#input_file=${dir}/all_edits_dropped.tsv.gz
input_file=${dir}/all_edits2.tsv.gz
base_file=${dir}/base.wrong_form_3.tsv.gz

[ -f ${input_file} ] || die "File $input_file does not exist."
[ -f ${base_file} ] || die "File $base_file does not exist."

(>&2 echo "$targets")

mkdir -p ${target_dir}/${dir}
for mval in $m_values; do
    for sval in $sel_values; do
        for fval in `seq 0.05 0.1 1.0`; do
        queue=`lowestQueue`
        model_name="${model}_${mval}_${fval}_${selector}_${sval}"
        targets_str=$(echo "$targets" | tr ' ' '|')
        name="mlfix_tuning_${model}_${selector}"
        echo "predicting: $targets" > "${target_dir}/${dir}/${model_name}.results"
        #~bojar/tools/shell/qsubmit --mem=${mem} --priority="-200" --queue=$queue --jobname=${name} "scripts/scikit-cv-class.py --input_file=$input_file --base_file=$base_file --feat_selector=$selector --feat_selector_params='${sel_params}${sval}' --target='$targets_str' --model_type=$model --model_params='max_features=${fval},${m_params}${mval}' | tee -a ${target_dir}/${dir}/${model_name}.results"
        #~bojar/tools/shell/qsubmit --mem=${mem} --priority="-200" --queue=$queue --jobname=${name} "scripts/scikit-cv-class.py --input_file=$input_file --base_file=$base_file --feat_selector=$selector --feat_selector_params='max_features=${fval},${sel_params}${sval}' --target='$targets_str' --model_type=$model --model_params='${m_params}${mval}' | tee -a ${target_dir}/${dir}/${model_name}.results"
        #~bojar/tools/shell/qsubmit --mem=5g --priority="-200" --queue=$queue --jobname=${name} "scripts/scikit-cv-class.py --input_file=$input_file --base_file=$base_file --target='$targets_str' --model_type=$model --model_params='${m_params}${mval}' | tee -a ${target_dir}/${dir}/${model_name}.results"
        done
        ~bojar/tools/shell/qsubmit --mem=5g --priority="-200" --queue=$queue --jobname=${name} "scripts/scikit-cv-class.py --input_file=$input_file --base_file=$base_file --target='$targets_str' --feat_selector=$selector --feat_selector_params='${sel_params}${sval}' --model_type=$model --model_params='${m_params}${mval}' | tee -a ${target_dir}/${dir}/${model_name}.results"
    done
done

exit 
