---
sort: 3
---

# fu-orf

Extraction of ORFs from **paired-end** Illumina datasets. Open reading frames are
defined as a stretch of aminoacids not interrupted by stop codons: this program
does not perform any _gene finding_ procedure and merely extracts ORFs (under
the assumption that, running on raw reads, fragments are expected).

```text
Extract ORFs from Paired-End reads.

Usage:
  porfast [options] 

Options:
  -h, --help
  -1, --R1=R1                FASTQ file, first pair
  -2, --R2=R2                FASTQ file, second pair
  -m, --min-size=MIN_SIZE    Minimum ORF size (aa) (default: 26)
  -p, --prefix=PREFIX        Rename reads using this prefix
  --pool-size=POOL_SIZE      Size of the batch of reads to process per thread (default: 260)
  -v, --verbose              Print verbose info
  -j, --join                 Try joining paired ends
  --min-overlap=MIN_OVERLAP  Minimum PE overlap (default: 12)
  --max-overlap=MAX_OVERLAP  Maximum PE overlap (default: 200)
  --min-identity=MIN_IDENTITY
                             Minimum sequence identity in overlap (default: 0.85)

```

## Example usage

The repository comes with a test dataset in the _reads_ directory
```
fu-orf -1 reads/R1.fq.gz -2 reads/R2.fq.gz --min-size 80 | seqfu head -n 5
```
will produce:
```
>D00200:311:HG3T5BCXY:1:1116:14226:46994_1/1
LWAECVEIGIEARKALLARCKLFRPFIPPVVDGKLWQDYPTSVLASDRRFFSFEPGAKWHGFEGYAADQYFVDPFKLLLTTPG
>D00200:311:HG3T5BCXY:1:1204:12081:27801_1/2
CKLLPFCVALALTGCSLAPDYQRPAMPVPQQFSLSQNGLVNAADNYQNAGWRTFFVDNQVKTLISEALVNNRDLRMATLKVQ
>D00200:311:HG3T5BCXY:1:1204:12081:27801_2/2
SRYSRIARATCGGNMKLLIVEDEKKTGEYLTKGLTEAGFVVDLADNGLNGYHLAMTGDYDLIILDIMLPDVNGWDIVRMLR
>D00200:315:HG3F5BCXY:1:1105:16316:63851_1/1
YNVFNNSSRKEILIMTKYIAHIEPLNAEKIGTKAHGTATFEEKGDELHIHVEMFDTPANIEHWEHFHGFPNGQKAHVPTAA
>D00200:315:HG3F5BCXY:1:1105:8757:70971_1/3
SQTKKDIYDAMQGLEYEINTMFSSQGQTPFTTLGFGLGTSWIEKEIQKDILRIRIKGLGRERRTAIFPKLVFTIKKGLNLHP
```