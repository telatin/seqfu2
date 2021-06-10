---
sort: 15
---
# seqfu merge

```note
Function under development: APIs and default parameters are likely going to change.

This is why you don't see it listed in the main screen of SeqFu (yet).
```

A tool to naively merge paired end reads preserving the quality of the forward read.

```
Usage: merge [options] -1 File_R1

  Options:
  -1, --R1 FILE                First paired-end file
  -2, --R2 FILE                Second paired-end file, can be automatically inferred  
  -i, --minid FLOAT            Minimum identity [default: 0.80]
  -m, --minlen INT             Minimum overlap [default: 20]
  --accepted-identity FLOAT    Accept fusion when identity is above FLOAT [default: 0.96]
  -v, --verbose                Print verbose messages
  -h, --help                   Show this help
```

## Merging reads

There are several tools to merge overlapping reads, and some are better than others.
In particular if we use tools that correcly interpret the _Phred quality scores_, then
tools like USEARCH and VSEARCH are correcly recalibrating the quality of the overlapping
bases.

Some tools, however, are expeting quality scores that are more likely produced by a
sequencing tool. This experimental module of SeqFu joins the reads in a different way:
takes the forward read _as is_, and extends it with the (reverse complemented) missing
part taken from the R2. 

## Potential uses

This tool can be used to estimate the overlapping size or the "mergeability" of reads 
before using the tools of choice.

For example:
```
seqfu merge -1 reads_R1.fq | seqfu head -n 200 | seqfu stats -n
```

## Output
The merged reads are printed to the standard output.

Also this is somehow unusual compared with most mergin tools, but allows streaming which
is a core feature in SeqFu tools.