#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


BINDIR="$DIR/../bin/"
BIN="$BINDIR"/seqfu
FILES="$DIR"/../data/

iInterleaved="$FILES"/interleaved.fq.gz
iPair1="$FILES"/illumina_1.fq.gz
iPair2="$FILES"/illumina_2.fq.gz
iAmpli="$FILES"/filt.fa.gz
iSort="$FILES"/sort.fa
iMini="$FILES"/target.fa

ERRORS=0
echo "# Minimal test suite"
echo "---------------------------------------"

# Binary works
"$BIN" > /dev/null || { echo "Binary not working: $BIN"; exit 1; }
echo "OK: Binary running"

for MOD in head tail view qual derep sort count stats grep rc interleave deinterleave count;
do
  BINCOUNT=$((BINCOUNT+1))
  echo " $BINCOUNT. $MOD"
  "$BIN" "$MOD" --help >/dev/null  2>&1 || {  echo "Help for $MOD returned non-zero"; exit 1; }
done

# Check version

VERSION=$("$BIN" version)
grep $VERSION $DIR/../seqfu.nimble

# Dereiplicate
if [[ $("$BIN" derep "$iAmpli"  | grep -c '>') -eq "18664" ]]; then
	echo "OK: Dereplicate"
  PASS=$((PASS+1))
else
	echo "ERR: Dereplicate didnt return 18664 seqs"
	ERRORS=$((ERRORS+1))
fi

if [[ $("$BIN" derep "$iAmpli" -m 10000 2>/dev/null | grep -c '>') -eq "1" ]]; then
	echo "OK: Dereplicate, min size"
  PASS=$((PASS+1))
else
	echo "ERR: Dereplicate, min size"
	ERRORS=$((ERRORS+1))
fi

# Grep
if [[ $("$BIN" grep -n seq.1 "$FILES"/comm.fa  | grep -c '>') -eq "1" ]]; then
	echo "OK: grep, name"
  PASS=$((PASS+1))
else
	echo "ERR: grep, name"
	ERRORS=$((ERRORS+1))
fi

if [[ $("$BIN" grep -c -n size=3 "$FILES"/comm.fa  | grep -c '>') -eq "1" ]]; then
	echo "OK: grep, size"
  PASS=$((PASS+1))
else
	echo "ERR: grep, size"
	ERRORS=$((ERRORS+1))
fi

# List
if [[ $("$BIN" list "$FILES"/prot.list "$FILES"/prot.faa  | grep -c '>') -eq "5" ]]; then
	echo "OK: list, default"
  PASS=$((PASS+1))
else
	echo "ERR: list, default not 5"
	ERRORS=$((ERRORS+1))
fi
if [[ $("$BIN" list -c "$FILES"/prot.list "$FILES"/prot.faa  | grep -c '>') -eq "4" ]]; then
	echo "OK: list, with comments"
  PASS=$((PASS+1))
else
	echo "ERR: list, with comments not 4"
	ERRORS=$((ERRORS+1))
fi

# Homopolymer
HOMO="$(dirname "$BIN")/fu-homocomp"
if [[ -e "$HOMO" ]]; then
  ORIGINAL=$(grep . "$FILES"/homopolymer.fq | wc -c)
  COMPRESSED=$($HOMO "$FILES"/homopolymer.fq | wc -c )
  if [[ $ORIGINAL -gt $COMPRESSED ]]; then
    echo "OK: homopolymer pass $ORIGINAL > $COMPRESSED"
    PASS=$((PASS+1))
  else
    echo "ERR: homopolymer failed $ORIGINAL original length, $COMPRESSED compressed length"
    ERRORS=$((ERRORS+1))
  fi
fi

# Interleave
if [[ $("$BIN" ilv -1 "$iPair1" -2 "$iPair2" | wc -l) == $(cat "$iPair1" "$iPair2" | gzip -d | wc -l ) ]]; then
	echo "OK: Interleave"
  PASS=$((PASS+1))
else
	echo "ERR: Interleave differs cat/wc"
	ERRORS=$((ERRORS+1))
fi

# Deinterleave
"$BIN" dei "$iInterleaved" -o testtmp
if [[ $(grep . testtmp_R{1,2}.fq | wc -l) == $(gzip -dc "$iInterleaved" | wc -l ) ]]; then
	echo "OK: Deinterleave"
  PASS=$((PASS+1))
