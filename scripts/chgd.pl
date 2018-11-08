#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use autodie;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

{
    # I want my arguments to be UTF-8
    use I18N::Langinfo qw(langinfo CODESET);
    use Encode qw(decode);
    my $codeset = langinfo(CODESET);
    @ARGV = map { decode $codeset, $_ } @ARGV;
}

if ( @ARGV != 2 ) {
    die("Usage: $0 file1 file2 \n");
}

my $count = 0;

open my $file1, '<:utf8', $ARGV[0];
open my $file2, '<:utf8', $ARGV[1];
while (<$file1>) {
    my $a = $_;
    my $b = <$file2>;
    $a =~ s/\r?\n?$//;
    $b =~ s/\r?\n?$//;
    $a =~ s/\s+$//;
    $b =~ s/\s+$//;

    if ( $a ne $b ) {
        $count++
    }
}

print "$count\n";

