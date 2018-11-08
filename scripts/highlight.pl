#!/usr/bin/perl

use strict;
use warnings;

binmode STDOUT, ":utf8";

open (ORIG, "<:utf8", $ARGV[0]) or die;
open (NEW, "<:utf8", $ARGV[1]) or die;
open (ORIG_OUT, ">:utf8", $ARGV[2]) or die;
open (NEW_OUT, ">:utf8", $ARGV[3]) or die;

while (<NEW>) {
    my $new = $_;
    my $orig = <ORIG>;
    $orig =~ s/\s*$//;
    $new =~ s/\s*$//;
    
    if ($new ne $orig) {
        #mark changed words
        my @origWords = split / /, $orig;
        my @newWords = split / /, $new;
        my $shift = 0;
        for (my $i = 0; $i < @origWords; $i++) {
            if (!$newWords[$i+$shift]) {
                next;
            }
            if ($origWords[$i] ne $newWords[$i+$shift]) {
                my $sh = 1;
                my $found = 0;
                while ($sh <= 3 && $found == 0) {
                    if ($origWords[$i+$sh] && $origWords[$i+$sh] eq $newWords[$i+$shift]) { #word $i missing in @newWords
                        $origWords[$i] = "*$origWords[$i]";
                        $origWords[$i+$sh-1] = "$origWords[$i+$sh-1]*";
                        $shift-=$sh;
                        $found = 1;
                    } elsif ($newWords[$i+$shift+$sh] && $origWords[$i] eq $newWords[$i+$shift+$sh]) { #surplus word $i+$shift in @newWords
                        $newWords[$i+$shift] = "*$newWords[$i+$shift]";
                        $newWords[$i+$shift+$sh-1] =
                        "$newWords[$i+$shift+$sh-1]*";
                        $shift+=$sh;
                        $found = 1;
                    }
                    $sh++;
                }
                if ($found == 0) {
                    $origWords[$i] = "*$origWords[$i]*";
                    $newWords[$i+$shift] = "*$newWords[$i+$shift]*";
                }
            }
        }
        $orig = join ' ', @origWords;
        $new = join ' ', @newWords;
    }
    print ORIG_OUT "$orig\n";
    print NEW_OUT "$new\n";
}

close ORIG;
close NEW;
close ORIG_OUT;
close NEW_OUT;
