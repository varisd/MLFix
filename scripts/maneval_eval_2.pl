#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

sub tsvsay {
    my $text;
    while ($text = shift) {
        print $text;
        print "\t";
    }
    print "\n";
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

#
# SETTINGS
#

my $fileprefix = $ARGV[0];
my $fixes_total = $ARGV[1];
#my $lines_total = $ARGV[2];
my $okchar = 'a';

print STDERR "Will process $fileprefix.out to compare $fixes_total fixes. The ok-char is '$okchar'.\n";

#
# PROCESS THE FILE
#

my %scores;
my %lines;

open my $fileOut, '<:utf8', "$fileprefix.out" or die("Cannot open file $fileprefix.out!");

my $a = 0;
while (<$fileOut>) {
    if (/^([0-9]+)\t.*(OUR1|OUR2|BASE).*\t(.)$/) {
        my $lineNo = $1;
        my $set = $2;
        my $evalChar = $3;
        if ($evalChar eq $okchar) {
            $scores{$set}++;
            $lines{$lineNo}++;
	    $a++;
        } else {
	    die "incorrect ok char";
	}
    } else {
	if ($a) {
	    if ($a == 3) {
		die "all lines have an 'a'!!!";
	    }
	    $a = 0;
	}
    }
}
close $fileOut;

#my $indefinite = $fixes_total - $scores{'BASE'} - $scores{'OUR1'} - $scores{'OUR2'};
#my $our1Percent1 = 100*$scores{'OUR1'}/($scores{'BASE'}+$scores{'OUR1'});
#my $our1Percent2 = 100*$scores{'OUR1'}/($scores{'BASE'}+$scores{'OUR1'}+$indefinite);
#my $our2Percent1 = 100*$scores{'OUR2'}/($scores{'BASE'}+$scores{'OUR2'});
#my $our2Percent2 = 100*$scores{'OUR2'}/($scores{'BASE'}+$scores{'OUR2'}+$indefinite);

my $notIndef = keys %lines;
my $indef = $fixes_total - $notIndef;

tsvsay ($fileprefix, $fixes_total, $scores{'BASE'}, $scores{'OUR1'}, $scores{'OUR2'}, $indef );
#tsvsay ($fileprefix, $fixes_total, $scores{'BASE'}, $scores{'OUR'}, $indefinite, $ourPercent1, $ourPercent2 );
