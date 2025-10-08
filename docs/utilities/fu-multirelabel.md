---
layout: default
title: fu-multirelabel
parent: Utilities
---


# fu-multirelabel

A program to rename sequences from multiple files
(adding the filename, and or numerical postfix).
Will fail if multiple sequence receive the same name.

```text
Usage: 
  fu-multirelabel [options] FILE...

  Options:
    -b, --basename             Prepend file basename to sequence
    -r, --rename NAME          Replace original name with NAME
    -n, --numeric-postfix      Add progressive number (reset at each new basename)
    -t, --total-postfix        Add progressive number (without resetting at each new input file)
    -d, --split-basename CHAR  Remove the final part of basename after CHAR [default: .]
    -s, --separator STRING     Separator between prefix, name, suffix [default: _]
    --no-comments              Strip out comments
    --comment-separator CHAR   Separate comment from name with CHAR [default: TAB]
```

## Description

A list of files (can be specified with wild chars) that
can contain sequences with the same name.
The program allows to prepend the filename as prefix.

## Example usage

```bash
fu-multirelabel -b *.fasta > relabeled.fasta 
```