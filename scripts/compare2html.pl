#!/usr/bin/perl

use strict;
use warnings;

binmode STDOUT, ":utf8";

if ( @ARGV != 5 ) {
    die("Usage: $0 NEW1 NEW2 ORIG REF EN<br>");
}

open (NEW1, "<:utf8", $ARGV[0]) or die;
open (NEW2, "<:utf8", $ARGV[1]) or die;
open (ORIG, "<:utf8", $ARGV[2]) or die;
open (REF, "<:utf8", $ARGV[3]) or die;
open (EN, "<:utf8", $ARGV[4]) or die;
my $counter = 0;
my $changed = 0;

print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
  <meta http-equiv="content-type" content="text/html; charset=utf-8">
  <title>cmp</title>
  </head>
  <body>';

while (<NEW1>) {
    my $new1 = $_;
    my $new2 = <NEW2>;
    my $orig = <ORIG>;
    my $ref = <REF>;
    my $en = <EN>;
    $orig =~ s/\s<b>$//;
    $new1 =~ s/\s<b>$//;
    $new2 =~ s/\s<b>$//;
    $ref =~ s/\s<b>$//;
    $en =~ s/\s<b>$//;
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
                    $newWords1[$i] = "<b>$newWords1[$i]</b>";
                    $shift--;
                } elsif ($newWords2[$i+$shift+1] && $newWords1[$i] eq $newWords2[$i+$shift+1]) { #surplus word $i+$shift in @newWords2
                    $newWords2[$i+$shift] = "<b>$newWords2[$i+$shift]</b>";
                    $shift++;
                } else {
                    $newWords1[$i] = "<b>$newWords1[$i]</b>";
                    $newWords2[$i+$shift] = "<b>$newWords2[$i+$shift]</b>";
                }
            }
        }
        $orig = join ' ', @origWords;
        $new1 = join ' ', @newWords1;
        $new2 = join ' ', @newWords2;
        #print
        print "<b>$counter</b>:<br><b>REF</b>: $ref<br>";
        print "<b>ORI</b>: $orig<br>";
        print "<b>NEW1</b>: $new1<br>";
        print "<b>NEW2</b>: $new2<br>";
        print "<b>EN</b>: $en<br><br>";
    }
}
close ORIG;
close NEW1;
close NEW2;
close REF;
close EN;

print "changed $changed sentences in total<br>";

print '</body>
</html>';
