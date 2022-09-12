---
sort: 21
---

# seqfu bases

Counts the number of A, C, G, T and Ns in FASTA and FASTQ files.

```note
Introduced in SeqFu 1.16
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
  -u, --uppercase-ratio  Print the uppercase/total ratio
  -H, --header           Print header
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