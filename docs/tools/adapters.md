---
title: seqfu adapters
summary: "Detect and remove sequencing adapters or PCR primers from single- and paired-end FASTQ reads."
category: filter
input: [FASTQ]
output: "FASTQ"
wrapper: false
deprecated: false
experimental: false
paired: true
interactive: false
related: ["seqfu primers", "seqfu trim", "fu-primers"]
keywords: "adapter adaptor primer trim fastq paired illumina iupac pcr"
---

```text
Usage:
  adapters [options] -1 FILE -o FILE

Trim 3' or linked adapters from FASTQ reads. A plain SPEC is a 3' adapter;
FRONT...BACK is a linked adapter with required FRONT and optional BACK.
Without -a/-A, known adapters are detected automatically unless -K is used.
Explicit adapter specifications disable known-adapter detection.

Input and adapters:
  -a, --adapter SPEC         R1 adapter specification
  -A, --adapter-r2 SPEC      R2 adapter specification
  -K, --skip-known-adapters  Skip automatic known-adapter detection
  -1, --r1 FILE             R1 or single-end FASTQ
  -2, --r2 FILE             R2 FASTQ

Output:
  -o, --output FILE         R1 output, or interleaved paired output
  -O, --output-r2 FILE      Separate R2 output
  --discard-untrimmed       Discard reads/pairs without required matches
  --gzip-level INT          Gzip compression level [default: 6]

Matching:
  -e, --error-rate FLOAT    Maximum errors per aligned adapter base [default: 0.1]
  --overlap INT             Minimum adapter overlap [default: 3]
  --no-indels               Allow substitutions only

Performance and reporting:
  -t, --threads INT         Worker threads [default: 1]
  --batch-size INT          Reads or pairs per batch [default: 4096]
  --stats                   Print trimming counts to stderr
  -h, --help                Show this help
```

`seqfu adapters` removes known or explicitly supplied adapter sequences from
FASTQ reads. It supports single-end files, paired files, gzip input and output,
approximate matching, and ordered multithreaded processing.

Unlike [`seqfu trim`]({{site.baseurl}}/tools/trim.html), this command trims
specific nucleotide sequences rather than low-quality regions. The two commands
can be used together when both adapter removal and quality trimming are needed.

## Adapter specifications

A plain adapter specification is searched within each read. Sequence from the
start of the match through the 3' end is removed. Partial adapter matches are
accepted when they satisfy `--overlap` and `--error-rate`.

```bash
seqfu adapters -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCA \
  -1 reads.fastq.gz -o trimmed.fastq.gz
```

Unmatched reads are retained by default. Add `--discard-untrimmed` to keep only
reads containing the requested adapter.

```bash
seqfu adapters -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCA \
  -1 reads.fastq.gz -o adapter-positive.fastq.gz --discard-untrimmed
```

A linked specification joins a required 5' component and an optional 3'
component with three dots:

```text
FIVE_PRIME...THREE_PRIME
```

The 5' component must match at the start of the read. When it matches, it is
removed; the 3' component is also removed when present. With the default output
policy, reads missing the required 5' component are written unchanged. With
`--discard-untrimmed`, they are discarded.

```bash
seqfu adapters -a 'ACGTACGT...AGTCAGTC' \
  -1 reads.fastq.gz -o inserts.fastq.gz --discard-untrimmed
```

Adapter sequences are case-insensitive and accept IUPAC DNA symbols. `U` is
normalized to `T`.

## Automatic known-adapter detection

