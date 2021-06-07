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

## Example

```
fu-nanotags  -q tag.fa fastq-reads.fq.gz > passed.fq
```

To inspect the parameters, add `--verbose --showaln`:
```
## Processing a564e10b-c82e-4e59-98a4-fdc6f1b31acb
# a564e10b-c82e-4e59-98a4-fdc6f1b31acb:test-tag strand=-;score=167;pctid=94.57%
 < AATGATA-TGCGACCACTGAGATCTACACCTCTCTATACACTC-TT-CCTACACGACGCTCTTCCGATCTTTCGTACGTGAGTTTAAATGTATTTGGCTAAGGTGTATGTAAACTTCCGACTTCAACTG
 < |||||||  |||||||| ||||||||||||||||||||||||| || ||||||||||||||||||||||  ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
 < AATGATACGGCGACCACCGAGATCTACACCTCTCTATACACTCTTTCCCTACACGACGCTCTTCCGATC--TCGTACGTGAGTTTAAATGTATTTGGCTAAGGTGTATGTAAACTTCCGACTTCAACTG
## Processing d5b2e371-8481-4362-9239-4b434366f81d
## Processing f5713c1f-826c-40e3-88d1-d721cbf43dde
## Processing 132518b1-1522-45ed-9a77-94a3c981ac20
# 132518b1-1522-45ed-9a77-94a3c981ac20:test-tag strand=+;score=531;pctid=90.55%
 > AATGATACGGCGACCACCGAGATCTACACTATCCCTCTACACTCTTTCCCTACACGACGCTCTTCCGATCTACGTACGTGAGTTTAAATGT-GTTAGCTAAGGTGTATAT-AGCTTCCGACTTCAGC
 > |||||||||||||||||||||||||||||  || || |||||||||||||||||||||||||||||||||| |||||||||||||||||||  || |||||||||||| | | |||||||||||| |
 > AATGATACGGCGACCACCGAGATCTACAC-CTCTCTATACACTCTTTCCCTACACGACGCTCTTCCGATCT-CGTACGTGAGTTTAAATGTATTTGGCTAAGGTGTATGTAAACTTCCGACTTCAAC
```