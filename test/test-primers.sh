TMP_PRIMER_DIR=$(mktemp -d)

SYN_R1="$TMP_PRIMER_DIR/sample_1.fq"
SYN_R2="$TMP_PRIMER_DIR/sample_2.fq"
SYN_OUT1="$TMP_PRIMER_DIR/out_t1.fq"
SYN_OUT2="$TMP_PRIMER_DIR/out_t2.fq"
SYN_ERR="$TMP_PRIMER_DIR/err.log"

cat > "$SYN_R1" <<'EOF'
@r1/1
ACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGT
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
EOF

cat > "$SYN_R2" <<'EOF'
@r1/2
TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCC
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
EOF

# Auto mate inference from _1. to _2.
"$BINDIR"/fu-primers -1 "$SYN_R1" --threads 1 --pool-size 1 > "$SYN_OUT1" 2>"$SYN_ERR"
RET=$?
NREADS=$(grep -c '^@' "$SYN_OUT1" || true)
MSG="fu-primers infers _1/_2 mate names and keeps paired output"
if [[ $RET -eq 0 && $NREADS -eq 2 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (exit=$RET reads=$NREADS err=$(cat "$SYN_ERR"))"
    ERRORS=$((ERRORS+1))
fi

# Parallel and single-thread outputs should match.
"$BINDIR"/fu-primers -1 "$SYN_R1" --threads 1 --pool-size 1 > "$SYN_OUT1" 2>"$SYN_ERR"
"$BINDIR"/fu-primers -1 "$SYN_R1" --threads 2 --pool-size 1 > "$SYN_OUT2" 2>>"$SYN_ERR"
MSG="fu-primers --threads 2 matches --threads 1 output"
if diff -q "$SYN_OUT1" "$SYN_OUT2" >/dev/null; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG"
    ERRORS=$((ERRORS+1))
fi

# Explicit missing R2 is an error (do not silently fall back to SE).
"$BINDIR"/fu-primers -1 "$SYN_R1" -2 "$TMP_PRIMER_DIR/missing_R2.fq" > /dev/null 2>"$SYN_ERR"
RET=$?
MSG="fu-primers fails when explicit -2 file is missing"
if [[ $RET -ne 0 ]] && grep -q "ERROR: File R2 not found" "$SYN_ERR"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$SYN_ERR"))"
    ERRORS=$((ERRORS+1))
fi

# Pool size validation.
"$BINDIR"/fu-primers -1 "$SYN_R1" --pool-size 0 > /dev/null 2>"$SYN_ERR"
RET=$?
MSG="fu-primers rejects invalid --pool-size"
if [[ $RET -ne 0 ]] && grep -q -- "--pool-size must be >= 1" "$SYN_ERR"; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$SYN_ERR"))"
    ERRORS=$((ERRORS+1))
fi

# Single-end mode remains functional when no mate can be inferred.
SE_OUT="$TMP_PRIMER_DIR/single_out.fq"
"$BINDIR"/fu-primers -1 "$FILES"/primers/small.fq --threads 2 --pool-size 2 > "$SE_OUT" 2>"$SYN_ERR"
RET=$?
NREADS=$(grep -c '^@' "$SE_OUT" || true)
MSG="fu-primers processes single-end input when mate is not inferred"
if [[ $RET -eq 0 ]] && [[ $NREADS -gt 0 ]]; then
    echo -e "$OK: $MSG"
    PASS=$((PASS+1))
else
    echo -e "$FAIL: $MSG (exit=$RET reads=$NREADS err=$(cat "$SYN_ERR"))"
    ERRORS=$((ERRORS+1))
fi

rm -rf "$TMP_PRIMER_DIR"
