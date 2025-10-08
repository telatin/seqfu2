---
layout: default
title: seqfu rotate
parent: Core Tools
---



# seqfu rotate

Rotate a sequence setting a new starting position, using 
a new position or an oligonucleotide.

Introduced with SeqFu 1.8.6.

```text
sage:
    fu-rotate [options] -i POS [<fastq-file>...]
    fu-rotate [options] -m STR [<fastq-file>...]

  Rotate the sequences of one or more sequence files using 
  coordinates or motifs.

  Position based:
    -i, --start-pos POS        Restart from base POS, where 1 is the first base [default: 1]
  
  Motif based:
    -m, --motif STR            Rotate sequences using motif STR as the new start,
                               where STR is a string of bases
    -s, --skip-unmached        If a motif is provided, skip sequences that do not
                               match the motif
    -r, --revcomp              Also scan for reverse complemented motif

  Other options:
    -v, --verbose              Verbose output
    -h, --help                 Show this help
```

## Examples

Given an input file with a single sequence:

```text
>polyA
ACACGTACTACTGAAAAAAAAAACTGCTACTA
```

### Rotate by new position

```bash
seqfu rotate -i 14  data/homopolymer.fa 
```

Output:

```text
>polyA
AAAAAAAAAACTGCTACTAACACGTACTACTG
```

### Rotate by oligonucleotide

:warning: rotation by oligo will only produce an output if the match is unique

```bash
seqfu rotate -m AAAAAAAAAA data/homopolymer.fa
```

Output:

```text
>polyA
AAAAAAAAAACTGCTACTAACACGTACTACTG
```


### Rotate by oligonucleotide (also in reverse)

```bash
seqfu rotate -r -m GTTTTTTTTTT  data/homopolymer.fa
```

Output:

```text
>polyA
GTTTTTTTTTTCAGTAGTACGTGTTAGTAGCA
```

## Screenshot

![Screenshot of "seqfu rotate"]({{site.baseurl}}/img/screenshot-rotate.svg "SeqFu rotate")