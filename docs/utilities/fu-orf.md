---
sort: 3
---

# fu-orf

Extraction of ORFs from raw reads datasets (and other
sequence files).
Open reading frames are defined as a stretch of aminoacids
not interrupted by stop codons:
this program does not perform any _gene finding_ procedure
and merely extracts ORFs (under the assumption that, running
on raw reads, fragments are expected).

A major update was introduced with version **1.8.4**, with
improved reporting (strand and reding frame in the output),
improved tests and `--scan-reverse` option (previously
enabled by default).

```text
fu-orf
 
  Extract ORFs from Paired-End reads.

  Usage: 
  fu-orf [options] <InputFile>  
  fu-orf [options] -1 File_R1.fq
  fu-orf [options] -1 File_R1.fq -2 File_R2.fq
  
  Input files:
    -1, --R1 FILE          First paired end file
    -2, --R2 FILE          Second paired end file

  ORF Finding and Output options:
    -m, --min-size INT     Minimum ORF size (aa) [default: 25]
    -p, --prefix STRING    Rename reads using this prefix
    -r, --scan-reverse     Also scan reverse complemented sequences
  
  Paired-end optoins:
    --min-overlap INT      Minimum PE overlap [default: 12]
    --max-overlap INT      Maximum PE overlap [default: 200]
    --min-identity FLOAT   Minimum sequence identity in overlap [default: 0.80]
    -j, --join             Attempt Paired-End joining
  
  Other options:
    --pool-size INT        Size of the sequences array to be processed
                           by each working thread [default: 250]
    --verbose              Print verbose log
    --help                 Show help
```

## Example usage

Single input file (FASTA or FASTQ):

```bash
fu-orf --min-size 500 data/orf.fa.gz  
```

Paired-end Illumina reads:

```bash
fu-orf --min-size 29  -1 data/illumina_1.fq.gz -2 data/illumina_2.fq.gz 
```

will produce a FASTA output reporting, as comment,
the frame and the total ORFs printed for each sequence:

```text
>filt.1_1 frame=+0 tot=5
RNLIILKMDFFFENFALVGLLYGACQRLNSTKFYLMSTDYLIVKTFNNGSLGSRIDEERS
>filt.1_2 frame=+2 tot=5
WSFRGSKSRNKVSVGEPAEGSLKKFNNFENGFFF
>filt.1_3 frame=+2 tot=5
KLCFGRPSIWGLPEVKLNQILFNVNRLFNSQNFQQRISWFSHR
>filt.1_4 frame=-1 tot=5
NLVEFNLWQAPYRRPTKAKFSKKKSIFKIIKFL
>filt.1_5 frame=-2 tot=5
LLNNRLTLNKIWLSLTSGRPHIEGLPKQSFQKKNPFSKLLNFFNDPSAGSPTETLLRLLLPLNDQ
>filt.2_1 frame=+0 tot=5
TYNQFFINLSHQIITNSQNFQQRISWFSHRNA
>filt.2_2 frame=+1 tot=5
NKLALAVGPACRQRSKLTTNFLSTCHTRLLLIVKTFNNGSLGSRIETQ
>filt.2_3 frame=+2 tot=5
WSFRGSKSRNKVSVGEPAEGSLLICLIAPHVFFFETNLLWRWAQPAARGLNLQPIFYQLVTPDYY
>filt.2_4 frame=-1 tot=5
KIGCKFRPLAAGWAHRQSKFVSKKNTCGAIKQISNDPSAGSPTETLLRLLLPLNDQ
>filt.2_5 frame=-2 tot=5
QVDKKLVVSLDLWRQAGPTAKASLFQRKTHVVQLSKSVMILPQVHLRKPCYDFYFL
```
