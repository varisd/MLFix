#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use autodie;

# processes the autoeval.out file and prints out the results in TSV format
# (first line are headings, second line are data)

sub say {
    my $line = shift;
    print "$line\n";
}

sub tsvsay {
    my $line = join "\t", @_;
    print "$line\n";
}

# converts to percent with two decimal digits
sub percent00 {
    my $number = shift;
    # 0.123456 -> 1234.56 -> 1234 -> 12.34
    return int(10000*$number)/100;
}

# e.g.:
# 2012-10-10_14-58-10_exp20_parse_fix
sub processLineSystem {
    my $handle = shift;
    my $line = <$handle>;
    chomp $line;
    return $line;
}

# e.g.:
# 42
sub processLineChanged {
    my $handle = shift;
    my $line = <$handle>;
    chomp $line;
    return $line;
}

# e.g.:
# NIST score = 8.4674  BLEU score = 0.4926 for system "2012-10-10_14-58-10_exp20_parse_fix/data_cs.txt"
sub processLineNistBleu {
    my $handle = shift;
    my $line = <$handle>;
    chomp $line;
    $line =~ /NIST score = ([0-9\.]{6,7}) +BLEU score = ([0-9\.]{6}) for system/;
    my $nist = $1;
    my $bleu = $2;
    return ($nist, $bleu);
}

# e.g.:
#  2012-10-10_14-58-10_exp20_parse_fix/output.txt:	       TER:	0.3584
sub processLinePerTer {
    my $handle = shift;
    my $line = <$handle>;
    chomp $line;
    $line =~ /([PT]ER):\t(0\.[0-9]{1,6})$/;
    my $type = $1;
    my $score = $2;
    return ($score, $type);
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';


# main

my ($eval_file_name) = @ARGV;

open my $eval_file, '<:utf8', $eval_file_name;

my ($system)        = processLineSystem   ($eval_file);
my ($linesChanged)  = processLineChanged  ($eval_file);
my ($nist0, $bleu0) = processLineNistBleu ($eval_file);
my ($nist1, $bleu1) = processLineNistBleu ($eval_file);
my ($per0)          = processLinePerTer   ($eval_file);
my ($per1)          = processLinePerTer   ($eval_file);
my ($ter0)          = processLinePerTer   ($eval_file);
my ($ter1)          = processLinePerTer   ($eval_file);

close $eval_file;

tsvsay ('chgd',
        'NIST_0', 'NIST_1', 'diff',
        'BLEU_0', 'BLEU_1', 'diff',
        'PER_0',  'PER_1',  'diff',
        'TER_0',  'TER_1',  'diff',
        'system');
tsvsay ($linesChanged,
        $nist0, $nist1, percent00($nist1-$nist0),
        $bleu0, $bleu1, percent00($bleu1-$bleu0),
        $per0,  $per1,  percent00($per1 -$per0),
        $ter0,  $ter1,  percent00($ter1 -$ter0),
        $system );
