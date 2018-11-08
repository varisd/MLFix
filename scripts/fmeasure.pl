#!/usr/bin/env perl

use strict;
use warnings;

my $beta = 0.5;

while(<>) {
    chomp;
    my $line = $_;
    my ($name, $n, $acc, $prec, $rec) = split / /, $line;
    my $score;
    if ($prec == 0 || $rec == 0) {
        $score = 0;
    }
    else {
        $score = (1 + $beta**2) * ($prec*$rec / (($beta**2 * $prec) + $rec));
    }
    print "$line $score\n";
}
