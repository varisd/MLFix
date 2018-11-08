#!/usr/bin/perl

use strict;
use warnings;

binmode STDOUT, ":utf8";

open (ORIG, "<:utf8", $ARGV[0]) or die;
open (NEW, "<:utf8", $ARGV[1]) or die;
open (REF, "<:utf8", $ARGV[2]) or die;
open (EN, "<:utf8", $ARGV[3]) or die;
my $counter = 0;
my $changed = 0;

while (<NEW>) {
    my $new = lc $_;
    my $orig = lc <ORIG>;
    my $ref = <REF>;
    my $en = <EN>;
    $orig =~ s/\s*$//;
    $new =~ s/\s*$//;
    $ref =~ s/\s*$//;
    $en =~ s/\s*$//;
    $orig =~ s/ ([[:punct:]])/$1/g;
    $orig =~ s/([„\(]) / $1/g;
    $counter++;
    if ($new ne $orig) {
	$changed++;
        #mark changed words
        my @origWords = split / /, $orig;
        my @newWords = split / /, $new;
        my $shift = 0;
        for (my $i = 0; $i < @origWords; $i++) {
            if (!$newWords[$i+$shift]) {
                next;
            }
            if ($origWords[$i] ne $newWords[$i+$shift]) {
                if ($origWords[$i+1] && $origWords[$i+1] eq $newWords[$i+$shift]) { #word $i missing in @newWords
                    $origWords[$i] = "*$origWords[$i]*";
                    $shift--;
                } elsif ($newWords[$i+$shift+1] && $origWords[$i] eq $newWords[$i+$shift+1]) { #surplus word $i+$shift in @newWords
                    $newWords[$i+$shift] = "*$newWords[$i+$shift]*";
                    $shift++;
                } else {
                    $origWords[$i] = "*$origWords[$i]*";
                    $newWords[$i+$shift] = "*$newWords[$i+$shift]*";
                }
            }
        }
        $orig = join ' ', @origWords;
        $new = join ' ', @newWords;

	#print
	print "$counter:\nREF: $ref\n";
	print "ORI: $orig\n";
	print "NEW: $new\n";
	print "EN: $en\n\n";
    }
}
close ORIG;
close NEW;
close REF;

print "Changed $changed sentences\n";
