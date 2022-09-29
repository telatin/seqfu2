# seqfu bases

Counts the number of A, C, G, T and Ns in FASTA and FASTQ files.

```note
Introduced in SeqFu 1.15.1 as experimental feature
```

Calculates the composition of DNA sequences

```text
Usage: bases [options] [<inputfile> ...]

Print the DNA bases, and %GC content, in the input files

Options:
  -c, --raw-counts       Print counts and not ratios
  -t, --thousands        Print thousands separator
  -a, --abspath          Print absolute path 
  -b, --basename         Print the basename of the file
  -n, --nice             Print terminal table
  -d, --digits INT       Number of digits to print [default: 2]
  -H, --header           Print header (auto enabled with --nice)
  -v, --verbose          Verbose output
  --debug                Debug output
  --help                 Show this help
```

### Output

The output is a table with the following columns (`-H` to print the header):

1. Filename (`-a` for absolute path, `-b` for basename)
2. Total bases (`-t` to add thousand separator)
3. Ratio of **A** bases over total bases (`-c` to print raw counts)
4. Ratio of **C** bases over total bases (`-c` to print raw counts)
5. Ratio of **G** bases over total bases (`-c` to print raw counts)
6. Ratio of **T** bases over total bases (`-c` to print raw counts)
7. Ratio of **N** bases over total bases (`-c` to print raw counts)
8. Ratio of **Other** characters (either IUPAC DNA or invalid chars) over total bases (`-c` to print raw counts)
9. %GC ratio
10. Ratio of **Uppercase** bases over total bases (if enabled by `-u`)

### Example

A simple example:

```text
seqfu bases --header data/illumina_*

#Filename               Total   A       C       G       T       N       Other   %GC
data/illumina_1.fq.gz   630     18.57   18.57   18.57   18.57   18.57   0.00    59.21
data/illumina_2.fq.gz   630     21.43   21.43   21.43   21.43   21.43   0.00    60.48
data/illumina_nocomm.fq 630     18.57   18.57   18.57   18.57   18.57   0.00    59.21
```

when using `-n` the output is a nice table:

```text
┌─────────────────────┬───────┬────────┬────────┬────────┬────────┬──────┬───────┬────────┬───────────┐
│ File                │ Bases │ A      │ C      │ G      │ T      │ N    │ Other │ %GC    │ Uppercase │
├─────────────────────┼───────┼────────┼────────┼────────┼────────┼──────┼───────┼────────┼───────────┤
│ data/base_at.fa     │ 33    │ 42.42  │ 0.00   │ 0.00   │ 57.58  │ 0.00 │ 0.00  │ 0.00   │ 100.00    │
│ data/bases_lower.fa │ 15    │ 33.33  │ 26.67  │ 20.00  │ 13.33  │ 6.67 │ 0.00  │ 46.67  │ 0.00      │
│ data/base_c.fa      │ 5     │ 0.00   │ 100.00 │ 0.00   │ 0.00   │ 0.00 │ 0.00  │ 100.00 │ 0.00      │
│ data/base.fa        │ 2     │ 50.00  │ 50.00  │ 0.00   │ 0.00   │ 0.00 │ 0.00  │ 50.00  │ 100.00    │
│ data/upper-none.fa  │ 7     │ 42.86  │ 14.29  │ 28.57  │ 14.29  │ 0.00 │ 0.00  │ 42.86  │ 0.00      │
│ data/base_t.fa      │ 5     │ 0.00   │ 0.00   │ 0.00   │ 100.00 │ 0.00 │ 0.00  │ 0.00   │ 0.00      │
│ data/base_a.fa      │ 5     │ 100.00 │ 0.00   │ 0.00   │ 0.00   │ 0.00 │ 0.00  │ 0.00   │ 100.00    │
│ data/upper-lower.fa │ 10    │ 50.00  │ 50.00  │ 0.00   │ 0.00   │ 0.00 │ 0.00  │ 50.00  │ 50.00     │
│ data/base_g.fa      │ 1     │ 0.00   │ 0.00   │ 100.00 │ 0.00   │ 0.00 │ 0.00  │ 100.00 │ 100.00    │
│ data/upper-only.fa  │ 9     │ 44.44  │ 11.11  │ 44.44  │ 0.00   │ 0.00 │ 0.00  │ 55.56  │ 100.00    │
│ data/base_extra.fa  │ 20    │ 50.00  │ 0.00   │ 0.00   │ 0.00   │ 0.00 │ 50.00 │ 0.00   │ 100.00    │
│ data/base_cg.fa     │ 25    │ 0.00   │ 52.00  │ 48.00  │ 0.00   │ 0.00 │ 0.00  │ 100.00 │ 100.00    │
└─────────────────────┴───────┴────────┴────────┴────────┴────────┴──────┴───────┴────────┴───────────┘
```
