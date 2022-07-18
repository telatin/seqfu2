#!/bin/bash

export SEQFU_QUIET=1
TMP=$(mktemp)

$("$BINDIR"/seqfu tail "$iNum" > "$TMP")
OBS=$(count "$TMP")
EXP=10
MSG="Last seqs (default) $TMP: exp=$EXP got=$OBS"
if [[ $EXP == $OBS ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi 

EXP=50
$("$BINDIR"/seqfu tail -n $EXP "$iNum" > "$TMP")
OBS=$(count "$TMP")
MSG="Last '-n $EXP' seqs $TMP: exp=$EXP got=$OBS"
if [[ $EXP == $OBS ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi 
rm "$TMP"
 
