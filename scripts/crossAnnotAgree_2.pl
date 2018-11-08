#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

sub tsvsay {
    my $text;
    while (defined ($text = shift)) {
        print $text;
        print "\t";
    }
    print "\n";
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my $okchar = 'a';

my %lines;

my $fixes_total = $ARGV[2];

my %anot1;
open my $anot1file, '<:utf8', $ARGV[0] or die("Cannot open anot1 file!");
while (<$anot1file>) {
    chomp;
    if (/^([0-9]+)\t.*(OUR1|OUR2|BASE).*\t(.)$/) {
        my $lineNo = $1;
        my $set = $2;
        my $evalChar = $3;
        if ($evalChar eq $okchar) {
            $anot1{$lineNo}->{$set} = 1;
            $lines{$lineNo}++;
        }
    }
}
close $anot1file;

my %anot2;
open my $anot2file, '<:utf8', $ARGV[1] or die("Cannot open anot2 file!");
while (<$anot2file>) {
    chomp;
    if (/^([0-9]+)\t.*(OUR1|OUR2|BASE).*\t(.)$/) {
        my $lineNo = $1;
        my $set = $2;
        my $evalChar = $3;
        if ($evalChar eq $okchar) {
            $anot2{$lineNo}->{$set} = 1;
            $lines{$lineNo}++;
        }
    }
}
close $anot2file;

my %agree;

$agree{3} = 0;
$agree{2} = 0;
$agree{1} = 0;
$agree{0} = 0;

my $undecidable = 0;

my @sets = ('BASE', 'OUR1', 'OUR2');
foreach my $lineNo (keys %lines) {
    my $line_agree = 3; # 0, 1, 2 or 3
    my $a1 = 0;
    my $a2 = 0;
    foreach my $set (@sets) {
	my $set_agree = 0;
	if ($anot1{$lineNo}->{$set}) {
	    $set_agree++;
	    $a1++;
	}
	if ($anot2{$lineNo}->{$set}) {
	    $set_agree++;
	    $a2++;
	}
	if ($set_agree == 1) {
	    # one had 'a' and the other one did not
	    # = they did not agree on this line
	    $line_agree--;
	}
    }
    if ($a1 && $a2) {
	# both definite
	$agree{$line_agree}++;
    } else {
	# one of them indefinite
	$undecidable++;
    }
}


# does not occur in any of the files = nobody marked anything
my $both_indef = $fixes_total - (keys %lines);

#$agree{3} += $both_indef;

#3/3\t2/3\t1/3\t0/3
tsvsay($agree{3}, $agree{2}, $agree{1}, $agree{0}, $both_indef, $undecidable);

#filename1\tfilename2\tagree\tdisagree\tagree_percent\tagree_our\tagree_base\tagree_indef\tdisagree_strict\tdisagree_indef\tagree_percent_strict
#tsvsay ($ARGV[0], $ARGV[1], $agree, $disagree, $agreePercent, $agree_our, $agree_base, $agree_indef, $disagree_strict, $disagree_indef, $agreePercentStrict);
