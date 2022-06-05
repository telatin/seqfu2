#!/bin/bash

# Single file
TMP=$(mktemp)
STATS=$("$BINDIR"/seqfu stats --basename $iAmpli > $TMP)

WC=$(cat "$TMP" | wc -l | grep -o '\d\+')
SEQS=$(cat "$TMP" | tail -n 1 | cut -f 2)
TOT=$(cat "$TMP" | tail -n 1 | cut -f 3)
N50=$(cat "$TMP" | tail -n 1 | cut -f 5)

MSG="[stats] Checking normal output expecting 2 lines: <$WC>"
if [[ $WC == 2 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi


MSG="[stats] Checking normal output expecting total seqs 78730: <$SEQS>"
if [[ $SEQS == 78730 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

MSG="[stats] Checking normal output expecting total bases 24299931: <$TOT>"
if [[ $TOT == 24299931 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

MSG="[stats] Checking normal N50 to be 316: <$N50>"
if [[ $N50 == 316 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

CSV=$("$BINDIR"/seqfu stats --basename --csv $iAmpli > $TMP)
N50=$(cat "$TMP" | tail -n 1 | cut -f 5 -d ,)
MSG="[stats] Checking CSV output N50 is 316, got: <$N50>"
if [[ $N50 == 316 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Nice output
STATS=$("$BINDIR"/seqfu stats --basename --nice $iAmpli > $TMP)
WC=$(cat "$TMP" | grep . | wc -l | grep -o '\d\+')
if [[ $WC == 5 ]]; then
    echo -e "$OK: [stats] Checking nice output expecting 5 lines: <$WC>"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: [stats] Checking nice output expecting 5 lines: <$WC>"
    ERRORS=$((ERRORS+1))
fi

# Json 
TMP2=$(mktemp)
STATS=$("$BINDIR"/seqfu stats --basename --json --multiqc $TMP2 $iAmpli > $TMP)
WC=$(cat "$TMP" | grep . | wc -l | grep -o '\d\+')
WC2=$(cat "$TMP2" | grep . | wc -l | grep -o '\d\+')
if [[ $WC2 == 36 ]]; then
    echo -e "$OK: [stats] Checking MultiQC output expecting 36 lines: <$WC2>"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: [stats] Checking MultiQC output expecting 36 lines: <$WC2>"
    ERRORS=$((ERRORS+1))
fi
# Multi file 

# Default sort
"$BINDIR"/seqfu stats --basename  $iAmpli $iSort $iMini > $TMP
# Sort by N50 descending
 "$BINDIR"/seqfu stats --basename  --sort N50 --reverse $iAmpli $iSort $iMini > $TMP2

FILT=$(cat $TMP | head -n 2 | tail -n 1 | cut -f 1)
MSG="[stats] Checking default starting  by 'filt': <$FILT>"
if [[ $FILT == "filt" ]];  then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

FILT=$(cat $TMP2 | head -n 2 |tail -n 1 | cut -f 1)
MSG="[stats] Checking default N50 starting by 'sort': <$FILT>"
if [[ $FILT == "sort" ]];  then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi
