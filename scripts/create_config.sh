#!/bin/bash

targets=$(echo $1 | tr "|" ".")  # predicted categories, separated by '|'
dataset_list=$2
#model_name="${model_file/.pkl/}"
#config_file="${model_file/pkl/yaml}"


for dir in `cat $dataset_list`; do
    config_all=config/${dir}/${targets}_all.yaml
    config_only=config/${dir}/${targets}_only.yaml
    config_omitted=config/${dir}/${targets}_omitted.yaml

    mkdir -p config/${dir}/
    echo "fields:" > $config_all
    cat config/fields.template >> $config_all
    echo "" >> $config_all
    
    echo "features:" >> $config_all
    cat config/features.template >> $config_all
    echo "" >> $config_all

    echo "predict:" >> $config_all
    for tar in `echo $targets | tr "." "\n"`; do
        echo "- $tar" >> $config_all
    done
    echo "" >> $config_all

    echo "models:" >> $config_all

    cp $config_all $config_only
    cp $config_all $config_omitted

    cat $dataset_list | sed "s/^\(.*\)$/\t\1: \1\/$targets\/best.pkl/" >> $config_all
    cat $dataset_list | sed "s/^\(.*\)$/\t\1: \1\/$targets\/best.pkl/" | grep $dir >> $config_only
    cat $dataset_list | sed "s/^\(.*\)$/\t\1: \1\/$targets\/best.pkl/" | grep -v $dir >> $config_omitted
done

exit

echo "fields:" > config/models/$config_file
cat config/fields.template >> config/models/$config_file
echo "" >> config/models/$config_file
echo "features:" >> config/models/$config_file
cat config/features.template >> config/models/$config_file
echo "" >> config/models/$config_file
echo "predict:" >> config/models/$config_file
cat config/predict.template >> config/models/$config_file
echo "" >> config/models/$config_file
echo "models:" >> config/models/$config_file
echo "	${model_name}: ${model_file}" >> config/models/$config_file
