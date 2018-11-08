#!/usr/bin/perl

use strict;
use warnings;
use utf8;

binmode STDOUT, ":utf8";

if ( @ARGV != 5 ) {
    die("Usage: $0 NEW1 NEW2 ORIG REF EN\n");
}

open (NEW1, "<:utf8", $ARGV[0]) or die;
open (NEW2, "<:utf8", $ARGV[1]) or die;
open (ORIG, "<:utf8", $ARGV[2]) or die;
open (REF, "<:utf8", $ARGV[3]) or die;
open (EN, "<:utf8", $ARGV[4]) or die;
my $counter = 0;
my $changed = 0;

while (<NEW1>) {
    my $new1 = $_;
    my $new2 = <NEW2>;
    my $orig = <ORIG>;
    my $ref = <REF>;
    my $en = <EN>;
    $orig =~ s/\s*$//;
    $new1 =~ s/\s*$//;
    $new1 =~ s/[„“]/"/g;
    $new2 =~ s/\s*$//;
    $new2 =~ s/[„“]/"/g;
    $ref =~ s/\s*$//;
    $en =~ s/\s*$//;
    $counter++;
    if ($new1 ne $new2) {
	$changed++;
        #mark changed words
        my @origWords = split / /, $orig;
        my @newWords1 = split / /, $new1;
        my @newWords2 = split / /, $new2;
        my $shift = 0;
        for (my $i = 0; $i < @newWords1; $i++) {
            if (!$newWords2[$i+$shift]) {
                next;
            }
            if ($newWords1[$i] ne $newWords2[$i+$shift]) {
                if ($newWords1[$i+1] && $newWords1[$i+1] eq $newWords2[$i+$shift]) { #word $i missing in @newWords2
                    $newWords1[$i] = "*$newWords1[$i]*";
                    $shift--;
                } elsif ($newWords2[$i+$shift+1] && $newWords1[$i] eq $newWords2[$i+$shift+1]) { #surplus word $i+$shift in @newWords2
                    $newWords2[$i+$shift] = "*$newWords2[$i+$shift]*";
                    $shift++;
                } else {
                    $newWords1[$i] = "*$newWords1[$i]*";
                    $newWords2[$i+$shift] = "*$newWords2[$i+$shift]*";
                }
            }
        }
        $orig = join ' ', @origWords;
        $new1 = join ' ', @newWords1;
        $new2 = join ' ', @newWords2;
        #print
#        print "$counter:\n{$ref}\n";
#        print "{$orig}\n";
#        print "{$new1}\n";
#        print "{$new2}\n";
#        print "{$en}\n\n";
        print "$counter:\nREF:  $ref\n";
        print "ORIG: $orig\n";
        print "NEW1: $new1\n";
        print "NEW2: $new2\n";
        print "SRC:  $en\n\n";
    }
}
close ORIG;
close NEW1;
close NEW2;
close REF;
close EN;

print "changed $changed sentences in total\n";
