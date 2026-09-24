---
title: seqfu shred
summary: "Systematically tile sequences into single- or paired-end reads."
category: transform
input: [FASTA, FASTQ]
output: "FASTQ or FASTA"
wrapper: false
deprecated: false
experimental: false
paired: true
interactive: false
since: "1.4"
related: ["fu-shred", "seqfu rotate"]
keywords: "shred shotgun simulate reads tiling amplicon coverage"
---

```note
Since 1.18 paired end support was enabled. Since 1.30 paired end output can be
compressed, interleaved or written to explicit files, and `fu-readtope` has been
replaced by `seqfu shred --amplicon`.
```

A program to systematically shotgun a reference
(i.e. this does **not** simulate
a random shotgun library preparation, but produce
reads of length _L_ sliding
over the reference chromosomes at a step _S_).

This tool is to test the effect of read size alone on
alignment and classification
methods, and was introduced in SeqFu 1.4. The `fu-shred` binary
is deprecated and forwards its arguments to `seqfu shred`.

```text
Usage: seqfu shred [options] [<input>...]

  Systematically produce a "shotgun" of input sequences, as single-end or
  paired-end reads. Reads from STDIN if no input is given.

  Tiling:
    -l, --length INT           Read length [default: 100]
    -s, --step INT             Distance between consecutive segment starts [default: 10]
    -x, --coverage FLOAT       Target read coverage: computes --step (overrides -s)
    -f, --frag-len INT         Fragment (insert) length, paired-end only [default: 500]
    --frag-sd FLOAT            Standard deviation of the fragment length, paired-end
                               only; 0 keeps the tiling systematic [default: 0]
    --seed INT                 Random seed used with --frag-sd [default: 42]
    --tail                     Add a final segment anchored to the sequence end
    --circular                 Treat sequences as circular (segments wrap around)
    --amplicon                 Each input sequence is one fragment: R1 is the start,
                               R2 the reverse complement of the end
    --max-n FLOAT              Skip segments with a fraction of N above this [default: 1.0]

  Strand:
    -r, --add-rc               Reverse complement every other segment (= --strand alt)
    --strand STR               One of fwd, rev, alt, both [default: fwd]

  Output (single-end to STDOUT by default):
    -o, --out-prefix STR       Paired-end: write <STR><for-tag>.fq and <STR><rev-tag>.fq
    -1, --out-r1 FILE          Output file (single-end, or R1 with -2, or interleaved with -i)
    -2, --out-r2 FILE          Paired-end: R2 output file
    -i, --interleaved          Paired-end, interleaved (to STDOUT unless -1 is given)
    --for-tag STR              R1 tag used with --out-prefix [default: _R1]
    --rev-tag STR              R2 tag used with --out-prefix [default: _R2]

  Format:
    -q, --quality INT          Constant quality; -1 means FASTA output [default: 40]
    --fasta                    FASTA output (same as -q -1)
    -z, --gzip                 Compress output (implied by filenames ending in .gz)
    --level INT                Gzip compression level, 0-9 [default: 6]
    -t, --threads INT          Compression threads (uses pigz if available) [default: 1]

  Read names:
    -b, --basename             Prepend the file basename to the read name
    --split-basename STRING    Split the file basename at this character [default: .]
    --prefix-separator STRING  Join the basename with the rest of the read name with this [default: _]
    --pair-suffix              Append /1 and /2 to paired read names
    --coords                   Add the origin to the comment as seqname:start-end:strand

  Other:
    -v, --verbose              Verbose output
    -h, --help                 Show this help
```

## Input

One or more FASTA or FASTQ files. By default will read from STDIN.

## Parameters

Main parameters:

* the desired read length with `--length INT`
* the distance between the starting site of each segment, with `--step INT`, or a target read coverage
  with `--coverage FLOAT` (the step is then computed from the read length, counting both mates in
  paired end mode and both strands with `--strand both`)
* the quality value of each base, with `--quality INT` (if you supply **-1**, or use `--fasta`, the output will be in FASTA format)

If processing multiple files, it can be convenient to prepend the file basename with `--basename`. The basename
will be split at the first `.`, but this can be changed with `--split-basename STR/CHAR`.

### Tiling

* `--tail` adds one last segment ending exactly at the end of the sequence, so that the 3' end is always covered.
* `--circular` treats each sequence as circular (e.g. plasmids): segments start at every step along the whole
  sequence and wrap around the end.
* `--max-n FLOAT` skips segments with a fraction of `N` bases above the threshold.
* `--amplicon` treats each input sequence as a single fragment: in paired end mode R1 is the first `--length`
  bases and R2 the reverse complement of the last `--length` bases (sequences shorter than the read length are
  reported in full). This replaces the old `fu-readtope` script.

### Strand

By default all segments are taken from the forward strand. `--strand rev` reverse complements all of them,
`--strand alt` (or the legacy `--add-rc`) reverse complements every other segment, and `--strand both` emits
each segment in both orientations (doubling the output).

## Paired end mode

Paired end mode is enabled by any of:

* `--out-prefix STR`: writes `STR_R1.fq` and `STR_R2.fq` (tags can be changed with `--for-tag` and `--rev-tag`;
  the extension becomes `.fa` in FASTA mode and gets a `.gz` suffix with `--gzip`)
* `-1 FILE -2 FILE`: explicit output files, compressed when the name ends in `.gz` (or with `--gzip`)
* `--interleaved`: a single interleaved stream, to STDOUT or to the file given with `-1`

The program first extracts a fragment of `--frag-len` bases, then the first `--length` bases are used as the
first read, and the reverse complement of the last `--length` bases as the second read.
Both mates share the same name, unless `--pair-suffix` is used to append `/1` and `/2`.

With `--frag-sd FLOAT` the fragment length is drawn, for each fragment, from a normal distribution
centred on `--frag-len` (never shorter than the read length). The random generator is seeded with `--seed`
(default 42), so the output is reproducible. With the default `--frag-sd 0` the tiling is fully systematic.

In single end mode, `-1 FILE` writes to a file instead of STDOUT; `--gzip` also works on STDOUT.

## Ground truth

`--coords` adds the origin of each read to its comment as `seqname:start-end:strand` (1-based, inclusive;
in paired end mode both mates carry the coordinates of the fragment). In circular mode a wrapping segment
has an end smaller than its start.

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
