#!/bin/bash

check_ok() {
    local msg="$1"
    echo -e "$OK: $msg"
    PASS=$((PASS + 1))
}

check_fail() {
    local msg="$1"
    echo -e "$FAIL: $msg"
    ERRORS=$((ERRORS + 1))
}

TMP_MERGE_DIR=$(mktemp -d)
R1="$TMP_MERGE_DIR/R1.fq"
R2="$TMP_MERGE_DIR/R2.fq"
R2_LOW="$TMP_MERGE_DIR/R2_low.fq"
R1_LOW="$TMP_MERGE_DIR/R1_low.fq"
R2_MISMATCH_HIGH="$TMP_MERGE_DIR/R2_mismatch_high.fq"
R1_EXTRA="$TMP_MERGE_DIR/R1_extra.fq"
R1_LEADING_MISMATCH="$TMP_MERGE_DIR/R1_leading_mismatch.fq"
R2_LEADING_MISMATCH="$TMP_MERGE_DIR/R2_leading_mismatch.fq"

cat > "$R1" <<'EOF'
@r1/1
ACTGACGT
+
IIIIIIII
EOF

cat > "$R2" <<'EOF'
@r1/2
TTACGTCA
+
IIIIIIII
EOF

cat > "$R2_LOW" <<'EOF'
@r1/2
TTACGTCA
+
########
EOF

cat > "$R1_LOW" <<'EOF'
@r1/1
ACTGACGT
+
########
EOF

cat > "$R2_MISMATCH_HIGH" <<'EOF'
@r1/2
TTACGACA
+
IIIIIIII
EOF

cat > "$R1_EXTRA" <<'EOF'
@r1/1
ACTGACGT
+
IIIIIIII
@r2/1
ACTGACGT
+
IIIIIIII
EOF

cat > "$R1_LEADING_MISMATCH" <<'EOF'
@lead/1
TAAAAAAA
+
IIIIIIII
EOF

cat > "$R2_LEADING_MISMATCH" <<'EOF'
@lead/2
TTTTTTTG
+
IIIIIIII
EOF

OUT_T1="$TMP_MERGE_DIR/t1.fq"
OUT_T2="$TMP_MERGE_DIR/t2.fq"
OUT_EXHAUSTIVE="$TMP_MERGE_DIR/exhaustive.fq"
OUT_MINLEN="$TMP_MERGE_DIR/minlen.fq"
ERR_MINLEN="$TMP_MERGE_DIR/minlen.err"
OUT_MAXLEN="$TMP_MERGE_DIR/maxlen.fq"
ERR_MAXLEN="$TMP_MERGE_DIR/maxlen.err"
"$BINDIR"/seqfu merge -1 "$R1" -2 "$R2" --min-overlap 4 --min-length 1 \
  --threads 1 > "$OUT_T1"
"$BINDIR"/seqfu merge -1 "$R1" -2 "$R2" --min-overlap 4 --min-length 1 \
  --threads 2 --batch-size 1 > "$OUT_T2"
"$BINDIR"/seqfu merge -1 "$R1" -2 "$R2" --min-overlap 4 --min-length 1 \
  --search exhaustive > "$OUT_EXHAUSTIVE"
"$BINDIR"/seqfu merge -1 "$R1" -2 "$R2" --min-overlap 4 --min-len 11 \
  --verbose > "$OUT_MINLEN" 2>"$ERR_MINLEN"
"$BINDIR"/seqfu merge -1 "$R1" -2 "$R2" --min-overlap 4 --min-len 1 \
  --max-len 9 --verbose > "$OUT_MAXLEN" 2>"$ERR_MAXLEN"

if diff -q "$OUT_T1" "$OUT_T2" >/dev/null; then
    check_ok "seqfu merge --threads 2 matches --threads 1 output"
else
    check_fail "seqfu merge threaded output differs"
fi

if diff -q "$OUT_T1" "$OUT_EXHAUSTIVE" >/dev/null; then
    check_ok "seqfu merge --search exhaustive matches seeded output"
else
    check_fail "seqfu merge exhaustive output differs"
fi

if [[ ! -s "$OUT_MINLEN" ]] && grep -q "Discarded by read length: 1" "$ERR_MINLEN"; then
    check_ok "seqfu merge --min-len discards short merged reads"
