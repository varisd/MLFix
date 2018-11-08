#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

sub say {
    my $text;
    while ($text = shift) {
        print $text;
    }
    print "\n";
}

sub tsvsay {
    my $text = join "\t", @_;
    print "$text\n";
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

#
# SETTINGS
#

my $fileprefix1 = $ARGV[0];
my $fileprefix2 = $ARGV[1];
my $fixes_total = $ARGV[2];

print STDERR "Will process $fileprefix1 and $fileprefix2 to compare $fixes_total fixes..\n";

#
# PROCESS THE FILE
#

my %scores1;
my %scores2;
my %lines;
my %sets;

open my $fileOut1, '<:utf8', "$fileprefix1" or die("Cannot open file $fileprefix1.out!");
open my $fileOut2, '<:utf8', "$fileprefix2" or die("Cannot open file $fileprefix2.out!");

while (<$fileOut1>) {
    my $line1 = $_;
    my $line2 = <$fileOut2>;
    if ($line1 =~ /^([0-9]+)\t.*(OUR1|OUR2|OUR3|BASE).*\t(.)$/) {
        my $lineNo = $1;
        my $set = $2;
        my $evalChar = $3;
	
	$sets{$set} = 1;

	# TODO
        if ($evalChar =~ /^[1-4]$/) {
            $scores1{$lineNo}->{$set} = $evalChar;
            $lines{$lineNo}++;
        } else {
	    die "incorrect ok char";
	}
    }
    if ($line2 =~ /^([0-9]+)\t.*(OUR1|OUR2|OUR3|BASE).*\t(.)$/) {
        my $lineNo = $1;
        my $set = $2;
        my $evalChar = $3;

	# TODO
        if ($evalChar =~ /^[1-4]$/) {
            $scores2{$lineNo}->{$set} = $evalChar;
        } else {
	    die "incorrect ok char";
	}
    }
}
close $fileOut1;
close $fileOut2;

my @results = ('win', 'lose', 'tie');
# $agree->{$set1}->{$set2}->{$result1}->{$result2}
my $agree = {};
foreach my $set1 (keys %sets) {
    foreach my $set2 (keys %sets) {
	foreach my $result1 (@results) {
	    foreach my $result2 (@results) {
		$agree->{$set1}->{$set2}->{$result1}->{$result2} = 0;
	    }
	}
    }
}


foreach my $line (keys %scores1) {
    # warn "$line\n";
    foreach my $set1 (keys %{$scores1{$line}}) {
	foreach my $set2 (keys %{$scores1{$line}}) {
	    my $result1;
	    if ($scores1{$line}->{$set1} < $scores1{$line}->{$set2}) {
		# lower score is better
		$result1 = 'win';
	    }
	    elsif ($scores1{$line}->{$set1} > $scores1{$line}->{$set2}) {
		# higher score is worse
		$result1 = 'lose';
	    }
	    elsif ($scores1{$line}->{$set1} == $scores1{$line}->{$set2}) {
		# a tie
		$result1 = 'tie';
	    } else {
		die "assert error";
	    }

	    my $result2;
	    if ($scores2{$line}->{$set1} < $scores2{$line}->{$set2}) {
		# lower score is better
		$result2 = 'win';
	    }
	    elsif ($scores2{$line}->{$set1} > $scores2{$line}->{$set2}) {
		# higher score is worse
		$result2 = 'lose';
	    }
	    elsif ($scores2{$line}->{$set1} == $scores2{$line}->{$set2}) {
		# a tie
		$result2 = 'tie';
	    } else {
		die "assert error";
	    }
	    
	    $agree->{$set1}->{$set2}->{$result1}->{$result2}++;

	}
    }
}


tsvsay ("$fileprefix1 and $fileprefix2");

foreach my $set1 (keys %$agree) {
    if ($set1 !~ /OUR3/) {
	next;
    }
    foreach my $set2 (keys %{$agree->{$set1}}) {
	if ($set2 =~ /OUR3/) {
	    next;
	}
	tsvsay ("$set1 over $set2");
	tsvsay ('A1/A2', @results);
	foreach my $result1 (@results) {
	    my @output = ($result1);
	    foreach my $result2 (@results) {
		push @output, $agree->{$set1}->{$set2}->{$result1}->{$result2};
	    }
	    tsvsay @output;
	}
    }
}
