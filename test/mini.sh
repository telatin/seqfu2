#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
PLATFORM=""
#if [[ $(uname) == "Darwin" ]]; then
# PLATFORM="_mac"
#fi
BIN=$DIR/../bin/seqfu${PLATFORM}
FILES=$DIR/../data/

iInterleaved=$FILES/interleaved.fq.gz
iPair1=$FILES/illumina_1.fq.gz
iPair2=$FILES/illumina_2.fq.gz
iAmpli=$FILES/filt.fa.gz
iSort=$FILES/sort.fa

ERRORS=0
echo "# Minimal test suite"

# Binary works
$BIN > /dev/null|| { echo "Binary not working"; exit 1; }
echo "OK: Running"

# Dereiplicate
if [[ $($BIN derep $iAmpli  | grep -c '>') -eq "18664" ]]; then
	echo "OK: Dereplicate"
else
	echo "ERR: Dereplicate didnt return 18664 seqs"
	ERRORS=$((ERRORS+1))
fi

if [[ $($BIN derep $iAmpli -m 10000 2>/dev/null | grep -c '>') -eq "1" ]]; then
	echo "OK: Dereplicate, min size"
else
	echo "ERR: Dereplicate, min size"
	ERRORS=$((ERRORS+1))
fi

# Interleave
if [[ $($BIN ilv -1 $iPair1 -2 $iPair2 | wc -l) == $(cat $iPair1 $iPair2 | gzip -d | wc -l ) ]]; then
	echo "OK: Interleave"
else
	echo "ERR: Interleave $($BIN ilv -1 $iPair1 -2 $iPair2 | wc -l) -eq $(cat $iPair1 $iPair2| gzip -d | wc -l )"
	ERRORS=$((ERRORS+1))
fi

# Deinterleave
$BIN dei $iInterleaved -o testtmp_
if [[ $(cat testtmp_* | wc -l) == $(cat $iInterleaved | gzip -d | wc -l ) ]]; then
	echo "OK: Deinterleave"
else
	echo "ERR: Deinterleave"
	ERRORS=$((ERRORS+1))
fi
rm testtmp_*

# Count
if [[ $($BIN count $iAmpli | cut -f 2) == $(cat $iAmpli | gzip -d | grep -c '>' ) ]]; then
	echo "OK: Count"
else
	echo "ERR: Count"
	ERRORS=$((ERRORS+1))
fi

if [[ $($BIN count $iPair1  $iPair2 | wc -l) -eq 1 ]]; then
	echo "OK: Count pairs"
else
	echo "ERR: Count pairs"
	ERRORS=$((ERRORS+1))
fi

if [[ $($BIN count -u $iPair1  $iPair2 | wc -l) -eq 2 ]]; then
	echo "OK: Count pairs, split"
else
	echo "ERR: Count pairs, split"
	ERRORS=$((ERRORS+1))
fi


## Sort by size (asc)
if [[ $($BIN sort --asc $iSort| head -n 1| cut -c 2-6) -eq 'short' ]]; then
  echo "OK: Sort by size"
else
  echo "ERR: Sort by size failed"
  ERRORS=$((ERRORS+1))
fi

if  [[ $ERRORS -gt 0 ]]; then
	echo "FAIL: $ERRORS test failed."
	exit 1
else
	echo "PASS"
fi

echo ""
for TEST in $DIR/*.sh;
do
  BASE=$(basename $TEST  | cut -f 1 -d .)
  if [[ "$BASE" != "mini" ]]; then
    echo " * There are further tests for '$BASE'";
    #bash $TEST;
  fi
done
