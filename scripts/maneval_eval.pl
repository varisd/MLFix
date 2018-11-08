#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

sub tsvsay {
    my (@output) = @_;
    for my $text (@output) {
        print $text;
        print "\t";
    }
    #my $text;
    #while ($text = shift) {
    #    print $text;
    #    print "\t";
    #}
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
my $okchar = '*';

print STDERR "Will process $fileprefix.out to compare $fixes_total fixes. The ok-char is '$okchar'.\n";

#
# PROCESS THE FILE
#

my %scores;
$scores{'BASE'} = 0;
$scores{'OUR'}  = 0;

open my $fileOut, '<:utf8', "$fileprefix.out" or die("Cannot open file $fileprefix.out!");

while (<$fileOut>) {
    if (/^([0-9]+)\t.*(OUR|BASE).*\t(.)$/) {
        my $lineNo = $1;
        my $set = $2;
        my $evalChar = $3;
        if ($evalChar eq $okchar) {
            $scores{$set}++;
        }
    }
}
close $fileOut;

if ($scores{'BASE'} + $scores{'OUR'} > 0) {
    my $indefinite = $fixes_total - $scores{'BASE'} - $scores{'OUR'};
    my $ourPercent1 = 100*$scores{'OUR'}/($scores{'BASE'}+$scores{'OUR'});
    my $ourPercent2 = 100*$scores{'OUR'}/($scores{'BASE'}+$scores{'OUR'}+$indefinite);
    print STDERR "$indefinite\n";

    tsvsay ($fileprefix, $fixes_total, $scores{'BASE'}, $scores{'OUR'}, $indefinite, $ourPercent1, $ourPercent2 );
}
else {
    print STDERR "No anots in $fileprefix.out.\n";    
}

