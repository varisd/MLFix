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
    my $new = $_;
    my $orig = <ORIG>;
    my $ref = <REF>;
    my $en = <EN>;
    $orig =~ s/\s*$//;
    $new =~ s/\s*$//;
    $ref =~ s/\s*$//;
    $en =~ s/\s*$//;
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
                    $origWords[$i] = "\\textbf{$origWords[$i]}";
                    $shift--;
                } elsif ($newWords[$i+$shift+1] && $origWords[$i] eq $newWords[$i+$shift+1]) { #surplus word $i+$shift in @newWords
                    $newWords[$i+$shift] = "\\textbf{$newWords[$i+$shift]}";
                    $shift++;
                } else {
                    $origWords[$i] = "\\textbf{$origWords[$i]}";
                    $newWords[$i+$shift] = "\\textbf{$newWords[$i+$shift]}";
                }
            }
        }
        $orig = join ' ', @origWords;
        $new = join ' ', @newWords;

	#print
	print "\%$counter:\n";
	print "\\Ex{\n";
	print "\\ExSRC{$en}\n\\hline\n";
	print "\\ExSMT{$orig}\n\\hline\n";
	print "\\ExDEP{$new}\n\\hline\n";
	print "\\ExREF{$ref}\n";
	print "}{wmt11:$counter}\n\n";
    }
}
close ORIG;
close NEW;
close REF;

print "Changed $changed sentences\n";
