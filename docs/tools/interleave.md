---
layout: default
title: seqfu interleave
parent: Core Tools
---


# seqfu interleave

*interleave* (or *ilv*) is one of the core subprograms of *SeqFu*.
It's used to produce an _interleaved FASTQ file_ from two separate 
files containing the forward and the reverse read of a paired-end 
fragment.

```text
ilv: interleave FASTQ files

  Usage: ilv [options] -1 <forward-pair> [-2 <reverse-pair>]

  -f --for-tag <tag-1>       string identifying forward files [default: auto]
  -r --rev-tag <tag-2>       string identifying forward files [default: auto]
  -o --output <outputfile>   save file to <out-file> instead of STDOUT
  -c --check                 enable careful mode (check sequence names and numbers)
  -v --verbose               print verbose output

  -s --strip-comments        skip comments
  -p --prefix "string"       rename sequences (append a progressive number)

guessing second file:
  by default <forward-pair> is scanned for _R1. and substitute with _R2.
  if this fails, the patterns _1. and _2. are tested.

example:

    ilv -1 file_R1.fq > interleaved.fq
```

## What are interleaved files?

[Paired end sequences](https://www.illumina.com/science/technology/next-generation-sequencing/plan-experiments/paired-end-vs-single-read.html) can be stored in two separate files 
(usually denoted with the **_R1** and **_R2** strings) or in a single sequence where each sequence pair is 
stored as two subsequent sequences.

A simple example is depicted below:

```text
=======================================================================
File_R1.fq                File_R2.fq                Interleaved.fq
=======================================================================


@seq1                     @seq1                     @seq1
TTTCATTCTGACTGCAACG       GGATTAAAAAAAGAGTGTC       TTTCATTCTGACTGCAACG
+                         +                         +
IIIIIIIIIIIIIIIIIII       IIIIIIIIIIIIIIIIIII       IIIIIIIIIIIIIIIIIII
@seq2                     @seq2                     @seq1
GTGTGGATTAAAAAAAAAA       TTTTTTTTTTTTTTTTTTT       GGATTAAAAAAAGAGTGTC
+                         +                         +
IIIIIIIIIIIIIIIIIII       IIIIIIIIIIIIIIIIIII       IIIIIIIIIIIIIIIIIII
@seq3                     @seq3                     @seq2 
AGAGTGTCTGATAGCA          GATAGCAG                  GTGTGGATTAAAAAAAAAA
+                         +                         +
IIIIIIIIIIIIIIII          IIIIIIII                  IIIIIIIIIIIIIIIIIII
                                                    @seq2
                                                    TTTTTTTTTTTTTTTTTTT
                                                    +
                                                    IIIIIIIIIIIIIIIIIII
                                                    @seq3
                                                    AGAGTGTCTGATAGCA
                                                    +
                                                    IIIIIIIIIIIIIIII
                                                    @seq3
                                                    GATAGCAG
                                                    +
                                                    IIIIIIII
```


## Screenshot

![Screenshot of "seqfu interleave"]({{site.baseurl}}/img/screenshot-interleave.svg "SeqFu interleave")