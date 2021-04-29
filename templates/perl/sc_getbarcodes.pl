#!/usr/bin/env perl 

use 5.012;
use FASTX::Reader;
use Getopt::Long;
 
my $opt_outputfile = "./barcodes.txt";
my $opt_start = 0;
my $opt_len = 16;
my $opt_bc_num = 100;
my $opt_min_counts = 3;
GetOptions(
  'o|output=s'     => \$opt_outputfile,
  's|start=i'      => \$opt_start,
  'l|len=i'        => \$opt_len,
  'n|bc-num=i'     => \$opt_bc_num,
  'm|min-counts=i' => \$opt_min_counts,
);

say STDERR "
 Extract barcodes
 -------------------------
 sc_getbarcodes.pl [options] FASTQ_FILES 

  -o FILE       Output file [$opt_outputfile]
  -s START      Start position of barcode [$opt_start]
  -l LEN        Barcode length [$opt_len]
  -m MIN        Minimum count of barcodes [$opt_min_counts]
  -n NUM        Number of expected barcodes [$opt_bc_num]
";
my %barcodes = ();

open (my $O, '>', "$opt_outputfile") || die " FATAL ERROR: Unable to write to $opt_outputfile. Permissions?\n$!\n";

for my $file (@ARGV) {
  next if not -e "$file";
  say STDERR " * Parsing $file";
  my $R = FASTX::Reader->new( { filename => "$file" });
  my $counter = 0;
  while (my $s = $R->getRead() ) {
    $counter++;
    my $bc = substr($s->{seq}, $opt_start, $opt_len);
    $barcodes{$bc}++;
  }
  say STDERR "\t $counter reads parsed.";
}

my $c = 0;
for my $bc (sort { $barcodes{$b} <=> $barcodes{$a}} keys %barcodes) {
  say {$O} $bc, "\t", $barcodes{$bc}, "\t", $opt_start, "\t", $opt_len;
  $c++;
  last if ($c >= $opt_bc_num);
  last if ($barcodes{$bc} < $opt_min_counts);
}
say STDERR "$c barcodes printed to $opt_outputfile";
