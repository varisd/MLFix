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

# experiment dir: must contain $input_file and $base_file
dir=$1

model=$2
base_params=$3
#m_params="max_features=0.45,n_estimators=50"
m_params="kernel=\"sigmoid\",C=1000"

# seq command generating all the parameter values
param_val_generator=$4
selector=""
selector=$5

#targets="new_node_number new_node_case"
#targets="new_node_gender new_node_number new_node_case"
#targets="new_node_gender new_node_animateness new_node_number new_node_case"
targets="wrong_form_3"
#targets="new_node_case"
#targets="new_node_pos new_node_prontype new_node_numtype new_node_numform new_node_numvalue new_node_adpostype new_node_conjtype new_node_poss new_node_reflex new_node_abbr new_node_hyph new_node_negativeness new_node_gender new_node_animateness new_node_number new_node_case new_node_prepcase new_node_degree new_node_person new_node_possgender new_node_possnumber new_node_verbform new_node_mood new_node_tense new_node_voice new_node_aspect new_node_variant new_node_style new_node_tagset new_node_other"

target_dir="tuning/wrong_form_3.srclemma.sel"
#target_dir="tuning/new_node_case.selector"
#target_dir="tuning/case_number"
#target_dir="tuning/case.srclemma"
#target_dir="tuning/cn.final"
#target_dir="tuning/cnga.final"
#target_dir="tuning/case.srclemma.sel"


echo $param_val_generator | grep -q "^seq" || die "Parameter \$4 must be a sequence generator"
values=`$4`

#input_file=${dir}/all_edits.tsv.gz
input_file=${dir}/all_edits2.tsv.gz
base_file=${dir}/base.wrong_form_3.tsv.gz
#base_file=${dir}/base.new_node_case.tsv.gz
#base_file=${dir}/base.case.tsv.gz
#base_file=${dir}/base.cn.tsv.gz
#base_file=${dir}/base.cng.tsv.gz
#base_file=${dir}/base.cnga.tsv.gz

[ -f ${input_file} ] || die "File $input_file does not exist."
[ -f ${base_file} ] || die "File $base_file does not exist."

(>&2 echo "$targets")

mkdir -p ${target_dir}/${dir}
for val in $values; do
    queue=`lowestQueue`
    model_name="${model}_${val}_${selector}"
    targets_str=$(echo "$targets" | tr ' ' '|')
    name="mlfix_tuning_${model}_${selector}"
    echo "predicting: $targets" > "${target_dir}/${dir}/${model_name}.results"
    #~bojar/tools/shell/qsubmit --mem=15g --priority="-200" --queue=$queue --jobname=${name} "scripts/scikit-cv-class.py --input_file=$input_file --base_file=$base_file --feat_selector=$selector --target='$targets_str' --model_type=$model --model_params='${base_params}${val}' | tee -a ${target_dir}/${dir}/${model_name}.results"
    ~bojar/tools/shell/qsubmit --mem=10g --priority="-200" --queue=$queue --jobname=${name} "scripts/scikit-cv-class.py --input_file=$input_file --base_file=$base_file --feat_selector=$selector --feat_selector_params='${base_params}${val}' --target='$targets_str' --model_type=$model --model_params='${m_params}' | tee -a ${target_dir}/${dir}/${model_name}.results"
    #~bojar/tools/shell/qsubmit --mem=15g --priority="-200" --queue=$queue --jobname=${name} "scripts/scikit-cv-class.py --input_file=$input_file --base_file=$base_file --feat_selector=$selector --target='$targets_str' --model_type=$model --model_params='${base_params},class_weight={ 1: ${val}}' | tee -a ${target_dir}/${dir}/${model_name}.results"
done

exit 








# train models
echo "Training..."
for val in $values; do
    model_name="${model}_${val}_${feat_ratio}"
	targets_str=$(echo $targets | tr ' ' '|')
    name="mlfix_tune_train_${model}_${feat_ratio}"
	~bojar/tools/shell/qsubmit --mem=30g --jobname=${name} "scripts/scikit-train.py $train_file '$targets_str' $model "${base_params}${val}" models/tuning/${model_name}.pkl" ${feat_ratio}
done

sleep 30
while true; do qstat -r | grep $name > /dev/null || break; sleep 100; done

# test models
echo "Testing..."
for val in $values; do
    model_name="${model}_${val}_${feat_ratio}"
    targets_str=$(echo $targets | tr ' ' '|')
    name="mlfix_tune_test_${model}_${feat_ratio}"
    ~bojar/tools/shell/qsubmit --mem=30g --jobname=${name} "scripts/test_model.py models/tuning/${model_name}.pkl $test_file 0 > ${out_dir}/${model_name}_eval.out"
done

sleep 30
while true; do qstat -r | grep $name > /dev/null || break; sleep 100; done

for val in $values; do
    model_name="${model}_${val}_${feat_ratio}"
    rm models/tuning/${model_name}.pkl*
done
    

if [ -f ${out_dir}/${model}_all.out ]; then rm ${out_dir}/${model}_all.out; fi
for f in `ls ${out_dir}/${model}_*_${feat_ratio}_eval.out`; do
    tail -1 $f >> ${out_dir}/${model}_${feat_ratio}_all.out
done
