#!/usr/bin/env perl

use strict;
use warnings;
use PerlIO::gzip;


my @columns = split /\|/, $ARGV[0];

my $feat_ignore = { "new_node_form" => 1, "new_node_lemma" => 1, "new_node_tag" => 1, "new_node_afun" => 1, "new_node_edgedirection" => 1, "new_node_childno" => 1, "new_node_lchildno" => 1, "new_node_rchildno" => 1 };

my $line = <STDIN>;
my @feature_names = split /\t/, $line;

while(<STDIN>) {
    $line = $_;

    my %features = ();
    @features{ @feature_names } = split /\t/, $line;

    my @cols = @columns;
    my $col = shift @cols;
    print $features{$col};
    for $col (@cols) {
        print "\t".$features{$col};
    }
    print "\n";
}
