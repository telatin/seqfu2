ORFFOR=$("$BINDIR"/fu-orf "$FILES"/orf.fa.gz --min-size 500 | grep ">" | wc -l)
ORFREV=$("$BINDIR"/fu-orf "$FILES"/orf.fa.gz --min-size 500  --scan-reverse | grep ">" | wc -l)

if [[ $ORFFOR -eq 1 ]]; then
    echo "OK: ONE large ORF found in forward mode"
    PASS=$((PASS+1))
else
    echo "FAIL: ONE large ORF found in forward mode [found: $ORFFOR]"
    FAIL=$((FAIL+1))
    ERRORS=$((ERRORS+1))
fi
if [[ $ORFREV -eq  2 ]]; then
    echo "OK: Two large ORF found in forward mode"
    PASS=$((PASS+1))
else
    echo "FAIL: Two large ORFs found in forward/reverse mode [found: $ORFREV]"
    FAIL=$((FAIL+1))
    ERRORS=$((ERRORS+1))
fi

  