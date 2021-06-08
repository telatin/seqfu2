---
sort: 6
---

# fu-nanotags

Search for tags (one or more sequences) in long reads using _Smith-Waterman_ 
alignment.
The tag has to be at the beginning of the read (specifying the region to scan
with `--cut INT`) or at the end (revserse complemented). If `--cut=0` the search
is in the full read.

```
Usage: fu-nanotags [options] -q QUERY [<fastq-file>...]

  Options:
    -q, --query TAGSEQ         Sequence string OR file with the sequence(s) to align against reads
    -s, --showaln              Show graphical alignment
    -c, --cut INT              Cut input reads at INT position [default: 300]
    -x, --disable-rev-comp     Do not scan reverse complemented reads
  
  Alignment options:
    -i, --pct-id FLOAT         Percentage of identity in the aligned region [default: 80.0]
    -m, --min-score INT        Minimum alignment score (0 for auto) [default: 0]
  
  Smith-Waterman parameters:
    -M, --weight-match INT     Match [default: 5]
    -X, --weight-mismatch INT  Mismatch penalty [default: -3]
    -G, --weight-gap INT       Gap penalty [default: -5]

  Other options:
    --pool-size INT            Number of sequences/pairs to process per thread [default: 25]
    -v, --verbose              Verbose output
    -h, --help                 Show this help
```

## Output

The program will print to the **standard output** the reasd containing the tag, 
under the specified alignment criteria.
A comment will be added to the reads specifying which tag was found (e.g. `tags=tag1;tag4`).

The program will print to the **standard error** the number of passing reads per file processed,
and the grand total. 

Example:
```
tradis/fastq_1.fq	60.00% (18/30) sequences printed, of which 8 in reverse strand.
tradis/fastq_2.fq.gz	53.75% (2150/4000) sequences printed, of which 949 in reverse strand.
Total	53.80% (2168/4030) sequences printed, of which 957 in reverse strand.
```

## Optimisation

If the tag is 100 bp long and we expect to be at the very beginning (or end) of the read,
it's advisable to reduce the `--cut INT` parameter accordingly to speedup the alingment
step (for example, to 110, to account for a small variation).

The current version of the program is single threaded, but a multithreading application 
will be released.

## Example

```bash
fu-nanotags  -q tag.fa fastq-reads.fq.gz > passed.fq
```

To inspect the parameters, add `--verbose --showaln`, 
possibly redirecting the output to `less -S` for a preliminary inspection:

```bash
fu-nanotags -q tag.fa reads.fq.gz --verbose --showaln 2>&1 | less -S
```

A fraction of the output is like the following:

```
# a564e10b-c82e-4e59-98a4-fdc6f1b31acb:test-tag strand=-;score=167;pctid=94.57%
 < AATGATA-TGCGACCACTGAGATCTACACCTCTCTATACACTC-TT-CCTACACGACGCTCTTCCGATCTTTCGTACGTGAGTTTAAATGTATTTGGCTAAGGTGTATGTAAACTTCCGACTTCAACTG
 < |||||||  |||||||| ||||||||||||||||||||||||| || ||||||||||||||||||||||  ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
 < AATGATACGGCGACCACCGAGATCTACACCTCTCTATACACTCTTTCCCTACACGACGCTCTTCCGATC--TCGTACGTGAGTTTAAATGTATTTGGCTAAGGTGTATGTAAACTTCCGACTTCAACTG
# 132518b1-1522-45ed-9a77-94a3c981ac20:test-tag strand=+;score=531;pctid=90.55%
 > AATGATACGGCGACCACCGAGATCTACACTATCCCTCTACACTCTTTCCCTACACGACGCTCTTCCGATCTACGTACGTGAGTTTAAATGT-GTTAGCTAAGGTGTATAT-AGCTTCCGACTTCAGC
 > |||||||||||||||||||||||||||||  || || |||||||||||||||||||||||||||||||||| |||||||||||||||||||  || |||||||||||| | | |||||||||||| |
 > AATGATACGGCGACCACCGAGATCTACAC-CTCTCTATACACTCTTTCCCTACACGACGCTCTTCCGATCT-CGTACGTGAGTTTAAATGTATTTGGCTAAGGTGTATGTAAACTTCCGACTTCAAC
```