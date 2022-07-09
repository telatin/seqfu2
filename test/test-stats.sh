#!/bin/bash

# Single file
TMP=$(mktemp)
"$BINDIR"/seqfu stats --basename "$iAmpli" > "$TMP"

WC=$(cat "$TMP" | wc -l | grep -o '[[:digit:]]\+')
SEQS=$(cat "$TMP" | tail -n 1 | cut -f 2)
TOT=$(cat "$TMP" | tail -n 1 | cut -f 3)
N50=$(cat "$TMP" | tail -n 1 | cut -f 5)

MSG="Checking normal output expecting 2 lines: <$WC>"
if [[ $WC == 2 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi


MSG="Checking normal output expecting total seqs 78730: <$SEQS>"
if [[ "$SEQS" == 78730 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

MSG="Checking normal output expecting total bases 24299931: <$TOT>"
if [[ "$TOT" == 24299931 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

MSG="Checking normal N50 to be 316: <$N50>"
if [[ $N50 == 316 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats --basename --csv "$iAmpli" > "$TMP"
N50=$(cat "$TMP" | tail -n 1 | cut -f 5 -d ,)
MSG="Checking CSV output N50 is 316, got: <$N50>"
if [[ $N50 == 316 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Nice output
"$BINDIR"/seqfu stats --basename --nice "$iAmpli" > "$TMP"
WC=$(cat "$TMP" | grep . | wc -l | grep -o '[[:digit:]]\+')
if [[ "$WC" == 5 ]]; then
    echo -e "$OK: Checking nice output expecting 5 lines: <$WC>"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: Checking nice output expecting 5 lines: <$WC>"
    ERRORS=$((ERRORS+1))
fi

# Json 
TMP2=$(mktemp)
"$BINDIR"/seqfu stats --basename --json --multiqc "$TMP2" "$iAmpli" > "$TMP"
WC=$(cat "$TMP" | grep . | wc -l | grep -o '[[:digit:]]\+')
WC2=$(cat "$TMP2" | grep . | wc -l | grep -o '[[:digit:]]\+')
if [[ "$WC2" == 39 ]]; then
    echo -e "$OK: Checking MultiQC output expecting 39 lines: <$WC2>"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: Checking MultiQC output expecting 39 lines: <$WC2>"
    ERRORS=$((ERRORS+1))
fi

if [[ $WC == 1 ]]; then
    echo -e "$OK: Experimental JSON output on 1 line: <$WC>"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: Experimental JSON output on 1 line: <$WC>"
    ERRORS=$((ERRORS+1))
fi
# Multi file 

# Default sort
"$BINDIR"/seqfu stats --basename  "$iAmpli" "$iSort" "$iMini" > "$TMP"
# Sort by N50 descending
"$BINDIR"/seqfu stats --basename  --sort n50 --reverse  "$iAmpli" "$iSort" "$iMini" > "$TMP2"

FILT=$(cat "$TMP" | head -n 2 | tail -n 1 | cut -f 1)
MSG="Checking default starting  by 'filt': <$FILT>"
if [[ "$FILT" == "filt" ]];  then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

FILT=$(cat "$TMP2" | head -n 2 |tail -n 1 | cut -f 1)
MSG="Checking default N50 starting by 'sort': <$FILT>"
if [[ "$FILT" == "sort" ]];  then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

#/////


"$BINDIR"/seqfu stats -a "$FILES"/prot.faa "$FILES"/prot2.faa "$FILES"/test.fa "$FILES"/test.fasta "$FILES"/test.fastq "$FILES"/test2.fastq "$FILES"/test_4.fa.gz | grep -v "Total bp" > "$TMP"

MSG="Check absolute paths"
if [[ $(grep ^/ "$TMP" | cut -c 1 | sort | head -n 1 ) == "/" ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: "
    ERRORS=$((ERRORS+1))
fi

MSG="Check sort orded when not specified"
A=$(basename $(head -n 1 "$TMP" | cut -f 1 ) )
if [[ "$A" == "prot.faa" ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG: $A"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats -a  --sort tot "$FILES"/prot.faa "$FILES"/prot2.faa "$FILES"/test.fa "$FILES"/test.fasta "$FILES"/test.fastq "$FILES"/test2.fastq "$FILES"/test_4.fa.gz | grep -v "Total bp" > "$TMP"
MSG="Check sort: tot seq sorted at 3300"
if [[ $(head -n 1 "$TMP" | cut -f 3 ) == 3300 ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG:$(head -n 1 "$TMP" | cut -f 3 ) "
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats -a  --sort tot --reverse "$FILES"/prot.faa "$FILES"/prot2.faa "$FILES"/test.fa "$FILES"/test.fasta "$FILES"/test.fastq "$FILES"/test2.fastq "$FILES"/test_4.fa.gz | grep -v "Total bp" > "$TMP"
MSG="Check reverse sort: tot seq sorted at 3300"
if [[ $(tail -n 1 "$TMP" | cut -f 3 ) == 3300 ]]; then
   echo -e "$OK: $MSG"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG:$(head -n 1 "$TMP" | cut -f 3 ) "
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats --gc "$FILES"/gc/1.fa | grep -v "Total bp" > "$TMP"
MSG="%GC check at 1.00"
OUT=$(cut -f 11 "$TMP" )
if [[ "$OUT" == 1.00 ]]; then
   echo -e "$OK: $MSG: <$OUT>"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG expected 1.00 got $OUT"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats --gc "$FILES"/gc/2.fa | grep -v "Total bp" > "$TMP"
MSG="%GC check at 0.00"
OUT=$(cut -f 11 "$TMP" )
if [[ "$OUT" == 0.00 ]]; then
   echo -e "$OK: $MSG: <$OUT>"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG expected 0.00 got $OUT"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu stats --gc "$FILES"/gc/3.fa | grep -v "Total bp" > "$TMP"
MSG="%GC check at 0.50"
OUT=$(cut -f 11 "$TMP" )
if [[ "$OUT" == 0.50 ]]; then
   echo -e "$OK: $MSG: <$OUT>"
   PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG expected 0.50 got $OUT"
    ERRORS=$((ERRORS+1))
fi
