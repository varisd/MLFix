#!/bin/perl -w

use strict;

my $indent = 0;

while(<>) {
	my $line = $_;

	--$indent if $line =~ /<\\\/span/;
	--$indent if $line =~ /}/;
	for (my	$i = 0; $i < $indent; ++$i) {
		print "\t";
	}
	++$indent if $line =~ /<span/;
	++$indent if $line =~ /{/;

	print "$line";
}
