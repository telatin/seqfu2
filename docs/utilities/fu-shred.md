---
sort: 10
---
# fu-shred

A program to systematically shotgun a reference
(i.e. this does **not** simulate
a random shotgun library preparation, but produce
reads of length _L_ sliding
over the reference chromosomes at a step _S_).

This tool is to test the effect of read size alone on
alignment and classification
methods, and was introduced in SeqFu 1.4.

```text
Usage: fu-shred [options]  [<fastq-file>...]

  Systematically produce a "shotgun" of input sequences. Can read from standard input.

  Options:
    -l, --length INT           Segment length [default: 100]
    -s, --step INT             Distance from one segment start to the following [default: 10] 
    -q, --quality INT          Quality (constant) for the segment, if -1 is 
                               provided will be printed in FASTA [default: 40]
    -r, --add-rc               Print every other read in reverse complement
    -b, --basename             Prepend the file basename to the read name
    --split-basename  CHAR     Split the file basename at this character [default: .]
    --prefix-separator STRING  Join the basename with the rest of the read name with this [default: _]

    -v, --verbose              Verbose output
    -h, --help                 Show this help

```

## Input

One or more FASTA or FASTQ files. By default will read from STDIN.

## Parameters

Main parameters:
* the desired sequence length with `--length INT`
* the distance between the starting site of each read, with `--step INT`
* the quality value of each base, with `--quality INT` (if you supply **-1**, the output will be in FASTA format)

If processing multiple files, it can be convenient to prepend the file basename with `--basename`. The basename
will be split at the first `.`, but this can be changed with `--split-basename STR/CHAR`.

If a mix of forward and reverse reads is required, `--add-rc` will reverse complement every other read. If you
want to test every read and its reverse complement, run the program _without_ `--add-rc` and make a reverse 
complement of the whole dataset with `seqfu rc`.

## Output

The generated sequences will be printed to the standard output (STDOUT). Each read has a progressive
name generated like this:
* file basename (if `--basename` is specified)
* a string separator (if `--basename` is specified)
* the chromosome name
* a string separator
* a progressive number

```text
@k141_1_1 
GTCGGAGTCGTTTATCCGCAACATCCTGCTTGCACAGGAGTTTTATAAAAAGGAGTTCGGCATCAAGTCGAAGGATATGTTCCTGCCCGACTGCTTCGGA
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
@k141_1_2 
TCGGGCAGGAACATATCCTTCGACTTGATGCCGAACTCCTTTTTATAAAACTCCTGTGCAAGCAGGATGTTGCGGATAAACGACTCCGACGACGGCATGT
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
@k141_1_3 
AACGACCCGAACATGCCGTCGTCGGAGTCGTTTATCCGCAACATCCTGCTTGCACAGGAGTTTTATAAAAAGGAGTTCGGCATCAAGTCGAAGGATATGT
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
@k141_1_4 
CGACTTGATGCCGAACTCCTTTTTATAAAACTCCTGTGCAAGCAGGATGTTGCGGATAAACGACTCCGACGACGGCATGTTCGGGTCGTTGGCCTCGAAC
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
@k141_1_5 
CGGGGGCTTCGTTCGAGGCCAACGACCCGAACATGCCGTCGTCGGAGTCGTTTATCCGCAACATCCTGCTTGCACAGGAGTTTTATAAAAAGGAGTTCGG
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
```

## Shotgun simulation

If you need to simulate a whole genome shotun, you will need alternative software like 
[ART](https://www.niehs.nih.gov/research/resources/software/biostatistics/art/index.cfm).
 