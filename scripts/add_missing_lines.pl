#!/usr/bin/env perl

use strict;
use warnings;

binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

my $counter = 0;
while (<STDIN>) {
    my $line = $_;
    my ($lnumber) = split /\t/, $line;
    if ($lnumber - 1 == $counter) {
        print $line;
    }
    else {
        while ($lnumber - 1!= $counter) {
            print $counter + 1;
            print "\n";
            $counter = ($counter + 1) % 100;
        }
        print $line;
    }
    $counter = ($counter + 1) % 100;
}
