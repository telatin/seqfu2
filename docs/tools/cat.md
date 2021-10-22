---
sort: 14
---
# seqfu cat

Concatenate multiple FASTA/FASTQ files, in a similar way of the GNU `cat` utility.

```text
Usage: cat [options] [<inputfile> ...]

Concatenate multiple FASTA or FASTQ files.

Options:
  -k, --skip SKIP        Print one sequence every SKIP [default: 0]

Sequence name:
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -z, --strip-name       Remove the original sequence name
  -b, --basename         Prepend file basename to the sequence name
  -a, --append STRING    Append this string to the sequence name [default: ]
  --split CHAR           Split basename at this char [default: .]
  --part INT             After splitting the basename, take this part [default: 1]
  --sep STRING           Sequence name fields separator [default: _]
  --basename-sep STRING  Separate basename from the rest with this [default: _]

Sequence comments:
  -s, --strip-comments   Remove original sequence comments
  --comment-sep CHAR     Comment separator [default:  ]
  --add-len              Add 'len=LENGTH' to the comments
  --add-initial-len      Add 'original_len=LENGTH' to the comments
  --add-gc               Add 'gc=%GC' to the comments
  --add-initial-gc       Add 'original_gc=%GC' to the comments
  --add-name             Add 'original_name=INITIAL_NAME' to the comments

Filtering:
  -m, --min-len INT      Discard sequences shorter than INT [default: 1]
  -x, --max-len INT      Discard sequences longer than INT, 0 to ignore [default: 0]
  --trim-front INT       Trim INT base from the start of the sequence [default: 0]
  --trim-tail INT        Trim INT base from the end of the sequence [default: 0]
  --truncate INT         Keep only the first INT bases, 0 to ignore  [default: 0]
                         Negative values to print the last INT bases

Output:
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --list                 Output a list of sequence names 
  -q, --fastq-qual INT   FASTQ default quality [default: 33]
  -v, --verbose          Verbose output
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
