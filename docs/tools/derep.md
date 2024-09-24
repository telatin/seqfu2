
# seqfu derep

*derep*  is one of the core subprograms of *SeqFu*, that allows the dereplication of FASTA and FASTQ files. 
Dereplication, in R. C. Edgard [words](https://drive5.com/usearch/manual/dereplication.html) is *A rather obscure name for finding the set of unique sequences. Or, equivalently, the process of finding duplicated (replicate) sequences.* 

In simple words, given a FASTA file, only unique sequences will be printed in the output. A core feature is printing the number of identical sequences found in the original dataset.

Dereplication is a step commonly used in NGS sequencing of amplicons, to reduce the computational time dedicated to the analysis of each representative sequence, and some tools will require dereplicated sequences as input 
(e.g. [USEARCH](https://rcedgar.github.io/usearch12_documentation/)).



```text
Usage: derep [options] [<inputfile> ...]

Options:
  -k, --keep-name              Do not rename sequence, but use the first sequence name
  -i, --ignore-size            Do not count 'size=INT;' annotations (they will be stripped in any case)
  -m, --min-size=MIN_SIZE      Print clusters with size equal or bigger than INT sequences [default: 0]
  -p, --prefix=PREFIX          Sequence name prefix [default: seq]
  -5, --md5                    Use MD5 as sequence name (overrides other parameters)
  -j, --json=JSON_FILE         Save dereplication metadata to JSON file
  -s, --separator=SEPARATOR    Sequence name separator [default: .]
  -w, --line-width=LINE_WIDTH  FASTA line width (0: unlimited) [default: 0]
  -l, --min-length=MIN_LENGTH  Discard sequences shorter than MIN_LEN [default: 0]
  -x, --max-length=MAX_LENGTH  Discard sequences longer than MAX_LEN [default: 0]
  -c, --size-as-comment        Print cluster size as comment, not in sequence name
  --add-len                    Add length to sequence
  -v, --verbose                Print verbose messages
  -h, --help                   Show this help
```

## Size values

By default the program will add the number of identical sequences found to the sequence name, as USEARCH does:
For example, if a sequence is found 18.335 times in the input file, the output will contain a sequence with ";size=18335" in the name (unless `--ignore-size` is passed). The term "size" can be confusing, but it was adopted for compatibility with USEARCH/VSERACH.

```
>seq.1;size=18335
CTTGGTCATTTAGAGGAAGTAAAAGTCGTAACAAGGTTTCCGTAGGTGAACCTGCGGAAGGATCATTACAGTATTCTTTTTGCCAGCGCTTAATTGCGCGGCGAAAAAACCTTACACACAGTGTTTTTTGTTATTACAAGAACTTTTGCTTTGGTCTGGACTAGAAATAGTTTGGGCCAGAGGTTTACTGAACTAAACTTCAATATTTATATTGAATTGTTATTTATTTAATTGTCAATTTGTTGATTAAATTCAAAAAATCTTCAAAACTTTCAACAACGGATCTCTTGGTTCTCGCATCGATGAAGAACGCAGC
>seq.2;size=4085
CTTGGTCATTTAGAGGAAGTAAAAGTCGTAACAAGGTTTCCGTAGGTGAACCTGCGGAAGGATCATTATTGAAGTTTAACTCAGAGGGTTGTAGCTGGCTCCTCCAAGAGCATGTGCACGCCCTTTGTCTTTACTCTTTTCCACCTGTGCACCTTTTGTAGACCATGAGTGAACTCTCGAGAGCGTTGGCAACGACGTGATCGGTTTGGGGATTTGCGTTCAGCTTTCCCTGTAGCTCGTGGTTTATGTCTTATAAACTCTATAGTCTGTTTTGAATGTCTTATGGGTTTTGCGCTGTAATGGTGCGACCTTTATAAACTATACAACTTTTAGCAACGGATCTCTTGGCTCTCGCATCGATGAAGAACGCAGC
>seq.3;size=2453
CTTGGTCATTTAGAGGAAGTAAGAGAGAAATGTATAAACTCATAATTGACGAATGATAATTGTTATTGAAGTTTTTGTAAAGGGGCTTCTTTATGAATAAGGGATACACGTTTGACGATATGATTAATACCATGATGCCCCTGGCCCTTTGACGGCTCGGCAAAGGGTGAAGGAATTTACTGCACGGTCAGGCCCTCGTCGCATCGATGAAGAACGCAGC
```

To keep the size separate from the sequence name it's possible to used `-c` (`--size-as-comment`):
```
>seq.1 size=18335
CTTGGTCATTTAGAGGAAGTAAAAGTCGTAACAAGGTTTCCGTAGGTGAACCTGCGGAAGGATCATTACAGTATTCTTTTTGCCAGCGCTTAATTGCGCGGCGAAAAAACCTTACACACAGTGTTTTTTGTTATTACAAGAACTTTTGCTTTGGTCTGGACTAGAAATAGTTTGGGCCAGAGGTTTACTGAACTAAACTTCAATATTTATATTGAATTGTTATTTATTTAATTGTCAATTTGTTGATTAAATTCAAAAAATCTTCAAAACTTTCAACAACGGATCTCTTGGTTCTCGCATCGATGAAGAACGCAGC
>seq.2 size=4085
CTTGGTCATTTAGAGGAAGTAAAAGTCGTAACAAGGTTTCCGTAGGTGAACCTGCGGAAGGATCATTATTGAAGTTTAACTCAGAGGGTTGTAGCTGGCTCCTCCAAGAGCATGTGCACGCCCTTTGTCTTTACTCTTTTCCACCTGTGCACCTTTTGTAGACCATGAGTGAACTCTCGAGAGCGTTGGCAACGACGTGATCGGTTTGGGGATTTGCGTTCAGCTTTCCCTGTAGCTCGTGGTTTATGTCTTATAAACTCTATAGTCTGTTTTGAATGTCTTATGGGTTTTGCGCTGTAATGGTGCGACCTTTATAAACTATACAACTTTTAGCAACGGATCTCTTGGCTCTCGCATCGATGAAGAACGCAGC
>seq.3 size=2453
CTTGGTCATTTAGAGGAAGTAAGAGAGAAATGTATAAACTCATAATTGACGAATGATAATTGTTATTGAAGTTTTTGTAAAGGGGCTTCTTTATGAATAAGGGATACACGTTTGACGATATGATTAATACCATGATGCCCCTGGCCCTTTGACGGCTCGGCAAAGGGTGAAGGAATTTACTGCACGGTCAGGCCCTCGTCGCATCGATGAAGAACGCAGC
```

## Summing dereplicated outputs

If the input files were already dereplicated printing the "size" of the cluster, `derep` will sum the
size values.

This is a feature that to our knowledge is only available in SeqFu and allows to process in parallel multiple samples
and generating a single "dereplicated file" at the end, propagating the correct cluster sizes.


## Screenshot

![Screenshot of "seqfu derep"]({{site.baseurl}}/img/screenshot-derep.svg "SeqFu derep")