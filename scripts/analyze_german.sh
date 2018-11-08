#!/bin/bash

infile=$1
outdir=$2
is_trg=${3:-0}

echo $is_trg >&2

filename=`basename -s .txt $infile`
mkdir -p /a/LRC_TMP/varis
#tmpdir=`mktemp -d --tmpdir='/a/LRC_TMP/varis/' 'wmt16.de_analysis.XXXXX'`
mkdir /a/LRC_TMP/varis/wmt16.de_analysis
tmpdir=/a/LRC_TMP/varis/wmt16.de_analysis
if [ $is_trg -ne 0 ]; then
    cat $infile | cut -f4 | perl -ne 'chomp $_; my @words = split / /, $_; print join "\n", map {$_ =~ s/\|.*$//; $_} @words; print "\n";' > $tmpdir/words.txt
else
    cat $infile | cut -f3 > $tmpdir/words.txt
fi
java -Xmx2G -classpath /home/mnovak/projects/wmt16-pronouns/tools/transition-1.30.jar is2.util.Split $tmpdir/words.txt > $tmpdir/words.conll
if [ $is_trg -ne 0 ]; then
    cp $tmpdir/words.conll $tmpdir/words.lemmas.conll
else
    java -Xmx2G -classpath /home/mnovak/projects/wmt16-pronouns/tools/transition-1.30.jar is2.lemmatizer2.Lemmatizer -test $tmpdir/words.conll -out $tmpdir/words.lemmas.conll -model /home/mnovak/projects/wmt16-pronouns/tools/models/lemma-ger-3.6.model
fi
java -Xmx5G -classpath /home/mnovak/projects/wmt16-pronouns/tools/transition-1.30.jar is2.transitionS2a.Parser -test $tmpdir/words.lemmas.conll -out $tmpdir/words_annot.conll -model /home/mnovak/projects/wmt16-pronouns/tools/pet-ger-S2a-40-0.25-0.1-2-2-ht4-hm4-kk0
if [ $is_trg -ne 0 ]; then
    cat $tmpdir/words_annot.conll | cut -f8 | grep -v "^$" | awk -F, 'BEGIN { FS = "\t"} {$9=$10;}1' OFS="\t" > $outdir/$filename.txt
else
    cat $tmpdir/words_annot.conll | awk -F, 'BEGIN { FS = "\t"} { $9=$10; }1' OFS="\t" > $outdir/$filename.conll
fi
#rm -rf $tmpdir
