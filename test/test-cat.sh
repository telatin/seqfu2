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

CAT_NS=$(mktemp)
cat > "$CAT_NS" <<'EOF'
>no_ns
ACGT
>one_N
ACNT
>two_Ns
ANNT
>lower_n
ACnT
EOF

"$BINDIR"/seqfu cat --max-ns 0 "$CAT_NS" > "$TMP"
OBS=$(grep -c '^>' "$TMP")
EXP=1
MSG="Checking --max-ns 0 keeps only records with no Ns, got $OBS"
if [[ $OBS == $EXP ]] && grep -q '^>no_ns' "$TMP"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu cat --max-ns 1 "$CAT_NS" > "$TMP"
OBS=$(grep -c '^>' "$TMP")
EXP=3
MSG="Checking --max-ns 1 discards only records with more than one N, got $OBS"
if [[ $OBS == $EXP ]] && grep -q '^>one_N' "$TMP" && grep -q '^>lower_n' "$TMP"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

CAT_PART=$(mktemp "${TMPDIR:-/tmp}/seqfu-cat-part.XXXXXX")
cat > "$CAT_PART" <<'EOF'
>seq1
ACGT
EOF

"$BINDIR"/seqfu cat --basename --part 99 "$CAT_PART" > /dev/null 2> "$TMP.err"
RET=$?
MSG="Checking --basename --part out-of-range exits cleanly"
if [[ $RET -ne 0 ]] && grep -q -- "--part 99 is out of range" "$TMP.err"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

CAT_TRIM=$(mktemp "${TMPDIR:-/tmp}/seqfu-cat-trim.XXXXXX")
cat > "$CAT_TRIM" <<'EOF'
@trim
AACCGGTT
+
HHHHHHHH
EOF

cat > "$TMP.expected" <<'EOF'
@trim
CCG
+
HHH
EOF

"$BINDIR"/seqfu cat --trim-front 2 --trim-tail 3 "$CAT_TRIM" > "$TMP"
MSG="Checking cat --trim-front/--trim-tail trims sequence and quality"
if cmp -s "$TMP" "$TMP.expected"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu cat "$CAT_TRIM" > "$TMP.plain"
"$BINDIR"/seqfu cat -o "$TMP.out.fq" "$CAT_TRIM"
MSG="Checking cat -o FILE writes the same records as STDOUT"
if cmp -s "$TMP.out.fq" "$TMP.plain"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

"$BINDIR"/seqfu cat -o "$TMP.out.fq.gz" "$CAT_TRIM"
MSG="Checking cat -o FILE.gz writes valid gzip with the same records"
if gzip -t "$TMP.out.fq.gz" 2>/dev/null && gzip -dc "$TMP.out.fq.gz" | cmp -s - "$TMP.plain"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

cp "$CAT_TRIM" "$TMP.self.fq"
MSG="Checking cat -o refuses to overwrite an input file"
if ! "$BINDIR"/seqfu cat -o "$TMP.self.fq" "$TMP.self.fq" 2>/dev/null && cmp -s "$TMP.self.fq" "$CAT_TRIM"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi
rm -f "$TMP.plain" "$TMP.out.fq" "$TMP.out.fq.gz" "$TMP.self.fq"
