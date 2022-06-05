#!/bin/bash
ORFFOR=$("$BINDIR"/fu-orf "$FILES"/orf.fa.gz --min-size 500 | grep ">" | wc -l)
ORFREV=$("$BINDIR"/fu-orf "$FILES"/orf.fa.gz --min-size 500  --scan-reverse | grep ">" | wc -l)

if [[ $ORFFOR -eq 1 ]]; then
    echo -e "$OK: ONE large ORF found in forward mode"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: Expected ONE large ORF found in forward mode [found: $ORFFOR]"
    ERRORS=$((ERRORS+1))
fi
if [[ $ORFREV -eq  2 ]]; then
    echo -e "$OK: Two large ORFs found in for/rev mode"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: Expected Two large ORFs found in forward/reverse mode [found: $ORFREV]"
    ERRORS=$((ERRORS+1))
fi

CODE1=$("$BINDIR"/fu-orf "$FILES"/codons.fa --min-size 3 --min-read-len 6 -c 1 | grep -v ">")
CODE5=$("$BINDIR"/fu-orf "$FILES"/codons.fa --min-size 3 --min-read-len 6 -c 5 | grep -v ">")
if [[ $CODE1 != $CODE5 ]]; then
    PASS=$((PASS+1))
    echo -e "$OK: Genetic code implemented"
else
    echo -e "$FAIL: Genetic code match $CODE1 $CODE5"
    ERRORS=$((ERRORS+1))
fi

if [[ $CODE1 =~ "RRI" ]]; then
    echo -e "$OK: Standard genetic code [1]"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: Standard genetic code error $CODE1 != RRI"
    ERRORS=$((ERRORS+1))
fi
  
if [[ $CODE5 =~ "SSM" ]]; then
    echo -e "$OK: Genetic code #5"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: Genetic code 5 error $CODE5 != SSM"
    ERRORS=$((ERRORS+1))
fi
