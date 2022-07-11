---
sort: 2
---
# seqfu deinterleave

*deinterleave* (or *dei*) is one of the core subprograms of *SeqFu*.
It's used to produce two separate FASTQ files from an interleaved file. 

```text
ilv: interleave FASTQ files

  Usage: dei [options] -o basename <interleaved-fastq>

  -o --output-basename "str"     save output to output_R1.fq and output_R2.fq
  -f --for-ext "R1"              extension for R1 file [default: _R1.fq]
  -r --rev-ext "R2"              extension for R2 file [default: _R2.fq]
  -c --check                     enable careful mode (check sequence names and numbers)
  -v --verbose                   print verbose output

  -s --strip-comments            skip comments
  -p --prefix "string"           rename sequences (append a progressive number)
 
notes:
    use "-" as input filename to read from STDIN

example:

    dei -o newfile file.fq
```


### Streaming

If a program produce an interleaved output, `seqfu deinterleave` can be used in a pipe (specifying "-" as input):

```bash
fu-primers -1 file_R1.fq -2 file_R2.fq | seqfu deinterleave -o fileNoPrimers -
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

![Screenshot of "seqfu deinterleave"]({{site.baseurl}}/img/screenshot-deinterleave.svg "SeqFu deinterleave")