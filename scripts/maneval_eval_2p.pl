#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

sub tsvsay {
    my $text = join "\t", @_;
    print "$text\n";
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
my $nokchar = 'n';

print STDERR "Will process $fileprefix.out to compare $fixes_total fixes. The ok-char is '$okchar'.\n";

#
# PROCESS THE FILE
#

my %scores;
my %lines;

my $beat={};
for my $set1 ('OUR1', 'OUR2', 'BASE') {
    for my $set2 ('OUR1', 'OUR2', 'BASE') {
	if ($set1 ne $set2) {
	    $beat->{$set1}->{$set2} = 0;
	}
    }
}

open my $fileOut, '<:utf8', "$fileprefix.out2p" or die("Cannot open file $fileprefix.out!");

my $a = 0;

my %results;
$results{'BASE'} = 'n';
$results{'OUR1'} = 'n';
$results{'OUR2'} = 'n';

my $oldLineNo = -1;
while (<$fileOut>) {
    if (/^([0-9]+)\t.*(OUR1|OUR2|BASE).*\t(.)$/) {
        my $lineNo = $1;
        my $set = $2;
        my $evalChar = $3;

	if ($oldLineNo ne $lineNo) {
	    # get pairwise results
	    for my $set1 ('OUR1', 'OUR2', 'BASE') {
		for my $set2 ('OUR1', 'OUR2', 'BASE') {
		    if ($set1 ne $set2) {
			if ($results{$set1} eq 'a' && $results{$set2} eq 'n') {
			    $beat->{$set1}->{$set2}++ ;
			}
		    }
		}
	    }
	    # reinit
	    $results{'BASE'} = 'n';
	    $results{'OUR1'} = 'n';
	    $results{'OUR2'} = 'n';
	    $oldLineNo = $lineNo;
	}

        if ($evalChar eq $okchar) {
            $scores{$set}++;
            $lines{$lineNo}++;
	    $a++;
	    $results{$set} = 'a';
        }
	elsif ($evalChar eq $nokchar) {
	    $results{$set} = 'n';
        }
	else {
	    die "incorrect ok char";
	}
    } else {
	die "incorrect line format";
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

tsvsay ('Beats', 'Beaten', 'times');
for my $set1 ('OUR1', 'OUR2', 'BASE') {
    for my $set2 ('OUR1', 'OUR2', 'BASE') {
	if ($set1 ne $set2) {
	    tsvsay ($set1, $set2, $beat->{$set1}->{$set2});
	}
    }
}
