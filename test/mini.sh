#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
PLATFORM=""
#if [[ $(uname) == "Darwin" ]]; then
# PLATFORM="_mac"
#fi
BINDIR="$DIR/../bin/"
BIN="$BINDIR"/seqfu
FILES=$DIR/../data/

iInterleaved=$FILES/interleaved.fq.gz
iPair1=$FILES/illumina_1.fq.gz
iPair2=$FILES/illumina_2.fq.gz
iAmpli=$FILES/filt.fa.gz
iSort=$FILES/sort.fa
iMini=$FILES/target.fa

ERRORS=0
echo "# Minimal test suite"

# Binary works
$BIN > /dev/null || { echo "Binary not working: $BIN"; exit 1; }
echo "OK: Binary running"

for MOD in head tail view qual derep sort count stats grep rc interleave deinterleave count;
do
  echo " - $MOD"
  $BIN $MOD --help >/dev/null  2>&1 || {  echo "Help for $MOD returned non-zero"; exit 1; }

done

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

# Grep
if [[ $($BIN grep -n seq.1 $FILES/comm.fa  | grep -c '>') -eq "1" ]]; then
	echo "OK: grep, name"
else
	echo "ERR: grep, name"
	ERRORS=$((ERRORS+1))
fi
if [[ $($BIN grep -c -n size=3 $FILES/comm.fa  | grep -c '>') -eq "1" ]]; then
	echo "OK: grep, size"
else
	echo "ERR: grep, size"
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
	echo "ERR: Count $BIN count $iAmpli: $($BIN count $iAmpli | cut -f 2) != $(cat $iAmpli | gzip -d | grep -c '>' )"
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

## Head 
if [[ $($BIN head -n 1 $iInterleaved | wc -l) -eq 4 ]]; then
  echo "OK: Head 1 sequence"
else
  echo "ERR: Head failed"
  ERRORS=$((ERRORS+1))
fi



## Tail 
if [[ $($BIN tail -n 1 $iInterleaved | wc -l) -eq 4 ]]; then
  echo "OK: tail 1 sequence"
else
  echo "ERR: Tail failed"
  ERRORS=$((ERRORS+1))
fi



##QUal
if [[ $($BIN qual  $iInterleaved | grep 'Illumina-1.8' | wc -l ) -eq 1 ]]; then
  echo "OK: qual tested"
else
  echo "ERR: qual failed"
  ERRORS=$((ERRORS+1))
fi
## External

if [[ $($BINDIR/fu-orf -1 $iPair1 -m 29 | grep -c '>') -eq 5 ]]; then
  echo "OK: fu-orf tested"
else
  echo "ERR: fu-orf test failed: $($BINDIR/fu-orf -1 $iPair1 -m 29 | grep -c '>') != 5"
  ERRORS=$((ERRORS+1))
fi

if [[ $($BINDIR/fu-sw -q $FILES/query.fa -t $FILES/target.fa | grep -c 'Score') -eq 2 ]]; then
  echo "OK: fu-sw tested"
else
  echo "ERR: fu-sw test failed: $BINDIR/fu-sw -q $DATA/query.fa -t $DATA/target.fa | grep -c 'Score' != 2"
  ERRORS=$((ERRORS+1))
fi
## STREAMING

if [[ $(cat  $iInterleaved | gzip -d | $BIN head -n 1 2>/dev/null | wc -l) -eq 4 ]]; then
  echo "OK: Head 1 sequence (stream)"
else
  echo "ERR: Head failed"
  ERRORS=$((ERRORS+1))
fi

if [[ $(cat  $iInterleaved | gzip -d | $BIN tail -n 1 2>/dev/null | wc -l) -eq 4 ]]; then
  echo "OK: tail 1 sequence (stream)"
else
  echo "ERR: tail failed"
  ERRORS=$((ERRORS+1))
fi

if [[ $($BIN head -n 6  $iInterleaved | $BIN tail -n 2 2>/dev/null | wc -l) -eq 8 ]]; then
  echo "OK: head/tail 1 sequence (stream)"
else
  echo "ERR: head/tail failed"
  ERRORS=$((ERRORS+1))
fi

# CAT
if [[ $($BIN cat $iMini | head -n 1) == ">ecoli comment" ]]; then
  echo "OK: cat: default"
else
  echo "ERR: cat: default"
  ERRORS=$((ERRORS+1))
fi

if [[ $($BIN cat $iMini -s | head -n 1) == ">ecoli" ]]; then
  echo "OK: cat: strip comment"
else
  echo "ERR: cat: strip comment"
  ERRORS=$((ERRORS+1))
fi

if [[ $($BIN cat -z -p test $iMini | head -n 1) == ">test_1 comment" ]]; then
  echo "OK: cat: prefix"
else
  echo "ERR: cat"
  ERRORS=$((ERRORS+1))
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

## Check docs
echo "# CHECKING DOCS"

for SUB in utilities tools;
do
  echo " * Utilities sort order in $SUB"
   grep ^sort: "$DIR/../docs/$SUB/"[a-z]* | grep -v README | \
   cut -f 2,3 -d : | \
   sort | uniq -c | perl -mTerm::ANSIColor -ne  '
   if ($_=~/^\s*(\S)/)
     { if ($1 != "1") 
        { print Term::ANSIColor::color("red"), " >>> RELEASE WARNING:", 
        Term::ANSIColor::color("reset"), " Wrong sort order: duplicate entry(es)\n"; 
        die;
        } 
     }'  || grep ^sort: "$DIR/../docs/$SUB/"[a-z]* | \
   rev | \
   sort -n | \
   rev 
done

## Check release
echo "# Checking release"
LOCAL_RELEASE=$(cat "$DIR/../seqfu.nimble" | grep version | cut -f 2 -d = | sed 's/[" ]//g')
GH_RELEASE=$(curl -s https://api.github.com/repos/telatin/seqfu2/releases/latest  | perl -nE 'my ($tag, $val) = split /:/, $_; if ($tag=~/tag_name/) { my @tag = split /"/, $val; for my $i (@tag) { $i =~s/[^0-9.]//g; say $i if (length($i) > 2); } }')

if [[ $LOCAL_RELEASE == $GH_RELEASE ]]; then
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
  echo "[PRERELEASE WARNING]: Local $LOCAL_RELEASE matches remote $GH_RELEASE"
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
else
  echo "OK:  $LOCAL_RELEASE != $GH_RELEASE (remote)"
fi



### Check failures
if  [[ $ERRORS -gt 0 ]]; then
	echo "FAIL: $ERRORS test failed."
	exit 1
else
	echo "PASS"
fi
