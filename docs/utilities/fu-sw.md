
# fu-sw

Simple implementation of the _Smith-Waterman_ alignment:

```text
Usage: fu-sw [options] -q QUERY -t TARGET

  Options:
    -q --query <FILE>         File with the sequence(s) to align against target
    -t --target <FILE>        File with the target sequence(s)
    -i --id ID                Align only against the sequence named `ID` in the target file
    -s --showaln              Show graphical alignment
    
  Smith-Waterman options:
    --score-match INT         Score for a match [default: 10]
    --score-mismatch INT      Score for a mismatch [default: -5]
    --score-gap INT           Score for a gap [default: -10]
    --min-score INT           Minimum alignment score [default: 80]
    --pct-id FLOAT            Minimum percentage of identity [default: 85]
  
  Other options:
    --pool-size INT           Number of sequences/pairs to process per thread [default: 20]
    -v --verbose              Verbose output
    -h --help                 Show this help
```

## Input files

Input files can be in FASTA or FASTQ format, and both query and 
target can hold multiple sequences even if the common application 
is to have a single sequence in the target file.

If the target file contains multiple sequences but only one is 
the intended target, the target can be specified with `--id` 
parameter.

## Example output

The output will print the alignment score and coordinates in a
single line after `QUERY` and `TARGET`.
If `--showaln` is specified, a graphical summary of the local
alignment is provided.

```text
# QUERY: not_in_target
## TARGET: ecoli

# QUERY: 16S_1_for_ins
## TARGET: ecoli
Score: 406 (97.18%)     Length: 69      Strand: +       Query: 0-71     Target: 21-90
 GCTCAGATTGAACGCTccGGCGGCAGGCCTAACACATGCAAGTCGAACGGTAACAGGAAGCAGCTTGCTGC
 ||||||||||||||||  |||||||||||||||||||||||||||||||||||||||||||||||||||||
 GCTCAGATTGAACGCT--GGCGGCAGGCCTAACACATGCAAGTCGAACGGTAACAGGAAGCAGCTTGCTGC

# QUERY: 16S_2_rev
## TARGET: ecoli
Score: 312 (100.00%)    Length: 52      Strand: -       Query: 0-52     Target: 175-227
 CGCATAATGTCGCAAGACCAAAGAGGGGGACCTTCGGGCCTCTTGCCATCGG
 ||||||||||||||||||||||||||||||||||||||||||||||||||||
 CGCATAATGTCGCAAGACCAAAGAGGGGGACCTTCGGGCCTCTTGCCATCGG
```

## Release note

From 1.19.0 the algorithm has been rewritten using only standard libraries,
while the initial implementation used the neo library for storing matrices.
This resulted in a 2X speedup.
