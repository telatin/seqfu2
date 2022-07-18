#!/bin/bash

export SEQFU_QUIET=1

FOR="CAGATA"
RC="TATCTG"

OBS=$("$BINDIR"/seqfu rc "$FOR")
MSG="Reverse complement of $FOR: exp=$RC got=$OBS"
if [[ $RC == $OBS ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi 

OBS=$("$BINDIR"/seqfu rc "$RC")
MSG="Reverse complement of $RC: exp=$FOR got=$OBS"
if [[ $OBS == $FOR ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi 

#>polya
#cagataaaaaaa
#TTTTTTTATCTG
OBS=$("$BINDIR"/seqfu rc "$FILES"/rc.fa | grep -v ">")
EXP="TTTTTTTATCTG"
MSG="Reverse complement of rc.fa: exp=$EXP got=$OBS"
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi 

## IUPAC

IUPAC="ACGTWSKY"
EXP="RMSWACGT"
OBS=$("$BINDIR"/seqfu rc $IUPAC)
MSG="Reverse complement iupac $IUPAC: exp=$EXP got=$OBS"
if [[ $OBS == $EXP ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi 