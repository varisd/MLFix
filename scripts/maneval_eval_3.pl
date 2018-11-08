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
    my $text;
    while ($text = shift) {
        print $text;
        print "\t";
    }
    print "\n";
}

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

#
# SETTINGS
#

my $fileprefix = $ARGV[0];
my $fixes_total = $ARGV[1];

print STDERR "Will process $fileprefix.out to compare $fixes_total fixes..\n";

#
# PROCESS THE FILE
#

my %scoresSum;
my %scores;
my %lines;

open my $fileOut, '<:utf8', "$fileprefix.out" or die("Cannot open file $fileprefix.out!");

while (<$fileOut>) {
    if (/^([0-9]+)\t.*(OUR1|OUR2|OUR3|BASE).*\t(.)$/) {
        my $lineNo = $1;
        my $set = $2;
        my $evalChar = $3;

	# TODO
        if ($evalChar =~ /^[1-4]$/) {
            $scoresSum{$set}->{$evalChar}++;
            $scores{$lineNo}->{$set} = $evalChar;
            $lines{$lineNo}++;
        } else {
	    die "incorrect ok char";
	}
    }
}
close $fileOut;

#my $indefinite = $fixes_total - $scores{'BASE'} - $scores{'OUR1'} - $scores{'OUR2'};
#my $our1Percent1 = 100*$scores{'OUR1'}/($scores{'BASE'}+$scores{'OUR1'});
#my $our1Percent2 = 100*$scores{'OUR1'}/($scores{'BASE'}+$scores{'OUR1'}+$indefinite);
#my $our2Percent1 = 100*$scores{'OUR2'}/($scores{'BASE'}+$scores{'OUR2'});
#my $our2Percent2 = 100*$scores{'OUR2'}/($scores{'BASE'}+$scores{'OUR2'}+$indefinite);

# $scores{$lineNo}->{$set} = $evalChar;
my %beat; # a beats b
my %tie;
foreach my $line (keys %scores) {
    foreach my $set1 (keys %{$scores{$line}}) {
	foreach my $set2 (keys %{$scores{$line}}) {
	    if ($scores{$line}->{$set1} < $scores{$line}->{$set2}) {
		# lower score is better
		$beat{$set1}->{$set2}++;
	    }
	    elsif ($scores{$line}->{$set1} > $scores{$line}->{$set2}) {
		# higher score is worse
		$beat{$set2}->{$set1}++;
	    }
	    elsif ($scores{$line}->{$set1} == $scores{$line}->{$set2}) {
		# a tie
		$tie{$set1}->{$set2}++;
	    } else {
		die "assert error";
	    }
	}
    }
}


my $notIndef = keys %lines;
my $indef = $fixes_total - $notIndef;

tsvsay ($fileprefix );
tsvsay ('eval', 'BASE', 'OUR1', 'OUR2', 'OUR3' );
tsvsay (1, $scoresSum{'BASE'}->{1}, $scoresSum{'OUR1'}->{1}, $scoresSum{'OUR2'}->{1}, $scoresSum{'OUR3'}->{1}  );
tsvsay (2, $scoresSum{'BASE'}->{2}, $scoresSum{'OUR1'}->{2}, $scoresSum{'OUR2'}->{2}, $scoresSum{'OUR3'}->{2}  );
tsvsay (3, $scoresSum{'BASE'}->{3}, $scoresSum{'OUR1'}->{3}, $scoresSum{'OUR2'}->{3}, $scoresSum{'OUR3'}->{3}  );
tsvsay (4, $scoresSum{'BASE'}->{4}, $scoresSum{'OUR1'}->{4}, $scoresSum{'OUR2'}->{4}, $scoresSum{'OUR3'}->{4}  );
#tsvsay ($fileprefix, $fixes_total, $scoresSum{'BASE'}, $scoresSum{'OUR'}, $indefinite, $ourPercent1, $ourPercent2 );



tsvsay ("winner", "loser", "wins", "losses", "ties" );

foreach my $set1 (keys %beat) {
    foreach my $set2 (keys %{$beat{$set1}}) {
	tsvsay ($set1, $set2, ( $beat{$set1}->{$set2} / 2 ), ( $beat{$set2}->{$set1} / 2 ), $tie{$set1}->{$set2});
    }
}
