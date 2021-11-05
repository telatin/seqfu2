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
  fu-orf --help | --codes
  
  Input files:
    -1, --R1 FILE           First paired end file
    -2, --R2 FILE           Second paired end file

  ORF Finding and Output options:
    -m, --min-size INT      Minimum ORF size (aa) [default: 25]
    -p, --prefix STRING     Rename reads using this prefix
    -r, --scan-reverse      Also scan reverse complemented sequences
    -c, --code INT          NCBI Genetic code to use [default: 1]
    -l, --min-read-len INT  Minimum read length to process [default: 25]
  
  Paired-end optoins:
    -j, --join              Attempt Paired-End joining
    --min-overlap INT       Minimum PE overlap [default: 12]
    --max-overlap INT       Maximum PE overlap [default: 200]
    --min-identity FLOAT    Minimum sequence identity in overlap [default: 0.80]
  
  Other options:
    --codes                 Print NCBI genetic codes and exit
    --pool-size INT         Size of the sequences array to be processed
                            by each working thread [default: 250]
    --verbose               Print verbose log
    --debug                 Print debug log  
    --help                  Show help
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


## Genetic codes

Genetic codes can be changed using [NCBI Genetic Codes](https://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi).

Type `fu-orf --codes` to print the following list.

 * 1.  The Standard Code
 * 2.  The Vertebrate Mitochondrial Code
 * 3.  The Yeast Mitochondrial Code
 * 4.  The Mold, Protozoan, and Coelenterate Mitochondrial Code and the Mycoplasma/Spiroplasma Code
 * 5.  The Invertebrate Mitochondrial Code
 * 6.  The Ciliate, Dasycladacean and Hexamita Nuclear Code
 * 9.  The Echinoderm and Flatworm Mitochondrial Code
 * 10. The Euplotid Nuclear Code
 * 11. The Bacterial, Archaeal and Plant Plastid Code
 * 12. The Alternative Yeast Nuclear Code
 * 13. The Ascidian Mitochondrial Code
 * 14. The Alternative Flatworm Mitochondrial Code
 * 16. Chlorophycean Mitochondrial Code
 * 21. Trematode Mitochondrial Code
 * 22. Scenedesmus obliquus Mitochondrial Code
 * 23. Thraustochytrium Mitochondrial Code
 * 24. Rhabdopleuridae Mitochondrial Code
 * 25. Candidate Division SR1 and Gracilibacteria Code
 * 26. Pachysolen tannophilus Nuclear Code
 * 27. Karyorelict Nuclear Code
 * 28. Condylostoma Nuclear Code
 * 29. Mesodinium Nuclear Code
 * 30. Peritrich Nuclear Code
 * 31. Blastocrithidia Nuclear Code
 * 33. Cephalodiscidae Mitochondrial UAA-Tyr Code