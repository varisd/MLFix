#!/bin/bash

train_file=$1
#file_test=$2

#targets="new_node_number new_node_gender"
targets="new_node_pos new_node_prontype new_node_numtype new_node_numform new_node_numvalue new_node_adpostype new_node_conjtype new_node_poss new_node_reflex new_node_abbr new_node_hyph new_node_negativeness new_node_gender new_node_animateness new_node_number new_node_case new_node_prepcase new_node_degree new_node_person new_node_possgender new_node_possnumber new_node_verbform new_node_mood new_node_tense new_node_voice new_node_aspect new_node_variant new_node_style new_node_tagset new_node_other"

# train models
while read p; do
	param1=$(echo $p | cut -d" " -f1)
	param2=$(echo $p | cut -d" " -f2)
	param3=$(echo $p | cut -d" " -f3)
	model_file="models/${param3}_combined.pkl"
	targets_str=$(echo $targets | tr ' ' '|')
	~bojar/tools/shell/qsubmit --mem=30g "scripts/scikit-train.py $train_file '$targets_str' $param1 $param2 $model_file"

	continue

	for target in $targets; do
		model_file="models/${param3}_${target}.gz"
		~bojar/tools/shell/qsubmit --mem=30g "scripts/scikit-train.py $train_file $target $param1 $param2 $model_file"
	done
done <config/model_params
