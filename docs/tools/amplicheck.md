---
layout: default
title: seqfu amplicheck
parent: Core Tools
---

# seqfu amplicheck

`seqfu amplicheck` inspects single-end or paired-end amplicon FASTQ files and
writes a JSON report with DADA2-style quality-control recommendations. It does
not run DADA2 or R.

![Screenshot of "seqfu amplicheck"]({{site.baseurl}}/img/seqfu-amplicheck.png "SeqFu amplicheck report")

```text
Usage:
  amplicheck [options] <FASTQ>...

Options:
  --single-end              Treat every positional FASTQ as a separate sample
  --fwd-tag STR             Forward read tag for batch pairing [default: _R1]
  --rev-tag STR             Reverse read tag for batch pairing [default: _R2]
  --max-reads INT           Stop after INT scanned reads or pairs per sample; 0 = all [default: 500000]
  --subsample FLOAT         Deterministic fraction of scanned reads or pairs to analyze [default: 1.0]
  --only STAGES             Run only comma-separated stages: primers,length,quality,merge,sweep
  --skip STAGES             Skip comma-separated stages; "overlap" is accepted as "merge"
  --fwd-primers LIST        Comma-separated forward primer sequences
  --rev-primers LIST        Comma-separated reverse primer sequences
  --sweep                   Run truncLen/maxEE sweep
  --truncLen-grid LIST      Comma-separated truncLen values for --sweep; 0 = no truncation
  --maxEE-grid LIST         Comma-separated maxEE values for --sweep
  --amplicon MODE           One of auto, 16s, its [default: auto]
  --outdir DIR              Output directory [default: amplicheck_out]
  --no-json                 Do not write JSON report
  --text                    Write human-readable report.txt
  --plot                    Write self-contained HTML quality plots
  --threads INT             Number of samples to process in parallel [default: 1]
  --min-recommend-reads INT  Minimum sampled reads required for recommendations [default: 5000]
  -v, --verbose             Print parsing progress and per-sample summaries
```

## Examples

Inspect one single-end sample:

```bash
seqfu amplicheck sample_R1.fastq.gz --text --plot
```

Inspect multiple single-end samples:

```bash
seqfu amplicheck --single-end data/*_R1.fastq.gz
```

Inspect one pair:

```bash
seqfu amplicheck sample_R1.fastq.gz sample_R2.fastq.gz --text
```

Inspect multiple pairs by tag substitution:

```bash
seqfu amplicheck data/*.fastq.gz --fwd-tag _R1 --rev-tag _R2
```

Scan up to 500,000 read pairs but analyze one every ten:

```bash
seqfu amplicheck sample_R1.fastq.gz sample_R2.fastq.gz --max-reads 500000 --subsample 0.1
```

Scan the whole pair and analyze one every hundred:

```bash
seqfu amplicheck sample_R1.fastq.gz sample_R2.fastq.gz --max-reads 0 --subsample 0.01
```

`--max-reads` counts scanned reads for single-end input and scanned read pairs
for paired-end input. `--subsample` is deterministic periodic thinning over
those scanned records: `0.1` keeps 1 every 10, `0.2` keeps 2 every
10, and `0.01` keeps 1 every 100.

Use `-v` to print one start line per sample, periodic scanned/sampled progress,
a parse completion line, and a compact per-sample summary on stderr. Report files
remain clean.

Use `--threads` to analyze independent samples concurrently. A single-end file
is one job and a paired-end R1/R2 pair is one job. Results and verbose logs are
emitted in input order regardless of worker completion order. The effective
thread count is capped by the number of samples and SeqFu's Malebolgia worker
pool size.

By default, primer detection checks the bundled 16S primer table. Supplying
`--fwd-primers`, `--rev-primers`, or both replaces that table for the run, so
only the supplied IUPAC primer sequences are considered. Multiple sequences can
be comma-separated. A primer call requires at least 80% identity within an
individual read and support from at least three reads and 10% of sampled reads.
The report still includes the observed prefix consensus when no primer reaches
those thresholds, but it is not marked as a detected primer.

Recommendations require 5,000 sampled reads by default. `--subsample` therefore
affects recommendation eligibility as well as analysis cost. Use
`--min-recommend-reads` to change the threshold for small validation datasets.

## Output

By default, output is written to:

```text
amplicheck_out/
└── report.json
```

With `--plot`, HTML output is added:

```text
amplicheck_out/
├── report.json
└── plots/
    ├── index.html
    └── sample.html
```

With `--text`, `report.txt` is written alongside JSON.
With `--plot`, SeqFu writes one standalone HTML quality report per sample under
`plots/`, plus `plots/index.html`. The index page is a self-contained sortable,
paged sample table with quality-report links and summary fields such as primer
detection, read counts, mean quality, average overlap, merge rate, and suggested
truncation settings. `--plot` can also be used as the only output format with
`--no-json`.

Example outputs:

- [report.json]({{site.baseurl}}/amplicheck/report.json)
- [report.txt]({{site.baseurl}}/amplicheck/report.txt)
- [plots/index.html]({{site.baseurl}}/amplicheck/plots/index.html)

The JSON report includes:

1. input layout, file or pair, and sample identifier
2. `n_reads_scanned`, `n_reads_sampled`, and `n_reads_total` when known
3. recommendation read threshold and whether enough reads were sampled
4. primer detection and bundled or custom primer labels
5. read-length summaries
6. per-position quality means and binned-quality classification
7. native overlap estimates
8. recommendation fields: `truncLen`, `maxEE`, `truncQ`, and strategy

For single-end input, the default stages are primer, length, and quality
analysis. Pair-only merge and sweep stages are unavailable and produce an error
when explicitly requested. Reverse-read fields and primer orientation are
serialized as `null`. The recommendation contains scalar `truncLen` and `maxEE`
values, plus `truncLen_fwd` as a compatibility alias.

The HTML quality pages contain the sampled per-cycle Q-score count matrix and
render mean/median/quantile curves plus a Q-score heatmap in the browser.
Single-end pages render one read panel and omit reverse-read and overlap columns
from the index. Reads longer than 10,000 bases are skipped for quality
plotting/profile accumulation.
