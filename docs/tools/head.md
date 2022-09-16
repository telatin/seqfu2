
# seqfu head

*head*  is one of the core subprograms of *SeqFu*.

It will print the first sequences of a FASTX file (like GNU head), but
can be instructed to skip a number of sequences between each printed one.

```text
Usage: head [options] [<inputfile> ...]

Select a number of sequences from the beginning of a file, allowing
to select a fraction of the reads (for example to print 100 reads,
selecting one every 10).

Options:
  -n, --num NUM          Print the first NUM sequences [default: 10]
  -k, --skip SKIP        Print one sequence every SKIP [default: 0]
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -s, --strip-comments   Remove comments
  -b, --basename         prepend basename to sequence name
  -v, --verbose          Verbose output
  --quiet                Don't print warnings
  --help                 Show this help

Output:
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --sep STRING           Sequence name fields separator [default: _]
  -q, --fastq-qual INT   FASTQ default quality [default: 33]```
```

## Example

By default the program prints the first 10 sequences of a file (the number
can be changed with `-n` or `--num`).

Sometimes to have a preview of a file we can add the `--skip` (or `-k` for short)
parameter to take a sequence every _N_.

The following examples shows the output of `seqfu head -n 10`, and `seqfu head -n 5 -k 4`):

![Example]({{site.baseurl}}/img/seqfu-head.png)

## Input and output

`seqfu head` takes as input one ore _more_ FASTA/FASTQ files (or reads from
the standard input if no filenames are provided, or `-` is added to the list).
The output will be in the same format as the input, unless `--fasta` or `--fastq`
are specified to force a different output.


## Screenshot

![Screenshot of "seqfu head"](img/screenshot-head.svg "SeqFu head")