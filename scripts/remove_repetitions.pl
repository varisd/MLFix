#!/usr/bin/env perl

use strict;
use warnings;
use PerlIO::gzip;

my %seen = ();

while(<STDIN>) {
    chomp;
    my $line = $_;
    if(!defined $seen{$line}) {
        print "$line\n";
        $seen{$line}++;
    }
    
}