else
    check_fail "seqfu merge min length filter [out=$(cat "$OUT_MINLEN") err=$(cat "$ERR_MINLEN")]"
fi

if [[ ! -s "$OUT_MAXLEN" ]] && grep -q "Discarded by read length: 1" "$ERR_MAXLEN"; then
    check_ok "seqfu merge --max-len discards long merged reads"
else
    check_fail "seqfu merge max length filter [out=$(cat "$OUT_MAXLEN") err=$(cat "$ERR_MAXLEN")]"
fi

MERGED_SEQ=$(sed -n '2p' "$OUT_T1")
MERGED_QUAL=$(sed -n '4p' "$OUT_T1")
if [[ "$MERGED_SEQ" == "ACTGACGTAA" ]] && [[ "$MERGED_QUAL" == "IIvvvvvvII" ]]; then
    check_ok "seqfu merge recalculates posterior quality for matching overlap"
else
    check_fail "seqfu merge recalculate output [seq=$MERGED_SEQ qual=$MERGED_QUAL]"
fi

FIRST_QUAL=$("$BINDIR"/seqfu merge -1 "$R1" -2 "$R2" --min-overlap 4 \
  --min-length 1 --qual-method first | sed -n '4p')
if [[ "$FIRST_QUAL" == "IIIIIIIIII" ]]; then
    check_ok "seqfu merge --qual-method first keeps R1 overlap quality"
else
    check_fail "seqfu merge first quality [qual=$FIRST_QUAL]"
fi

MISMATCH_SEQ=$("$BINDIR"/seqfu merge -1 "$R1_LOW" -2 "$R2_MISMATCH_HIGH" \
  --min-overlap 4 --min-id 0.80 --min-length 1 --qual-method first | sed -n '2p')
if [[ "$MISMATCH_SEQ" == "ACTGTCGTAA" ]]; then
    check_ok "seqfu merge chooses higher-quality mismatch base"
else
    check_fail "seqfu merge mismatch consensus [seq=$MISMATCH_SEQ]"
fi

LOWEST_QUAL=$("$BINDIR"/seqfu merge -1 "$R1" -2 "$R2_LOW" --min-overlap 4 \
  --min-length 1 --qual-method lowest | sed -n '4p')
if [[ "$LOWEST_QUAL" == "II########" ]]; then
    check_ok "seqfu merge --qual-method lowest uses lower overlap quality"
else
    check_fail "seqfu merge lowest quality [qual=$LOWEST_QUAL]"
fi

LEADING_SEQ=$("$BINDIR"/seqfu merge -1 "$R1_LEADING_MISMATCH" \
  -2 "$R2_LEADING_MISMATCH" --min-overlap 8 --min-id 0.80 \
  --min-length 1 --qual-method first | sed -n '2p')
if [[ "$LEADING_SEQ" == "TAAAAAAA" ]]; then
    check_ok "seqfu merge keeps valid overlaps with an early mismatch"
else
    check_fail "seqfu merge early mismatch overlap [seq=$LEADING_SEQ]"
fi

HIGH_ERR="$TMP_MERGE_DIR/highest.err"
"$BINDIR"/seqfu merge -1 "$R1" -2 "$R2" --qual-method highest \
  >/dev/null 2>"$HIGH_ERR"
HIGH_CODE=$?
if [[ $HIGH_CODE -ne 0 ]] && grep -q "Invalid quality method" "$HIGH_ERR"; then
    check_ok "seqfu merge rejects removed highest quality mode"
else
    check_fail "seqfu merge highest handling [exit=$HIGH_CODE err=$(cat "$HIGH_ERR")]"
fi

EOF_ERR="$TMP_MERGE_DIR/eof.err"
"$BINDIR"/seqfu merge -1 "$R1_EXTRA" -2 "$R2" --min-overlap 4 --min-length 1 \
  >/dev/null 2>"$EOF_ERR"
EOF_CODE=$?
if [[ $EOF_CODE -ne 0 ]] && grep -q "R2 file ended before R1" "$EOF_ERR"; then
    check_ok "seqfu merge detects R2 early EOF"
else
    check_fail "seqfu merge early EOF handling [exit=$EOF_CODE err=$(cat "$EOF_ERR")]"
fi

rm -rf "$TMP_MERGE_DIR"
