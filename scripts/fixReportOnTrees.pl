#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

sub say {
    my $line = shift;
    print "$line\n";
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

my $count=0;
while (<>) {
    chomp;
    if (/<LM id="s(.{1,3})">/) {
        if ($count) {
            print "\n";
        }
        print ++$count;
        print ":";
    } elsif (/<sentence>({.+})<\/sentence>/) {
        my $log = $1;
        while ($log =~ /\{([^\}]+)\}/g) {
            my $fixLog = $1;
            if ($fixLog =~ /^(.+): (.+) -> (.+)$/) {
                my $fix = $1;
                my $from = $2;
                my $to = $3;
                print "$fix;";
            } else {
                print "$fixLog;";
            }
        }
    } #else not an interesting line
}

