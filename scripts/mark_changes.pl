#!/usr/bin/perl

use strict;
use warnings;

binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

my $counter = 0;
my $changed = 0;

while (<STDIN>) {
    my $src = $_;
    my $ref = <STDIN>;
    my $mt = <STDIN>;
    my $node = <STDIN>;
    my $parent = <STDIN>;
    my $empty = <STDIN>;
    $ref =~ s/\s*$//;
    $mt =~ s/\s*$//;
    $counter++;
    #if ($new ne $orig) {
    #$changed++;
        #mark changed words
        my @refWords = split / /, $ref;
        my @mtWords = split / /, $mt;
        my $shift = 0;
        for (my $i = 0; $i < @refWords; $i++) {
            if (!$mtWords[$i+$shift]) {
                next;
            }
            if ($refWords[$i] ne $mtWords[$i+$shift]) {
                if ($refWords[$i+1] && $refWords[$i+1] eq $mtWords[$i+$shift]) { #word $i missing in @mtWords
                    $refWords[$i] = "*$refWords[$i]*";
                    $shift--;
                } elsif ($mtWords[$i+$shift+1] && $refWords[$i] eq $mtWords[$i+$shift+1]) { #surplus word $i+$shift in @mtWords
                    $mtWords[$i+$shift] = "*$mtWords[$i+$shift]*";
                    $shift++;
                } else {
                    $refWords[$i] = "*$refWords[$i]*";
                    $mtWords[$i+$shift] = "*$mtWords[$i+$shift]*";
                }
            }
        }
        $ref = join ' ', @refWords;
        $mt = join ' ', @mtWords;

	#print
	print "$src";
	print "$ref\n";
	print "$mt\n";
	print "$node";
    print "$parent\n";
#    }
}
close ORIG;
close NEW;
close REF;

print "Changed $changed sentences\n";