else
	echo "ERR: Deinterleave   "
	ERRORS=$((ERRORS+1))
fi
rm testtmp_*

# Count
if [[ $("$BIN" count "$iAmpli" | cut -f 2) == $(gzip -dc "$iAmpli" | grep -c '>' ) ]]; then
	echo "OK: Count"
  PASS=$((PASS+1))
else
	echo "ERR: Count \"$BIN\" count \"$iAmpli\": differs grep/wc"
	ERRORS=$((ERRORS+1))
fi

if [[ $("$BIN" count "$iPair1"  "$iPair2" | wc -l) -eq 1 ]]; then
	echo "OK: Count pairs"
  PASS=$((PASS+1))
else
	echo "ERR: Count pairs"
	ERRORS=$((ERRORS+1))
fi

if [[ $("$BIN" count -u "$iPair1"  "$iPair2" | wc -l) -eq 2 ]]; then
	echo "OK: Count pairs, split"
  PASS=$((PASS+1))
else
	echo "ERR: Count pairs, split"
	ERRORS=$((ERRORS+1))
fi


## Sort by size (asc)
if [[ $("$BIN" sort --asc "$iSort" | head -n 1| cut -c 2-6) -eq 'short' ]]; then
  echo "OK: Sort by size"
  PASS=$((PASS+1))
else
  echo "ERR: Sort by size failed"
  ERRORS=$((ERRORS+1))
fi

## Head 
if [[ $("$BIN" head -n 1 "$iInterleaved" | wc -l) -eq 4 ]]; then
  echo "OK: Head 1 sequence"
  PASS=$((PASS+1))
else
  echo "ERR: Head failed"
  ERRORS=$((ERRORS+1))
fi



## Tail 
if [[ $("$BIN" tail -n 1 "$iInterleaved" | wc -l) -eq 4 ]]; then
  echo "OK: tail 1 sequence"
  PASS=$((PASS+1))
else
  echo "ERR: Tail failed"
  ERRORS=$((ERRORS+1))
fi



##QUal
if [[ $("$BIN" qual  "$iInterleaved" | grep 'Illumina-1.8' | wc -l ) -eq 1 ]]; then
  echo "OK: qual tested"
  PASS=$((PASS+1))
else
  echo "ERR: qual failed"
  ERRORS=$((ERRORS+1))
fi

## External

# Seqfu ORF
ORF1=$("$BINDIR"/fu-orf -1 "$iPair1" -m 29 -r | grep -c '>')
if [[ $ORF1 -eq 20 ]]; then
  echo "OK: fu-orf [-1] tested"
  PASS=$((PASS+1))
else
  echo "ERR: fu-orf [-1] test failed: $ORF1 != 20"
  ERRORS=$((ERRORS+1))
fi

ORFSE=$("$BINDIR"/fu-orf "$iPair1" -m 29 -r  | grep -c '>')
if [[ $ORFSE -eq 20 ]]; then
  echo "OK: fu-orf [Single] tested"
  PASS=$((PASS+1))
else
  echo "ERR: fu-orf [Single] test failed: $ORFSE != 20"
  ERRORS=$((ERRORS+1))
fi

ORF2=$("$BINDIR"/fu-orf -r -m 29 -1 "$iPair1" -2 "$iPair2" | grep -c '>')
if [[ $ORF2 -gt 4 ]]; then
  echo "OK: fu-orf [Paired] tested"
  PASS=$((PASS+1))
else
  echo "ERR: fu-orf [Paired] test failed: $ORF2 != 5"
  ERRORS=$((ERRORS+1))
fi

if [[ $("$BINDIR"/fu-sw -q "$FILES"/query.fa -t "$FILES"/target.fa | grep -c 'Score') -eq 2 ]]; then
  echo "OK: fu-sw tested"
  PASS=$((PASS+1))
else
  echo "ERR: fu-sw test failed: != 2"
  ERRORS=$((ERRORS+1))
fi
## STREAMING

if [[ $( gzip -dc  "$iInterleaved" | "$BIN" head -n 1 2>/dev/null | wc -l) -eq 4 ]]; then
  echo "OK: Head 1 sequence (stream)"
  PASS=$((PASS+1))
