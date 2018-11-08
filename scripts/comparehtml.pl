#!/usr/bin/perl

use strict;
use warnings;

binmode STDOUT, ":utf8";

if ( @ARGV != 4 ) {
    die("Usage: $0 NEW ORIG REF EN<br>");
}

open (NEW, "<:utf8", $ARGV[0]) or die;
open (ORIG, "<:utf8", $ARGV[1]) or die;
open (REF, "<:utf8", $ARGV[2]) or die;
open (EN, "<:utf8", $ARGV[3]) or die;
my $counter = 0;
my $changed = 0;

print '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
  <meta http-equiv="content-type" content="text/html; charset=utf-8">
  <title>cmp</title>
  </head>
  <body>';

while (<NEW>) {
    my $new = $_;
    my $orig = <ORIG>;
    my $ref = <REF>;
    my $en = <EN>;
    $orig =~ s/\s<b>$//;
    $new =~ s/\s<b>$//;
    $ref =~ s/\s<b>$//;
    $en =~ s/\s<b>$//;
    $counter++;
    if ($new ne $orig) {
	$changed++;
        #mark changed words
        my @origWords = split / /, $orig;
        my @newWords = split / /, $new;
        my $shift = 0;
        for (my $i = 0; $i < @newWords; $i++) {
            if (!$origWords[$i+$shift]) {
                next;
            }
            if ($newWords[$i] ne $origWords[$i+$shift]) {
                if ($newWords[$i+1] && $newWords[$i+1] eq $origWords[$i+$shift]) { #word $i missing in @origWords
                    $newWords[$i] = "<b>$newWords[$i]</b>";
                    $shift--;
                } elsif ($origWords[$i+$shift+1] && $newWords[$i] eq $origWords[$i+$shift+1]) { #surplus word $i+$shift in @origWords
                    $origWords[$i+$shift] = "<b>$origWords[$i+$shift]</b>";
                    $shift++;
                } else {
                    $newWords[$i] = "<b>$newWords[$i]</b>";
                    $origWords[$i+$shift] = "<b>$origWords[$i+$shift]</b>";
                }
            }
        }
        $orig = join ' ', @origWords;
        $new = join ' ', @newWords;
        #print
        print "<b>$counter</b>:<br>";
        print "<b>ORI</b>: $orig<br>";
        print "<b>NEW</b>: $new<br>";
        print "<b>EN</b>: $en<br>";
        print "<b>REF</b>: $ref<br><br>";
    }
}
close ORIG;
close NEW;
close REF;
close EN;

print "changed $changed sentences in total<br>";

print '</body>
</html>';
