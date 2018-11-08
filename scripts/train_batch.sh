#!/bin/bash

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

# experiment dir: must contain $input_file and $base_file
dir=$1

model=$2
m_params=$3
selector=$4
sel_params=$5


targets="wrong_form_3"
#targets="new_node_case"
#targets="new_node_number new_node_case"
#targets="new_node_gender new_node_number new_node_case"
#targets="new_node_gender new_node_animateness new_node_number new_node_case"

target_dir="models/$dir"

#model_name="best.case.pkl"
#model_name="best.cn.pkl"
#model_name="best.cng.pkl"
#model_name="best.cnga.pkl"
model_name=best.wrong_form.pkl


#input_file=${dir}/all_edits.tsv.gz
#input_file=${dir}/all_edits_wrongonly.tsv.gz

#base_file=${dir}/base.new_node_case.tsv.gz
#base_file=${dir}/base.case.tsv.gz
#base_file=${dir}/base.cn.tsv.gz
#base_file=${dir}/base.cng.tsv.gz
#base_file=${dir}/base.cnga.tsv.gz

input_file=${dir}/all_edits2.tsv.gz
base_file=${dir}/base.wrong_form_3.tsv.gz

[ -f ${input_file} ] || die "File $input_file does not exist."
[ -f ${base_file} ] || die "File $base_file does not exist."

(>&2 echo "$targets")

mkdir -p "${target_dir}"

queue=`lowestQueue`
targets_str=$(echo "$targets" | tr ' ' '|')
jobName="mlfix_train_${model_name}_${model}_${selector}"

~bojar/tools/shell/qsubmit --mem=15g --priority="-100" --queue=$queue --jobname=${jobName} "scripts/scikit-cv-class.py --input_file=$input_file --base_file=$base_file --feat_selector=$selector --feat_selector_params='${sel_params}' --target='$targets_str' --model_type=$model --model_params='${m_params}' --save_model=${target_dir}/${model_name} | tee -a ${target_dir}/${jobName}.out"
