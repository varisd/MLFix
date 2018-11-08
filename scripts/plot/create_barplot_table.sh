#!/bin/bash

list=$1
file=$2
label_file="table.iset.labels"
out_file="table.iset"

tmp_dir=/tmp

for dir in `head -1 $list`; do
    cut -d $'\t' -f1 stats/$dir/$file | sort > $tmp_dir/file1.tmp
done

for dir in `cat $list`; do
    echo $dir
    sort -t $'\t' -k1 stats/${dir}/$file > $tmp_dir/file2.tmp
    join -t $'\t' $tmp_dir/file2.tmp $tmp_dir/file1.tmp -a2 > $tmp_dir/file3.tmp
    mv $tmp_dir/file3.tmp $tmp_dir/file1.tmp
done

cat $label_file > $out_file
cat $tmp_dir/file1.tmp | cut -d $'\t' -f1,3,5,7,9,11,13,15,17,19 | sort -t $'\t' -gr -k2 >> $out_file

cat $out_file | sed 's/ \t/\t/;s/ /\|/g;s/old_node_//g' > $tmp_dir/file1.tmp
mv $tmp_dir/file1.tmp $out_file
