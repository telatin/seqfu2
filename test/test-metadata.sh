#!/bin/bash

export SEQFU_QUIET=1

READS_DIR="$FILES"/reads/

SEQFU_TEMP_DIR=$(mktemp -d)
META_DEFAULT=$($BINDIR/seqfu metadata $READS_DIR > "$SEQFU_TEMP_DIR"/metadata.tsv)
META_IRIDA=$($BINDIR/seqfu metadata -f irida -P 100 $READS_DIR > "$SEQFU_TEMP_DIR"/irida.csv)
## IUPAC

EXP=3
OBS=$("$BINDIR"/fu-tabcheck "$SEQFU_TEMP_DIR"/metadata.tsv | cut -f 3)
MSG="Default table columns: exp=$EXP got=$OBS"
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi 

EXP=6
OBS=$("$BINDIR"/fu-tabcheck "$SEQFU_TEMP_DIR"/metadata.tsv | cut -f 4)
MSG="Default table rows: exp=$EXP got=$OBS"
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi 

EXP=7
OBS=$(getnumber $(grep . "$SEQFU_TEMP_DIR"/irida.csv | wc -l))
MSG="Irida lines: exp=$EXP got=$OBS"
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi 