# Reference interleave.sh script

```bash
#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
PLATFORM=""
if [[ $(uname) == "Darwin" ]]; then
 PLATFORM=""
fi
BIN=$DIR/../bin/seqfu${PLATFORM}
FILES=$DIR/../data/

# 
iPair1=$FILES/illumina_1.fq.gz
iPair2=$FILES/illumina_2.fq.gz
iPair1a=$FILES/tests/sample1_R1.fq
iPair1b=$FILES/tests/sample1_R2.fq
iPair1b=$FILES/tests/sample1_forward.fq
iPair2b=$FILES/tests/sample1_reverse.fq
iR1LONG1=$FILES/tests/longerone_R1.fq
iR2LONG1=$FILES/tests/longerone_R2.fq
iR1LONG2=$FILES/tests/longertwo_R1.fq
iR2LONG2=$FILES/tests/longertwo_R2.fq
iR1EMPTY=$FILES/tests/empty_R1.fq
iR2EMPTY=$FILES/tests/empty_R2.fq
iAllMISS=$FILES/tests/nonexistent.fq

ERRORS=0
echo "# Testing -interleave- function"

# Binary works
$BIN > /dev/null|| { echo "Binary not working"; exit 1; }
echo "OK: Running"

# Interleave normal R1 and R2 fastq
echo ""
echo "1. TEST - interleave R1 and R2 fastq"
echo "COMMAND: $BIN ilv -v -o testtmpSample1.fq -1 $iPair1a -2 $iPair2a"
$BIN ilv -v -o testtmpSample1.fq -1 $iPair1a -2 $iPair2a
if [[ $(cat testtmpSample1.fq | wc -l) == $(cat $iPair1a $iPair1a | wc -l ) ]]; then
	echo "OK: Interleave fastq _R1 and _R2"
else
	echo "ERR: Interleave fastq _R1 and _R2"
	ERRORS=$((ERRORS+1))
fi


# Interleave normal gzipped - find _2 by only giving _1
echo ""
echo "2. TEST - interleave gesipped fastq - _1 and let _2 automatically find"
echo "COMMAND: BIN ilv -v -o testtmpS1.fq -1 $iPair1"
$BIN ilv -v -o testtmpS1.fq -1 $iPair1
if [[ $(cat testtmpS1.fq | wc -l) == $(cat $iPair1 $iPair2 | gunzip | wc -l ) ]]; then
	echo "OK: Interleave fastq _1 and _2"
else
	echo "ERR: Interleave fastq _1 and _2"
	ERRORS=$((ERRORS+1))
fi

# Interleave normal  custom extension
echo ""
echo "3. TEST - interleave _forward and let _reverse automatically find by specifying -f and -r "
echo "COMMAND: $BIN ilv -v -o testtmpS2.fq -1 $iPair1b -f forward -r reverse"
$BIN ilv -v -o testtmpS2.fq -1 $iPair1b -f forward -r reverse
if [[ $(cat testtmpS2.fq | wc -l) == $(cat $iPair1b $iPair2b | wc -l ) ]]; then
	echo "OK: Interleave fastq _forward and _reverse"
else
	echo "ERR: Interleave fastq _forward and _reverse"
	ERRORS=$((ERRORS+1))
fi


# Interleave unbalanced reads
echo ""
echo "4. TEST - interleave R1 (more reads) and R2 (fewer reads) of fastq"
echo "COMMAND: $BIN ilv -v -o testtmpLong1.fq -1 $iR1LONG1 -2 $iR2LONG1 2> testtmpnope"
$BIN ilv -v -o testtmpLong1.fq -1 $iR1LONG1 -2 $iR2LONG1

# Interleave unbalanced reads
echo ""
echo "5. TEST - interleave R1 (fewer reads) and R2 (more reads) of fastq"
echo "COMMAND: $BIN ilv -v -o testtmpLong2.fq -1 $iR1LONG2 -2 $iR2LONG2 2> testtmpnope2"
$BIN ilv -v -o testtmpLong2.fq -1 $iR1LONG2 -2 $iR2LONG2

# Interleave two same fastq
# FATAL ERROR: First file and second file are equal.
echo ""
echo "6. TEST - interleave two same fastq files"
echo "COMMAND: $BIN ilv -v -1 $iPair1a -2 $iPair1a"
$BIN ilv -v -1 $iPair1a -2 $iPair1a

# Interleave two empty fastq
# needed: warning if input files are empty "no sequenes in file X"; at the moment: produces empty output but no warning
echo ""
echo "7. TEST - interleave two empty fastq files"
echo "COMMAND: $BIN ilv -v -o testtmpintempty.fq -1 $iR1EMPTY -2 $iR2EMPTY"
$BIN ilv -v -o testtmpintempty.fq -1 $iR1EMPTY -2 $iR2EMPTY
if [[ $(cat testtmpintempty.fq | wc -l ) == "       0"  ]]; then
        echo "OK: Two empty input files resulted in one empty output file"
else
        echo "ERR: interleave two empty fastq files"
        ERRORS=$((ERRORS+1))
fi

# Interleave nonexistent R2
# needed: warning if input R2 file is nonexistent; at the moment: error
#echo ""
#echo "8. TEST - interleave one existent R1 fastq file with one non-existent file"
#echo "COMMAND: $BIN ilv -v -o testtmpmiss -1 $iPair1a -2 $iAllMISS"
#$BIN ilv -v -o testtmpmiss -1 $iPair1a -2 $iAllMISS 

rm testtmp*
 
``` 