When neither `-a` nor `-A` is supplied, `seqfu adapters` selects an adapter
from an internal database of 234 known adapter and primer sequences derived from
[fastp](https://github.com/OpenGene/fastp)'s `src/knownadapters.h`. The selected
sequence and its database description are reported to standard error before
trimming.

```bash
seqfu adapters -1 reads.fastq.gz -o trimmed.fastq.gz
```

Detection is a bounded preliminary pass over at most 100,000 reads or 100 Mb
from each input file. It requires at least 12 aligned adapter bases, tolerates
substitutions according to `--error-rate`, and chooses one supported adapter per
mate. If no adapter has sufficient support, the command reports this and leaves
that mate unchanged rather than guessing.

Because trimming requires reopening the file after this scan, automatic
detection does not accept stdin. Use an explicit `-a` specification for a
stream, use `-K` to disable adapter processing, or save the stream to a
seekable FASTQ file first.

Supplying either `-a` or `-A` makes the explicit adapter configuration
authoritative and skips the bundled database. `-K` (or
`--skip-known-adapters`) also disables automatic detection. If it is used
without an explicit adapter, reads pass through unchanged.

Automatic detection identifies entries from the bundled database only; it does
not perform de novo adapter assembly.

## Paired-end adapters

For paired reads, `-a` applies to R1 and `-A` applies to R2. A mate without an
explicit specification is passed through unchanged; it is not automatically
scanned when the other mate has an explicit adapter. A pair is always kept or
discarded together.

```bash
seqfu adapters \
  -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCA \
  -A AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT \
  -1 sample_R1.fastq.gz -2 sample_R2.fastq.gz \
  -o clean_R1.fastq.gz -O clean_R2.fastq.gz
```

With no explicit specifications, R1 and R2 are scanned independently. This
allows the usual Read 1 and Read 2 adapters to be selected separately.

```bash
seqfu adapters \
  -1 sample_R1.fastq.gz -2 sample_R2.fastq.gz \
  -o clean_R1.fastq.gz -O clean_R2.fastq.gz
```

If paired input is supplied without `-O`, both mates are written to `-o` as
interleaved FASTQ in R1, R2 order.

```bash
seqfu adapters \
  -1 sample_R1.fastq.gz -2 sample_R2.fastq.gz \
  -o clean.interleaved.fastq.gz
```

## Matching controls

`--error-rate` is the maximum number of alignment errors divided by the number
of aligned adapter bases. Insertions and deletions are allowed by default; use
`--no-indels` for substitutions-only matching. `--overlap` sets the minimum
aligned length accepted during trimming.

```bash
seqfu adapters -a AGATCGGAAGAGC -1 reads.fastq.gz -o trimmed.fastq.gz \
  --error-rate 0.05 --overlap 10 --no-indels
```

Empty inserts are discarded. Read names, comments, and the quality scores
corresponding to retained sequence bases are preserved.

## PCR primer mode

`seqfu primers` is the PCR-specific interface to the same matching and output
engine.

```text
Usage:
  primers [options] --fwd SEQ --rev SEQ -1 FILE -o FILE

Trim PCR primers from FASTQ reads. The expected 5' primer is required by
default; an opposite-primer read-through match at 3' is trimmed when present.

Primers and input:
  -f, --fwd SEQ             Forward primer (IUPAC DNA)
  -r, --rev SEQ             Reverse primer (IUPAC DNA)
  -1, --r1 FILE             R1 or single-end FASTQ
  -2, --r2 FILE             R2 FASTQ

Output:
  -o, --output FILE         R1 output, or interleaved paired output
  -O, --output-r2 FILE      Separate R2 output
  --keep-untrimmed          Keep reads/pairs missing expected 5' primers
  --gzip-level INT          Gzip compression level [default: 6]

Matching:
  -e, --error-rate FLOAT    Maximum errors per aligned primer base [default: 0.1]
  --overlap INT             Minimum primer overlap [default: 8]
  --no-indels               Allow substitutions only

Performance and reporting:
  -t, --threads INT         Worker threads [default: 1]
  --batch-size INT          Reads or pairs per batch [default: 4096]
  --stats                   Print trimming counts to stderr
  -h, --help                Show this help
```

For paired reads, the command constructs these linked patterns internally:

```text
R1: FWD...reverse-complement(REV)
R2: REV...reverse-complement(FWD)
```

The expected 5' primer must be present on both mates by default. Opposite-primer
sequence at the 3' end is optional and is removed as read-through contamination
when found. Consequently, the following performs the PCR-oriented equivalent
of linked Cutadapt specifications while avoiding manual reverse complements:

```bash
seqfu primers --fwd FWDPRIMER --rev REVPRIMER \
  -1 sample_R1.fastq.gz -2 sample_R2.fastq.gz \
  -o amplicons_R1.fastq.gz -O amplicons_R2.fastq.gz
```

Use `--keep-untrimmed` to retain pairs missing either expected 5' primer. A mate
without its expected primer is written unchanged; a matching mate in the same
pair is still trimmed. IUPAC-degenerate primers are supported:

```bash
seqfu primers \
  --fwd CCTACGGGNGGCWGCAG \
  --rev GGACTACHVGGGTATCTAATCC \
  -1 sample_R1.fastq.gz -2 sample_R2.fastq.gz \
  -o amplicons_R1.fastq.gz -O amplicons_R2.fastq.gz
```

For single-end input, the forward primer is required at the 5' end and the
reverse-complemented reverse primer is removed from the 3' end when present.

## Output and statistics

Output format is FASTQ. A `.gz` suffix enables gzip compression; compression
level is controlled with `--gzip-level`. Output files cannot overwrite input
files, and split paired outputs must use different paths.

`--stats` writes processed, written, discarded, 5'-trimmed, and 3'-trimmed
counts to standard error. With multiple threads, reads are processed in bounded
batches while output remains in input order.