else
  echo "ERR: Head failed"
  ERRORS=$((ERRORS+1))
fi

if [[ $(gzip -dc  "$iInterleaved" | "$BIN" tail -n 1 2>/dev/null | wc -l) -eq 4 ]]; then
  echo "OK: tail 1 sequence (stream)"
  PASS=$((PASS+1))
else
  echo "ERR: tail failed"
  ERRORS=$((ERRORS+1))
fi

if [[ $("$BIN" head -n 6  "$iInterleaved" | "$BIN" tail -n 2 2>/dev/null | wc -l) -eq 8 ]]; then
  echo "OK: head/tail 1 sequence (stream)"
  PASS=$((PASS+1))
else
  echo "ERR: head/tail failed"
  ERRORS=$((ERRORS+1))
fi

# CAT
if [[ $("$BIN" cat "$iMini" | head -n 1) == ">ecoli comment" ]]; then
  echo "OK: cat: default"
  PASS=$((PASS+1))
else
  echo "ERR: cat: default"
  ERRORS=$((ERRORS+1))
fi

if [[ $("$BIN" cat "$iMini" -s | head -n 1) == ">ecoli" ]]; then
  echo "OK: cat: strip comment"
  PASS=$((PASS+1))
else
  echo "ERR: cat: strip comment"
  ERRORS=$((ERRORS+1))
fi

if [[ $("$BIN" cat -z -p test "$iMini" | head -n 1) == ">test_1 comment" ]]; then
  echo "OK: cat: prefix"
  PASS=$((PASS+1))
else
  echo "ERR: cat: prefix not found"
  ERRORS=$((ERRORS+1))
fi

if [[ $("$BIN" cat -b "$iMini" -s | head -n 1) != ">target_ecoli" ]]; then
  echo "ERR: cat: basename not added"
  ERRORS=$((ERRORS+1))
else
  echo "OK: cat: added basename"
  PASS=$((PASS+1))
fi

## fu-cov
TOTFILT=$("$BINDIR"/fu-cov "$FILES/ctgs.fa.gz" -c 100 -x 200 2>/dev/null | grep -c '>')
if [[ $((TOTFILT+0)) -eq 1 ]]; then
  echo "OK: fu-cov"
  PASS=$((PASS+1))
else
  echo "ERR: fu-cov was supposed to select 1 sequence, $TOTFILT found "
  ERRORS=$((ERRORS+1))
fi
 
echo ""
for TEST in "$DIR"/test-*.sh;
do
  BASE=$(basename "$TEST"  | cut -f 1 -d .)
  if [[ -e $TEST ]]; then
    echo " - Tests for: '$BASE'";
    source "$TEST"
  fi
done

## Check docs
echo ""
echo "# CHECKING DOCS"

for SUB in utilities tools;
do
  echo " - Utilities sort order in $SUB"
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
echo ""
echo "# Checking release"
LOCAL_RELEASE=$(grep version "$DIR/../seqfu.nimble"  | cut -f 2 -d = | sed 's/[" ]//g')
GH_RELEASE=$(curl -s https://api.github.com/repos/telatin/seqfu2/releases/latest  | perl -nE 'my ($tag, $val) = split /:/, $_; if ($tag=~/tag_name/) { my @tag = split /"/, $val; for my $i (@tag) { $i =~s/[^0-9.]//g; say $i if (length($i) > 2); } }')

if [[ $LOCAL_RELEASE == $GH_RELEASE ]]; then
  echo " ****************************************************************************"
  echo " Local $LOCAL_RELEASE matches remote $GH_RELEASE"
  echo " Set RELEASE=1 to make this warning fatal (e.g. when preparing a new release)"
  echo " ****************************************************************************"
  echo
  if [[ $RELEASE == 1 ]];
  then
   echo "ERROR: Release matches last version on GitHub"
   ERRORS=$((ERRORS+1))
  fi
else
  echo "OK:  $LOCAL_RELEASE != $GH_RELEASE (remote)"
  PASS=$((PASS+1))
fi



### Check failures
echo "---------------------------------------"
if  [[ $ERRORS -gt 0 ]]; then
	echo "FAIL: $ERRORS test failed."
	exit 1
else
	echo "PASS ($PASS tests)"
fi
