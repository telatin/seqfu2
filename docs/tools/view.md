---
layout: default
title: seqfu view
parent: Core Tools
---


# seqfu view

*view*  is one of the core subprograms of *SeqFu*.

It can be used to visually inspect a FASTQ file printing
colored bars for quality scores and highlighting oligonucleotide
matches.

```text
Usage: view [options] <inputfile> [<input_reverse>]

View a FASTA/FASTQ file for manual inspection, allowing to search for
an oligonucleotide.

Options:
  -o, --oligo1 OLIGO     Match oligo, with ambiguous IUPAC chars allowed
                         (rev. compl. search is performed), color blue
  -r, --oligo2 OLIGO     Second oligo to be scanned for, color red
  -q, --qual-scale STR   Quality thresholds, seven values
                         separated by columns [default: 3:15:25:28:30:35:40]

  --match-ths FLOAT      Oligo matching threshold [default: 0.75]
  --min-matches INT      Oligo minimum matches [default: 5]
  --max-mismatches INT   Oligo maxmimum mismataches [default: 2]
  --ascii                Use simple ASCII chars instead of UNICODE to
                         render the quality values
  -Q, --qual-chars       Show quality characters instead of bars
  -n, --nocolor          Disable colored output
  --verbose              Show extra information
  -h, --help             Show this help
```

## Example output

The quality scores are rendered as colored bars (grey, red, yellow, green) of different heights.
Matching oligos are rendered as blue arrows (forward) or red arrows (reverse).

![Screenshot of "seqfu view, action"]({{site.baseurl}}/img/screenshot-view-example.svg "SeqFu view example")


## Important hints

### Disabling wordwrap 

_SeqFu view_ is designed for a manual inspection, and thus it's very convenient to pipe the output to
`less` to avoid being misled by word-wraps:

```bash
seqfu view sequence.fq | less -SR
```

(in `less`: `-S` prevents word-wrap, and `-R` will preserve the colored output)

### Encoding of "graphical" bars

The _graphical_ rendering of the quality values is done using Unicode characters (UTF-8 encoding),
thus requiring both the host system and the terminal emulator to support UTF-8. A simple test 
to check if your terminal supports Unicode is to type:

```bash
echo -e '\xe2\x82\xac'
```

If you see the Euro character (€) then your terminal fully supports UTF-8. If not, you can use
`--ascii` or `--qual-chars`. 

The following screenshot shows how quality scores are rendered using the different options:

*  Default view with quality scale

![Screenshot: Quality scale"]({{site.baseurl}}/img/screenshot-view-qual.svg "SeqFu view: quality scale")

* Graphical representation of the quality with ASCII characters
  
![Screenshot: Quality scale in ASCII]({{site.baseurl}}/img/screenshot-view-qual-ascii.svg "Qualities in ASCII chars")

* Quality encoded as in the FASTQ file, but colored
                                               
![Screenshot: Quality scale as in FASTQ]({{site.baseurl}}/img/screenshot-view-qual-raw.svg  "Qualities as encoded in FASTQ")

## Screenshot

![Screenshot of "seqfu view, help"]({{site.baseurl}}/img/screenshot-view.svg "SeqFu view")

