#!/usr/bin/env perl

use strict;
use warnings;

my $threshold = 0.05;

while(<>) {
    chomp;
    my ($src, $mt, $ref) = split /\t/;

    my $mt_hash = bag_of_words($mt);
    my $ref_hash = bag_of_words($ref);

    my $src_new = join (" ", map { $_ =~ s/\|.*$//; $_ } (split / /, $src));
    my $mt_new = join (" ", map { $_ =~ s/\|.*$//; $_ } (split / /, $mt));
    my $ref_new = join (" ", map { $_ =~ s/\|.*$//; $_ } (split / /, $ref));

    my $res = cross_prod($mt_hash, $ref_hash) / (vec_length($mt_hash) * vec_length($ref_hash));
    print "$src_new\t$mt_new\t$ref_new\n" if ($res > $threshold);
}

# sent format: word1|lemma1 word2|lemma2 ...
sub bag_of_words {
    my ($sent) = @_;
    my %hash = ();

    foreach my $token (split / /, $sent) {
        my ($form, $lemma) = split /|/, $token;
        $hash{$lemma}++;
    }
    return \%hash;
}

sub vec_length {
    my ($hash) = @_;
    my $res = 0;
    foreach my $key (keys %$hash) { $res += $hash->{$key} * $hash->{$key}; }
    return $res;
}

sub cross_prod {
    my ($hash1, $hash2) = @_;
    my $res = 0;

    foreach my $key (keys %$hash1) {
        next if (!defined $hash2->{$key});
        $res += $hash1->{$key} * $hash2->{$key};
    }

    return $res;
}

