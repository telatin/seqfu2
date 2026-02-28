#!/bin/bash
ORFFOR=$("$BINDIR"/fu-orf "$FILES"/orf.fa.gz --min-size 500 | grep ">" | wc -l)
ORFREV=$("$BINDIR"/fu-orf "$FILES"/orf.fa.gz --min-size 500  --scan-reverse | grep ">" | wc -l)
SEQFU_ORFFOR=$("$BINDIR"/seqfu orf "$FILES"/orf.fa.gz --min-size 500 | grep ">" | wc -l)
SEQFU_ORFREV=$("$BINDIR"/seqfu orf "$FILES"/orf.fa.gz --min-size 500 --scan-reverse | grep ">" | wc -l)
SEQFU_ORFFOR_IFB1=$("$BINDIR"/seqfu orf "$FILES"/orf.fa.gz --min-size 500 --in-flight-batches 1 | grep ">" | wc -l)

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

if [[ $SEQFU_ORFFOR -eq 1 ]]; then
    echo -e "$OK: seqfu orf forward mode"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: seqfu orf forward mode [found: $SEQFU_ORFFOR]"
    ERRORS=$((ERRORS+1))
fi

if [[ $SEQFU_ORFREV -eq 2 ]]; then
    echo -e "$OK: seqfu orf reverse mode"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: seqfu orf reverse mode [found: $SEQFU_ORFREV]"
    ERRORS=$((ERRORS+1))
fi

if [[ $SEQFU_ORFFOR_IFB1 -eq 1 ]]; then
    echo -e "$OK: seqfu orf works with --in-flight-batches 1"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: seqfu orf with --in-flight-batches 1 [found: $SEQFU_ORFFOR_IFB1]"
    ERRORS=$((ERRORS+1))
fi

POOL_ERR=$(mktemp)
"$BINDIR"/seqfu orf "$FILES"/orf.fa.gz --pool-size 0 >/dev/null 2>"$POOL_ERR"
POOL_EXIT=$?
POOL_MSG=$(cat "$POOL_ERR")
rm -f "$POOL_ERR"
if [[ $POOL_EXIT -ne 0 ]] && [[ $POOL_MSG =~ "--pool-size must be greater than 0" ]]; then
    echo -e "$OK: seqfu orf rejects invalid --pool-size"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: seqfu orf invalid --pool-size handling [exit: $POOL_EXIT] [msg: $POOL_MSG]"
    ERRORS=$((ERRORS+1))
fi

IFB_ERR=$(mktemp)
"$BINDIR"/seqfu orf "$FILES"/orf.fa.gz --in-flight-batches=-1 >/dev/null 2>"$IFB_ERR"
IFB_EXIT=$?
IFB_MSG=$(cat "$IFB_ERR")
rm -f "$IFB_ERR"
if [[ $IFB_EXIT -ne 0 ]] && [[ $IFB_MSG =~ "--in-flight-batches must be >= 0" ]]; then
    echo -e "$OK: seqfu orf rejects invalid --in-flight-batches"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: seqfu orf invalid --in-flight-batches handling [exit: $IFB_EXIT] [msg: $IFB_MSG]"
    ERRORS=$((ERRORS+1))
fi

TMP_R1=$(mktemp)
TMP_R2=$(mktemp)
cat > "$TMP_R1" <<'EOF'
@r1
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIII
EOF
cat > "$TMP_R2" <<'EOF'
@r1
TTTTTTTTTTTTTTTTTTTTTTTTTTTTTT
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIII
EOF
JOINED_MAX=$("$BINDIR"/seqfu orf -1 "$TMP_R1" -2 "$TMP_R2" -j --min-size 15 --min-overlap 12 --max-overlap 200 | grep -c "^>")
CAPPED_MAX=$("$BINDIR"/seqfu orf -1 "$TMP_R1" -2 "$TMP_R2" -j --min-size 15 --min-overlap 12 --max-overlap 5 | grep -c "^>")
rm -f "$TMP_R1" "$TMP_R2"
if [[ $JOINED_MAX -gt 0 ]] && [[ $CAPPED_MAX -eq 0 ]]; then
    echo -e "$OK: seqfu orf honors --max-overlap hard cap"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: seqfu orf --max-overlap hard cap [max200: $JOINED_MAX] [max5: $CAPPED_MAX]"
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
