# Perl module usage example

To install the perl module we can use _cpanm_ or _conda_, for example
```bash
conda install -y  -c bioconda perl-fastx-reader
```

This folder contains two scripts to perform a "custom operation" on FASTQ files.
In this case we download a set of _single cell_ RNA Seq data using `getdata.sh` (
source: [this tutorial](https://umi-tools.readthedocs.io/en/latest/Single_cell_tutorial.html#step-1-obtaining-the-data)).

Then we extract the barcodes that are in position 0-16 of the R1 reads using
`sc_getbarcodes.pl` that will print them in `barcodes.txt`. The script can process
all the files in the directory, so we won't concatenate as done in the tutorial.
We expect 100 cells so we ask for the top 100 barcodes.

```bash
perl sc_getbarcodes.pl -o barcodes.txt -n 100 fastqs/*R1*
```

Finally, `sc_splitbybarcode.pl` will use the extracted barcodes to split the
R1, R2 and I1 files by barcode.

```bash
perl sc_splitbybarcode.pl -b barcodes.txt -o split/ fastqs/*R1*
```

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