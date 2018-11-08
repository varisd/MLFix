#!/usr/bin/env perl

use strict;
use warnings;
use PerlIO::gzip;

my $curr_sent_id = "";
my @sent = ();
my $keep = 0;

my $line = <STDIN>;
chomp $line;
my @feature_names = split /\t/, $line;
print "$line\n";

while(<STDIN>) {
    chomp;
    $line = $_;

    my %features = ();
    @features{ @feature_names } = split /\t/, $line;
    my $sent_id = $features{"old_node_id"};
    $sent_id =~ s/\-[^\-]*$//;

    if ($curr_sent_id ne $sent_id) {
        if ($keep == 1) {
            print join "\n", @sent;
            print "\n";
        }
        $keep = 0;
        $curr_sent_id = $sent_id;
        @sent = ();
    }

    push @sent, $line;

    if ($features{"wrong_form_3"} eq "1") {
        $keep = 1;
    }
}

if ($keep == 1) {
    print join "\n", @sent;
    print "\n";
}
