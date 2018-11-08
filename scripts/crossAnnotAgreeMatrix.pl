#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

sub tsvsay {
    foreach (@_) {
        print $_;
        print "\t";
    }
    print "\n";
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my $okchar = '*';

my %lines;

my $fixes_total = $ARGV[2];

my %anot1;
open my $anot1file, '<:utf8', $ARGV[0] or die("Cannot open anot1 file!");
while (<$anot1file>) {
    chomp;
    if (/^([0-9]+)\t.*(OUR|BASE).*\t(.)$/) {
        my $lineNo = $1;
        my $set = $2;
        my $evalChar = $3;
        if ($evalChar eq $okchar) {
            $anot1{$lineNo} = $set;
            $lines{$lineNo}++;
        }
    }
}
close $anot1file;

my %anot2;
open my $anot2file, '<:utf8', $ARGV[1] or die("Cannot open anot2 file!");
while (<$anot2file>) {
    chomp;
    if (/^([0-9]+)\t.*(OUR|BASE).*\t(.)$/) {
        my $lineNo = $1;
        my $set = $2;
        my $evalChar = $3;
        if ($evalChar eq $okchar) {
            $anot2{$lineNo} = $set;
            $lines{$lineNo}++;
        }
    }
}
close $anot2file;

my %IAA;
#G = good (we improved the results)
#B = bad (we worsened the results)
#I = indefinite (cannot be judged)
$IAA{'GG'} = 0;
$IAA{'GB'} = 0;
$IAA{'GI'} = 0;
$IAA{'BG'} = 0;
$IAA{'BB'} = 0;
$IAA{'BI'} = 0;
$IAA{'IG'} = 0;
$IAA{'IB'} = 0;
$IAA{'II'} = 0;

foreach my $lineNo (keys %lines) {
    my $anot1char;
    my $anot2char;
    if ($lines{$lineNo} == 2) { #both have an opinion
        if ($anot1{$lineNo} eq 'OUR') {
            $anot1char = 'G';
        } else { #'BASE'
            $anot1char = 'B';
        }
        if ($anot2{$lineNo} eq 'OUR') {
            $anot2char = 'G';
        } else { #'BASE'
            $anot2char = 'B';
        }
    } else { #one of them cannot decide
        if ($anot1{$lineNo}) {
            $anot2char = 'I';
            if ($anot1{$lineNo} eq 'OUR') {
                $anot1char = 'G';
            } else { #'BASE'
                $anot1char = 'B';
            }
        } else { # $anot2{$lineNo}
            $anot1char = 'I';
            if ($anot2{$lineNo} eq 'OUR') {
                $anot2char = 'G';
            } else { #'BASE'
                $anot2char = 'B';
            }
        }
    }
    $IAA{$anot1char.$anot2char}++;
}
#sentences missing in both anots (noone could decide) - this is what is missing in the data
$IAA{'II'} = $fixes_total - ($IAA{'GG'} + $IAA{'GB'} + $IAA{'GI'} + $IAA{'BG'} + $IAA{'BB'} + $IAA{'BI'} + $IAA{'IG'} + $IAA{'IB'});

tsvsay ('A/B', 'improved', 'worsened', 'indefinite');
tsvsay ('improved', $IAA{'GG'}, $IAA{'GB'}, $IAA{'GI'});
tsvsay ('worsened', $IAA{'BG'}, $IAA{'BB'}, $IAA{'BI'});
tsvsay ('indefinite', $IAA{'IG'}, $IAA{'IB'}, $IAA{'II'});
