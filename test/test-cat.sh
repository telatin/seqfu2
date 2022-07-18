#!/bin/bash

# Single file
TMP=$(mktemp)
"$BINDIR"/seqfu stats --basename "$iAmpli" > "$TMP"


MSG="Precheck input file has 1000 sequences"
if [[ $(count "$FILES"/numbers.fa) == 1000 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu cat --skip 2 "$FILES"/numbers.fa > "$TMP"
OBS=$(count "$TMP")
EXP=500
MSG="Checking cat --skip 2, expecting 500 sequences, got $OBS" 
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu cat --skip-first 500 --skip 2 "$FILES"/numbers.fa > "$TMP"
OBS=$(count "$TMP")
EXP=250
MSG="Checking cat --skip 2 and --skip-first 500, expecting $EXP sequences, got $OBS" 
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu cat --skip-first 500 --skip 2 "$FILES"/numbers.fa > "$TMP"
OBS=$(count "$TMP")
EXP=250
MSG="Checking cat --skip 2 and --skip-first 500, expecting $EXP sequences, got $OBS" 
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu cat --skip-first 500 --max-bp 200 --skip 2 "$FILES"/numbers.fa > "$TMP"
OBS=$(bp "$TMP")
EXP=200
MSG="Checking --max-bp 200, got $OBS <= $EXP" 
if [[ ! $OBS -gt $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu cat --jump-to 500 "$FILES"/numbers.fa > "$TMP"
OBS=$(count "$TMP")
EXP=500
MSG="Checking --jump-to NAME (exclusive), got $OBS expecting $EXP" 
if [[ ! $OBS -gt $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi


