#!/usr/bin/perl

use strict;
use Getopt::Long;
use File::Temp qw /tempfile/;
use File::Basename;
use File::Spec;

my $mteval = File::Spec->catfile(dirname(File::Spec->rel2abs(__FILE__)),
                    "mteval-v11b.pl");

my $setid = "SETID";
my $docid = "DOCID";
my $srclang = "slang";
my $tgtlang = "tlang";
my $backup_prefix = undef; # copy all the files to prefix.{src,hyp,ref}
GetOptions(
  "setid=s" => \$setid,
  "docid=s" => \$docid,
  "srclang=s" => \$srclang,
  "tgtlang=s" => \$tgtlang,
  "mteval=s" => \$mteval,
  "backup-prefix=s" => \$backup_prefix,
) or exit 1;

my $src = shift;
my $ref = shift;
my $hyp = shift;

die "usage: wrapmteval.pl srcfile reffile hypfile"
  if !defined $src || !defined $ref || !defined $hyp;

die "Cannot run: $mteval" if ! -x $mteval;

my ($refhan, $reffile, $refsents) = prepare_sgml("refset", $ref);
my ($srchan, $srcfile, $srcsents) = prepare_sgml("srcset", $src);
my ($hyphan, $hypfile, $hypsents) = prepare_sgml("tstset", $hyp);

if (defined $backup_prefix) {
  safesystem("autocat $src >$backup_prefix.src") or die;
  safesystem("autocat $hyp >$backup_prefix.hyp") or die;
  safesystem("autocat $ref >$backup_prefix.ref") or die;
}

if ($refsents != $srcsents || $srcsents != $hypsents) {
  unlink($reffile); unlink($srcfile); unlink($hypfile);
  die "Incompatible number of sentences: $srcsents src, $refsents ref, $hypsents $hyp";
}

safesystem($mteval, "-r", $reffile, "-s", $srcfile, "-t", $hypfile) or die;

unlink($reffile); unlink($srcfile); unlink($hypfile);

sub prepare_sgml {
  my $type = shift;
  my $fn = shift;

  my $ofn = $fn;
  $ofn = "zcat $fn |" if $fn =~ /\.gz$/;
  $ofn = "bzcat $fn |" if $fn =~ /\.bz2$/;
  open INF, $ofn or die "Can't open '$ofn'";

  my ($fhan, $fname) = tempfile( "nistXXXXX" );
  print $fhan "<$type setid=\"$setid\" srclang=\"$srclang\" trglang=\"$tgtlang\">\n";
  print $fhan "<DOC docid=\"$docid\" sysid=\"$fn\">\n";
  
  my $nr = 0;
  while (<INF>) {
    $nr++;
    chomp;
    $_ =~ s/^\s+|\s+$//g;
    $_ =~ s/\s+/ /g;
    print $fhan "<seg id=\"$nr\">$_</seg>\n";
  }
  print $fhan "</DOC>\n";
  print $fhan "</$type>\n";
  
  return ($fhan, $fname, $nr);
}


sub safesystem {
  print STDERR "Executing: @_\n";
  system(@_);
  if ($? == -1) {
      print STDERR "Failed to execute: @_\n  $!\n";
      exit(1);
  }
  elsif ($? & 127) {
      printf STDERR "Execution of: @_\n  died with signal %d, %s coredump\n",
          ($? & 127),  ($? & 128) ? 'with' : 'without';
      exit(1);
  }
  else {
    my $exitcode = $? >> 8;
    print STDERR "Exit code: $exitcode\n" if $exitcode;
    return ! $exitcode;
  }
}
