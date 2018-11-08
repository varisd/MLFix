#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

sub tsvsay {
    my $line = join "\t", @_;
    print "$line\n";
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my $okchar = '*';

my %lines;

my $fixes_total = $ARGV[2];
exit if $fixes_total == 0;

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

my $agree_our = 0;
my $agree_base = 0;
my $agree_indef = 0;
my $disagree_strict = 0;
my $disagree_indef = 0;

foreach my $lineNo (keys %lines) {
    print STDERR $lines{$lineNo} . "\n";
    if ($lines{$lineNo} == 2) { #both have an opinion
        if ($anot1{$lineNo} eq $anot2{$lineNo}) {
            if ($anot1{$lineNo} eq 'OUR') {
                $agree_our++;
            } else {
                $agree_base++;
            }
        } else {
            $disagree_strict++;
            
        }
    } else { #one of them cannot decide
        $disagree_indef++;
    }
}
#sentences missing in both anots (noone could decide)
$agree_indef = $fixes_total - ($agree_our + $agree_base + $disagree_strict + $disagree_indef);

print STDERR "$agree_our + $agree_base + $disagree_strict\n";

#count total agreement
my $agree = $agree_our + $agree_base + $agree_indef;
my $disagree = $disagree_strict + $disagree_indef;
my $agreePercent = 100*$agree/$fixes_total;
my $agreePercentStrict = 100*($agree_our + $agree_base)/($agree_our + $agree_base + $disagree_strict);

#filename1\tfilename2\tagree\tdisagree\tagree_percent\tagree_our\tagree_base\tagree_indef\tdisagree_strict\tdisagree_indef\tagree_percent_strict
tsvsay ($ARGV[0], $ARGV[1], $agree, $disagree, $agreePercent, $agree_our, $agree_base, $agree_indef, $disagree_strict, $disagree_indef, $agreePercentStrict);
