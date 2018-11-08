#!/bin/bash

dir=data


mkdir -p /a/LRC_TMP/varis/mlfix/split_data
script_dir=/a/merkur3/varis/workdir-git/mlfix/scripts

src=$1
mt=$2
pe=$3
prefix=$4

echo 

tmp_dir=`mktemp -d --tmpdir=/a/LRC_TMP/varis/mlfix/split_data`

paste $src $mt $pe > $tmp_dir/all.txt
perl $script_dir/split.pl 0.9 $tmp_dir/all.txt $tmp_dir/train $tmp_dir/test

cut -f1 $tmp_dir/train > $dir/${prefix}_train_src.txt
cut -f2 $tmp_dir/train > $dir/${prefix}_train_mt.txt
cut -f3 $tmp_dir/train > $dir/${prefix}_train_pe.txt
cut -f1 $tmp_dir/test > $dir/${prefix}_test_src.txt
cut -f2 $tmp_dir/test > $dir/${prefix}_test_mt.txt
cut -f3 $tmp_dir/test > $dir/${prefix}_test_pe.txt
