#!/bin/bash

export SEQFU_QUIET=1
TEMPFILENAME=$(mktemp)
INPUT="$FILES"/16S_coli.fa
### SINGLE END
"$BINDIR"/fu-shred "$INPUT" -l 100 -s 150 > "$TEMPFILENAME"
COUNT=$(cat "$TEMPFILENAME" | "$BINDIR"/seqfu count - | cut -f 2)
LEN=$(cat "$TEMPFILENAME" | "$BINDIR"/seqfu stats - | cut -f 3 | tail -n 1)
EXIT=$?


MSG="SE: 10 sequences"
EXP=10
if [[ $COUNT == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $COUNT from $INPUT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $COUNT from $INPUT)"
    ERRORS=$((ERRORS+1))
fi 

MSG="SE: Total length 1000bp "
EXP=1000
if [[ $LEN == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $LEN from $INPUT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $LEN from $INPUT)"
    ERRORS=$((ERRORS+1))
fi 

TEMPORARY_DIR=$(mktemp -d)
FWD="$TEMPORARY_DIR"/illuminate_R1.fq
REV="$TEMPORARY_DIR"/illuminate_R2.fq
"$BINDIR"/fu-shred "$INPUT" -f 100 -l 50 -s 150 -o "$TEMPORARY_DIR"/illuminate

MSG="Output found $FWD,$REV "
if [[ -e "$FWD" ]] && [[ -e "$REV" ]]; then
    echo -e "$OK: $MSG "
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi 

COUNT=$(cat "$FWD" | "$BINDIR"/seqfu count - | cut -f 2)
LEN=$(cat "$FWD" | "$BINDIR"/seqfu stats - | cut -f 3 | tail -n 1)
MSG="PE: 10 sequences"
EXP=10
if [[ $COUNT == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $COUNT from $INPUT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $COUNT from $INPUT)"
    ERRORS=$((ERRORS+1))
fi 

MSG="PE: Total length 1000bp "
EXP=500
if [[ $LEN == $EXP ]]; then
    echo -e "$OK: $MSG (expected $EXP, got $LEN from $INPUT)"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (expected $EXP, got $LEN from $INPUT)"
    ERRORS=$((ERRORS+1))
fi 