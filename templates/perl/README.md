# Perl module usage example

This folder contains two scripts to perform a custom operation on FASTQ files.
In this case we download a set of _single cell_ RNA Seq data using `getdata.sh`.

Then we extract the barcodes that are in position 16-26 of the R1 reads using
`sc_getbarcodes.pl` that will print them in `barcodes.txt`.

Finally, `sc_splitbybarcode.pl` will use the extracted barcodes to split the
R1 files by barcode.

## Synopsis

A short introduction to the parser syntax. The full documentation [is available on MetaCPAN](https://metacpan.org/pod/FASTX::Reader).

```perl
my $reader = FASTX::Reader->new( { filename => "$file" });
while (my $record = $reader->getRead() ) {
   say "@", $record-{name},
     $record->{seq},
     "\n+\n,
     $record->{qual};
}
```