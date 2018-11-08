#!/bin/sh


cat $1 | \
sed -e 's/{/{\n/g;s/}/\n}/g;s/\:\"\([^\:]*\)\",/:"\1",\n/g;s/:\([0-9]*\),/:\1,\n/g;s/\",\"/",\n"/g;s/},/},\n/g;s/\(\<span[^><]*>\)/\1\n/g;s/<\\\/span>/\n\<\\\/span\>/g;' | \
grep -ve "^\s*$" | \
#grep -v '<span' | \
#grep -v '<\\\/span>' | \
perl json_indent.pl
