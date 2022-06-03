#!/bin/bash
NATIVE=$(grep -v ">" "$FILES"/homopolymer.fa| wc -c)
COMPRESSED=$("$BINDIR"/fu-homocomp "$FILES"/homopolymer.fa | grep -v ">" | wc -c)

if [[ $NATIVE -gt $COMPRESSED ]]; then
    echo -e "$OK: compression from $NATIVE to $COMPRESSED"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: compression from $NATIVE to $COMPRESSED"
    FAIL=$((FAIL+1))
    ERRORS=$((ERRORS+1))
fi

 
