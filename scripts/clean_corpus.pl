#!/usr/bin/perl

# This script gets two parallel files and deletes such lines that are empty in one of the files

use strict;
use warnings;

open(IN1, "<:utf8", $ARGV[0]) or die;
open(IN2, "<:utf8", $ARGV[1]) or die;
open(OUT1, ">:utf8", $ARGV[2]) or die;
open(OUT2, ">:utf8", $ARGV[3]) or die;

my $deleted = 0;

while(<IN1>) {
    my $in1 = $_;
    my $in2 = <IN2>;
    chomp $in1;
    chomp $in2;
    $in1 =~ s/^\s*//;
    $in2 =~ s/^\s*//;
    if ($in1 && $in2) {
        print OUT1 "$in1\n";
        print OUT2 "$in2\n";
    }
    else {
        $deleted++;
    }
}

close IN1;
close IN2;
close OUT1;
close OUT2;

print STDERR "$deleted lines was deleted\n";
