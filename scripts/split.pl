#!/usr/bin/env perl

use strict;
use warnings;

my $ratio=$ARGV[0];
my $file=$ARGV[1];
my $out_train=$ARGV[2];
my $out_test=$ARGV[3];

open(my $fh, "<", $file) or die "Cannot open $file";

open(my $train_fh, ">", $out_train) or die "Cannot open $out_train";
open(my $test_fh, ">", $out_test) or die "Cannot open $out_test";

while(<$fh>) {
	my $line = $_;
	
	if(rand(1) > $ratio) { print $test_fh $line; }
	else { print $train_fh $line; }
}

close($fh);
close($train_fh);
close($test_fh);
