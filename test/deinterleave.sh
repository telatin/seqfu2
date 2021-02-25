#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
PLATFORM=""
if [[ $(uname) == "Darwin" ]]; then
 PLATFORM=""
fi
BIN=$DIR/../bin/seqfu${PLATFORM}
FILES=$DIR/../data/

# Files
iInterleaved=$FILES/interleaved.fq.gz
iInterleavedFQ=$FILES/tests/interleavedFQ.fq
iInterUNEVEN=$FILES/tests/unevenInterleaved.fq
iInterLONG1=$FILES/tests/longerone.fq
iInterLONG2=$FILES/tests/longertwo.fq
iAllEMPTY=$FILES/tests/empty.fq
iAllMISS=$FILES/tests/nonexistent.fq

ERRORS=0
echo "# Testing -deinterleave- function"

# Binary works
$BIN > /dev/null|| { echo "Binary not working"; exit 1; }
echo "OK: Running"

# Deinterleave normal gzipped
echo ""
echo "1. TEST - de-interleave a gzipped fastq file"
echo "COMMAND: $BIN dei -v -o testtmp $iInterleaved"
$BIN dei -v -o testtmp $iInterleaved
if [[ $(cat testtmp_R1.fq testtmp_R2.fq  | wc -l) == $(cat $iInterleaved | gunzip | wc -l ) ]]; then
	echo "OK: Deinterleave gzipped fastq"
else
	echo "ERR: Deinterleave gzipped fastq"
	ERRORS=$((ERRORS+1))
fi

# Deinterleave normal
echo ""
echo "2. TEST - de-interleave a fastq file"
echo "COMMAND: $BIN dei -v -o testtmpFQ $iInterleavedFQ"
$BIN dei -v -o testtmpFQ $iInterleavedFQ
if [[ $(cat testtmpFQ_R1.fq testtmpFQ_R2.fq  | wc -l) == $(cat $iInterleavedFQ | wc -l ) ]]; then
        echo "OK: Deinterleave fastq"
else
        echo "ERR: Deinterleave fastq"
        ERRORS=$((ERRORS+1))
fi

# Deinterleave normal other extension
echo ""
echo "3. TEST - de-interleave a fastq file into custom extension"
echo "COMMAND: $BIN dei -v -f _forward.fq -r _reverse.fq -o testtmpcus $iInterleaved"
$BIN dei -v -f _forward.fq -r _reverse.fq -o testtmpcus $iInterleaved
if [[ $(cat testtmpcus_forward.fq testtmpcus_reverse.fq  | wc -l) == $(cat $iInterleaved | gunzip | wc -l ) ]]; then
	echo "OK: Deinterleave fastq custom extension"
else
	echo "ERR: Deinterleave fastq custom extension"
	ERRORS=$((ERRORS+1))
fi

# Deinterleave uneven fastq
# needed: warning if more reads of either R1 or R2
echo ""
echo "4. TEST - de-interleave a fastq file with uneven number of reads"
echo "COMMAND: $BIN dei -v -o testtmpuneven $iInterUNEVEN"
$BIN dei -v -o testtmpuneven $iInterUNEVEN

# Deinterleave empty fastq
# needed: warning if input file is empty "no sequenes in file X"; at the moment: produces empty R1 and R2 but no warning
#echo ""
#echo "5. TEST - de-interleave empty fastq file"
#echo "COMMAND: $BIN dei -v -o testtmpempty $iAllEMPTY"
#$BIN dei -v -o testtmpempty $iAllEMPTY

# Deinterleave nonexistent
# needed: warning if input file is nonexistent; at the moment: error
#echo ""
#echo "6. TEST - de-interleave a non-existent fastq file"
#echo "COMMAND: $BIN dei -v -o testtmpmiss $iAllMISS"
#$BIN dei -v -o testtmpmiss $iAllMISS

rm testtmp*
