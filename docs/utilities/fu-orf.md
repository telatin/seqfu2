---
sort: 3
---

# fu-orf

Extraction of ORFs from **paired-end** Illumina datasets.
Open reading frames are defined as a stretch of aminoacids
not interrupted by stop codons:
this program does not perform any _gene finding_ procedure
and merely extracts ORFs (under the assumption that, running
on raw reads, fragments are expected).

```text
fu-orf

  Extract ORFs from Paired-End reads.

  Usage: 
  fu-orf [options] -1 File_R1.fq

  Options:
    -1, --R1 FILE          First paired end file
    -2, --R2 FILE          Second paired end file
    -m, --min-size INT     Minimum ORF size (aa) [default: 25]
    -p, --prefix STRING    Rename reads using this prefix
    --min-overlap INT      Minimum PE overlap [default: 12]
    --max-overlap INT      Maximum PE overlap [default: 200]
    --min-identity FLOAT   Minimum sequence identity in overlap [default: 0.80]
    -j, --join             Attempt Paired-End joining
    --pool-size INT        Size of the sequences array to be processed
                           by each working thread [default: 250]
    --verbose              Print verbose log
    --help                 Show help
```

## Example usage

The repository comes with a test dataset in the _reads_ directory

```bash
fu-orf -1 reads/R1.fq.gz -2 reads/R2.fq.gz --min-size 80 | seqfu head -n 5
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
