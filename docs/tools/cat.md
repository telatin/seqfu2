---
layout: default
title: seqfu cat
parent: Core Tools
nav_order: 2
---

# seqfu cat

Concatenate multiple FASTA/FASTQ files, in a similar way of the GNU `cat` utility.

```text
Usage: cat [options] [<inputfile> ...]

Concatenate multiple FASTA or FASTQ files.

Options:
  -k, --skip STEP        Print one sequence every STEP [default: 0]
  --skip-first INT       Skip the first INT records [default: -1]
  --jump-to STR          Start from the record after the one named STR
                         (overrides --skip-first)
  --print-last           Print the name of the last sequence to STDERR (Last:NAME)

Sequence name:
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -z, --strip-name       Remove the original sequence name
  -a, --append STRING    Append this string to the sequence name [default: ]
  --sep STRING           Sequence name fields separator [default: _]

  -b, --basename         Prepend file basename to the sequence name (before prefix)
  --split CHAR           Split basename at this char [default: .]
  --part INT             After splitting the basename, take this part [default: 1]
  --basename-sep STRING  Separate basename from the rest with this [default: _]
  --zero-pad INT         Zero pad the counter to INT digits [default: 0]

Sequence comments:
  -s, --strip-comments   Remove original sequence comments
  --comment-sep CHAR     Comment separator [default:  ]
  --add-len              Add 'len=LENGTH' to the comments
  --add-initial-len      Add 'original_len=LENGTH' to the comments
  --add-gc               Add 'gc=%GC' to the comments
  --add-initial-gc       Add 'original_gc=%GC' to the comments
  --add-name             Add 'original_name=INITIAL_NAME' to the comments
  --add-ee               Add 'ee=EXPECTED_ERROR' to the comments
  --add-initial-ee       Add 'original_ee=EXPECTED_ERROR' to the comments

Filtering:
  -n, --max-ns INT       Discard sequences with more than INT Ns [default: -1]
  -m, --min-len INT      Discard sequences shorter than INT [default: 1]
  -x, --max-len INT      Discard sequences longer than INT, 0 to ignore [default: 0]
  --max-ee FLOAT         Discard sequences with higher than FLOAT expected error [default: -1.0]
  --trim-front INT       Trim INT base from the start of the sequence [default: 0]
  --trim-tail INT        Trim INT base from the end of the sequence [default: 0]
  --truncate INT         Keep only the first INT bases, 0 to ignore  [default: 0]
                         Negative values to print the last INT bases
  --max-bp INT           Stop printing after INT bases [default: 0]

Output:
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --report FILE          Save a report to FILE (original name, new name)
  --list                 Output a list of sequence names 
  --anvio                Output in Anvio format (-p c_ -s -z --zeropad 12 --report rename_report.txt)
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  -v, --verbose          Verbose output
  --debug                Debug output
  -h, --help             Show this help
```

## Input

One or more FASTA or FASTQ files. If no files are provided, the program will read from _standard input_.
Additionally, you can add _standard input_ to the list of input files.
by adding `-`.

## Output

It is possible to mix FASTA and FASTQ files, and by default the program will produce a mixed output.
Using `--fasta` or `--fastq` will force a specific output formats. For FASTA sequences a default quality values will be used.
Using `--list` the simple list of records matching the criteria will be printed.

## Anvi'o shortcut

If you use `--anvio` you will automatically suppress names and comments, and add a prefix `c_` to the sequence names and leading zeros to the counter, and write the report to `rename_report.txt`.
If you specify a different `--report` file, this will of course override the default report file.

## Splashscreen

![Screenshot of "seqfu cat"]({{site.baseurl}}/img/screenshot-cat.svg "SeqFu cat")