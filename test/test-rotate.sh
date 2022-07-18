#!/bin/bash
ROTATE=$("$BINDIR"/seqfu rotate -i 14 "$FILES"/homopolymer.fa| grep -v '^>')
FORROT=$("$BINDIR"/seqfu rotate -m AAAAAAAAAAC "$FILES"/homopolymer.fa| grep -v '^>')
REVROT=$("$BINDIR"/seqfu rotate -r -m GTTTTTTT "$FILES"/homopolymer.fa| grep -v '^>')

if [[ $ROTATE = "AAAAAAAAAACTGCTACTAACACGTACTACTG" ]]; then
    echo -e "$OK: sequence rotated"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: rotated seq $ROTATE  should start with polyA"
    ERRORS=$((ERRORS+1))
fi

if [[ $FORROT = "AAAAAAAAAACTGCTACTAACACGTACTACTG" ]]; then
    echo -e "$OK: sequence rotated with pattern"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: rotated seq $ROTATE  (pattern) should start with polyA"
    ERRORS=$((ERRORS+1))
fi

if [[ $REVROT = "GTTTTTTTTTTCAGTAGTACGTGTTAGTAGCA" ]]; then
    echo -e "$OK: sequence rotated with reverse pattern"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: rotated seq $ROTATE  (reverse pattern) should start with GTTT."
    ERRORS=$((ERRORS+1))
fi
