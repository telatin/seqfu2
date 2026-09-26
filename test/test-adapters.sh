#!/usr/bin/env bash

ADAPTERS_BIN="${SEQFU_BIN:-${BINDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/}/seqfu}"
ADAPTERS_TMP=$(mktemp -d)
PASS=${PASS:-0}
ERRORS=${ERRORS:-0}
OK=${OK:-'\033[0;32mOK\033[0m'}
FAIL=${FAIL:-'\033[0;31mFAIL\033[0m'}
trap 'rm -rf "$ADAPTERS_TMP"' EXIT

adapters_ok() {
  echo -e "$OK: adapters: $1"
  PASS=$((PASS+1))
}

adapters_fail() {
  echo -e "$FAIL: adapters: $1"
  ERRORS=$((ERRORS+1))
}

adapters_compare() {
  local label=$1 expected=$2 actual=$3
  if cmp -s "$expected" "$actual"; then
    adapters_ok "$label"
  else
    adapters_fail "$label"
    diff -u "$expected" "$actual" || true
  fi
}

if "$ADAPTERS_BIN" adapters --help >/dev/null 2>&1 &&
   "$ADAPTERS_BIN" primers --help >/dev/null 2>&1; then
  adapters_ok "both command help pages exit successfully"
else
  adapters_fail "command help failed"
fi

if "$ADAPTERS_BIN" adapters --help 2>&1 | grep -q -- "--skip-known-adapters"; then
  adapters_ok "adapters help exposes --skip-known-adapters"
else
  adapters_fail "adapters help omits --skip-known-adapters"
fi

cat > "$ADAPTERS_TMP/single.fq" <<'EOF'
@matched note
ACGTACGTGGAACCGACTGACT
+
!!!!!!!!ABCDEF########
@unmatched
TTTTTTTTCCCCCC
+
IIIIIIIIIIIIII
EOF

cat > "$ADAPTERS_TMP/single.expected.fq" <<'EOF'
@matched note
GGAACC
+
ABCDEF
EOF

if "$ADAPTERS_BIN" primers --fwd ACGTACGT --rev AGTCAGTC \
    -1 "$ADAPTERS_TMP/single.fq" -o "$ADAPTERS_TMP/single.out.fq" \
    --no-indels; then
  adapters_compare "single-end linked trimming preserves exact quality" \
    "$ADAPTERS_TMP/single.expected.fq" "$ADAPTERS_TMP/single.out.fq"
else
  adapters_fail "single-end primer command failed"
fi

cat > "$ADAPTERS_TMP/single.keep.expected.fq" <<'EOF'
@matched note
GGAACC
+
ABCDEF
@unmatched
TTTTTTTTCCCCCC
+
IIIIIIIIIIIIII
EOF

if "$ADAPTERS_BIN" primers --fwd ACGTACGT --rev AGTCAGTC \
    -1 "$ADAPTERS_TMP/single.fq" -o "$ADAPTERS_TMP/single.keep.fq" \
    --keep-untrimmed --no-indels; then
  adapters_compare "--keep-untrimmed retains unmatched reads unchanged" \
    "$ADAPTERS_TMP/single.keep.expected.fq" "$ADAPTERS_TMP/single.keep.fq"
else
  adapters_fail "--keep-untrimmed command failed"
fi

cat > "$ADAPTERS_TMP/R1.fq" <<'EOF'
@pair1/1 alpha
AACCGGTTAAAAAATACGGACT
+
!!!!!!!!ABCDEF########
@pair2/1 beta
AACCGGTTCCCCCC
+
!!!!!!!!UVWXYZ
EOF


cat > "$ADAPTERS_TMP/R2.fq" <<'EOF'
@pair1/2 alpha
AGTCCGTAGGGGGGAACCGGTT
+
!!!!!!!!GHIJKL########
@pair2/2 beta
TTTTTTTTGGGGGG
+
IIIIIIIIIIIIII
EOF

cat > "$ADAPTERS_TMP/R1.expected.fq" <<'EOF'
@pair1/1 alpha
AAAAAA
+
ABCDEF
EOF

cat > "$ADAPTERS_TMP/R2.expected.fq" <<'EOF'
@pair1/2 alpha
GGGGGG
+
GHIJKL
EOF

if "$ADAPTERS_BIN" primers --fwd AACCGGTT --rev AGTCCGTA \
    -1 "$ADAPTERS_TMP/R1.fq" -2 "$ADAPTERS_TMP/R2.fq" \
    -o "$ADAPTERS_TMP/split.R1.fq" -O "$ADAPTERS_TMP/split.R2.fq" \
    --no-indels -t 2 --batch-size 1; then
  adapters_compare "paired split R1 output and strict pair retention" \
    "$ADAPTERS_TMP/R1.expected.fq" "$ADAPTERS_TMP/split.R1.fq"
  adapters_compare "paired split R2 output and exact quality" \
    "$ADAPTERS_TMP/R2.expected.fq" "$ADAPTERS_TMP/split.R2.fq"
else
  adapters_fail "paired split primer command failed"
fi

cat "$ADAPTERS_TMP/R1.expected.fq" "$ADAPTERS_TMP/R2.expected.fq" > \
  "$ADAPTERS_TMP/interleaved.expected.fq"
if "$ADAPTERS_BIN" primers --fwd AACCGGTT --rev AGTCCGTA \
    -1 "$ADAPTERS_TMP/R1.fq" -2 "$ADAPTERS_TMP/R2.fq" \
    -o "$ADAPTERS_TMP/interleaved.fq" --no-indels; then
  adapters_compare "paired output falls back to interleaved without -O" \
    "$ADAPTERS_TMP/interleaved.expected.fq" "$ADAPTERS_TMP/interleaved.fq"
else
  adapters_fail "paired interleaved primer command failed"
fi

if "$ADAPTERS_BIN" adapters \
    -a 'AACCGGTT...TACGGACT' -A 'AGTCCGTA...AACCGGTT' \
    -1 "$ADAPTERS_TMP/R1.fq" -2 "$ADAPTERS_TMP/R2.fq" \
    -o "$ADAPTERS_TMP/general.R1.fq" -O "$ADAPTERS_TMP/general.R2.fq" \
    --discard-untrimmed --no-indels; then
  adapters_compare "general linked -a output matches the primer workflow" \
    "$ADAPTERS_TMP/R1.expected.fq" "$ADAPTERS_TMP/general.R1.fq"
  adapters_compare "general linked -A output matches the primer workflow" \
    "$ADAPTERS_TMP/R2.expected.fq" "$ADAPTERS_TMP/general.R2.fq"
else
  adapters_fail "general paired linked adapter command failed"
fi

cat > "$ADAPTERS_TMP/iupac.fq" <<'EOF'
@iupac
CCTACGGGAGGCAGCAGTTAA
+
IIIIIIIIIIIIIIIIIIIII
EOF

cat > "$ADAPTERS_TMP/iupac.expected.fq" <<'EOF'
@iupac
TTAA
+
IIII
EOF

if "$ADAPTERS_BIN" primers --fwd CCTACGGGNGGCWGCAG \
    --rev GGACTACHVGGGTATCTAATCC -1 "$ADAPTERS_TMP/iupac.fq" \
    -o "$ADAPTERS_TMP/iupac.out.fq" --no-indels; then
  adapters_compare "IUPAC-degenerate primer matches concrete sequence" \
    "$ADAPTERS_TMP/iupac.expected.fq" "$ADAPTERS_TMP/iupac.out.fq"
else
  adapters_fail "IUPAC primer command failed"
fi

cat > "$ADAPTERS_TMP/indel.fq" <<'EOF'
@indel
ACGTTACGTGATTACA
+
IIIIIIIIIIIIIIII
EOF

cat > "$ADAPTERS_TMP/indel.expected.fq" <<'EOF'
@indel
GATTACA
+
IIIIIII
EOF

"$ADAPTERS_BIN" primers --fwd ACGTACGT --rev AGTCAGTC \
  -1 "$ADAPTERS_TMP/indel.fq" -o "$ADAPTERS_TMP/indel.out.fq" \
  --error-rate 0.2
adapters_compare "semiglobal matching accepts a primer insertion" \
  "$ADAPTERS_TMP/indel.expected.fq" "$ADAPTERS_TMP/indel.out.fq"

"$ADAPTERS_BIN" primers --fwd ACGTACGT --rev AGTCAGTC \
  -1 "$ADAPTERS_TMP/indel.fq" -o "$ADAPTERS_TMP/no-indel.out.fq" \
  --error-rate 0.2 --no-indels
if [[ ! -s "$ADAPTERS_TMP/no-indel.out.fq" ]]; then
  adapters_ok "--no-indels rejects the inserted primer"
else
  adapters_fail "--no-indels retained an inserted primer"
fi

cat > "$ADAPTERS_TMP/adapters.expected.fq" <<'EOF'
@matched note
ACGTACGTGGAACC
+
!!!!!!!!ABCDEF
@unmatched
TTTTTTTTCCCCCC
+
IIIIIIIIIIIIII
EOF

if "$ADAPTERS_BIN" adapters -a GACTGACT -1 "$ADAPTERS_TMP/single.fq" \
    -o "$ADAPTERS_TMP/adapters.out.fq" --no-indels; then
  adapters_compare "general adapters trims 3' matches and keeps untrimmed reads" \
    "$ADAPTERS_TMP/adapters.expected.fq" "$ADAPTERS_TMP/adapters.out.fq"
else
  adapters_fail "general adapters command failed"
fi

KNOWN_R1=AGATCGGAAGAGCACACGTCTGAACTCCAGTCA
KNOWN_R2=AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT
printf -v KNOWN_R1_Q '%*s' "${#KNOWN_R1}" ''
printf -v KNOWN_R2_Q '%*s' "${#KNOWN_R2}" ''
KNOWN_R1_Q=${KNOWN_R1_Q// /I}
KNOWN_R2_Q=${KNOWN_R2_Q// /J}

{
  printf '@known1 note\nTTTTTT%s\n+\nABCDEF%s\n' "$KNOWN_R1" "$KNOWN_R1_Q"
  printf '@known2\nCCCC%s\n+\n1234%s\n' "$KNOWN_R1" "$KNOWN_R1_Q"
  printf '@clean\nACACACACACACACAC\n+\nKLMNOPQRSTUVWXYZ\n'
} > "$ADAPTERS_TMP/known.single.fq"

cat > "$ADAPTERS_TMP/known.single.expected.fq" <<'EOF'
@known1 note
TTTTTT
+
ABCDEF
@known2
CCCC
+
1234
@clean
ACACACACACACACAC
+
KLMNOPQRSTUVWXYZ
EOF

if "$ADAPTERS_BIN" adapters -1 "$ADAPTERS_TMP/known.single.fq" \
    -o "$ADAPTERS_TMP/known.single.out.fq" --no-indels \
    2> "$ADAPTERS_TMP/known.single.err"; then
  adapters_compare "known-adapter scan trims reads and preserves exact qualities" \
    "$ADAPTERS_TMP/known.single.expected.fq" "$ADAPTERS_TMP/known.single.out.fq"
  if grep -q "Illumina TruSeq Adapter Read 1" \
      "$ADAPTERS_TMP/known.single.err"; then
    adapters_ok "known-adapter scan reports the selected database entry"
  else
    adapters_fail "known-adapter scan did not report the expected entry"
  fi
else
  adapters_fail "single-end known-adapter scan failed"
fi

KNOWN_R1_MISMATCH=C${KNOWN_R1:1}
printf '@known-mismatch\nTTTT%s\n+\nABCD%s\n' \
  "$KNOWN_R1_MISMATCH" "$KNOWN_R1_Q" > "$ADAPTERS_TMP/known.mismatch.fq"
cat > "$ADAPTERS_TMP/known.mismatch.expected.fq" <<'EOF'
@known-mismatch
TTTT
+
ABCD
EOF
if "$ADAPTERS_BIN" adapters -1 "$ADAPTERS_TMP/known.mismatch.fq" \
    -o "$ADAPTERS_TMP/known.mismatch.out.fq" --no-indels \
    2> "$ADAPTERS_TMP/known.mismatch.err"; then
  adapters_compare "known-adapter scan tolerates the configured error rate" \
    "$ADAPTERS_TMP/known.mismatch.expected.fq" \
    "$ADAPTERS_TMP/known.mismatch.out.fq"
else
  adapters_fail "mismatch-tolerant known-adapter scan failed"
fi

{
  printf '@known-pair1/1\nTTTTTT%s\n+\nABCDEF%s\n' "$KNOWN_R1" "$KNOWN_R1_Q"
  printf '@known-pair2/1\nCCCC%s\n+\n1234%s\n' "$KNOWN_R1" "$KNOWN_R1_Q"
} > "$ADAPTERS_TMP/known.R1.fq"
{
  printf '@known-pair1/2\nGGGG%s\n+\nWXYZ%s\n' "$KNOWN_R2" "$KNOWN_R2_Q"
  printf '@known-pair2/2\nTTTT%s\n+\n9876%s\n' "$KNOWN_R2" "$KNOWN_R2_Q"
} > "$ADAPTERS_TMP/known.R2.fq"

cat > "$ADAPTERS_TMP/known.R1.expected.fq" <<'EOF'
@known-pair1/1
TTTTTT
+
ABCDEF
@known-pair2/1
CCCC
+
1234
EOF

cat > "$ADAPTERS_TMP/known.R2.expected.fq" <<'EOF'
@known-pair1/2
GGGG
+
WXYZ
@known-pair2/2
TTTT
+
9876
EOF

if "$ADAPTERS_BIN" adapters \
    -1 "$ADAPTERS_TMP/known.R1.fq" -2 "$ADAPTERS_TMP/known.R2.fq" \
    -o "$ADAPTERS_TMP/known.R1.out.fq" -O "$ADAPTERS_TMP/known.R2.out.fq" \
    --no-indels 2> "$ADAPTERS_TMP/known.paired.err"; then
  adapters_compare "known-adapter scan detects and trims R1 independently" \
    "$ADAPTERS_TMP/known.R1.expected.fq" "$ADAPTERS_TMP/known.R1.out.fq"
  adapters_compare "known-adapter scan detects and trims R2 independently" \
    "$ADAPTERS_TMP/known.R2.expected.fq" "$ADAPTERS_TMP/known.R2.out.fq"
  if grep -q "detected R1 adapter" "$ADAPTERS_TMP/known.paired.err" &&
      grep -q "detected R2 adapter" "$ADAPTERS_TMP/known.paired.err"; then
    adapters_ok "paired scan reports separate adapters for both mates"
  else
    adapters_fail "paired scan did not report both mate adapters"
  fi
else
  adapters_fail "paired known-adapter scan failed"
fi

if "$ADAPTERS_BIN" adapters -A "$KNOWN_R2" \
    -1 "$ADAPTERS_TMP/known.R1.fq" -2 "$ADAPTERS_TMP/known.R2.fq" \
    -o "$ADAPTERS_TMP/explicit-only.R1.fq" \
    -O "$ADAPTERS_TMP/explicit-only.R2.fq" --no-indels \
    2> "$ADAPTERS_TMP/explicit-only.err"; then
  adapters_compare "an explicit R2 adapter leaves R1 unscanned and unchanged" \
    "$ADAPTERS_TMP/known.R1.fq" "$ADAPTERS_TMP/explicit-only.R1.fq"
  adapters_compare "an explicit R2 adapter trims only R2" \
    "$ADAPTERS_TMP/known.R2.expected.fq" \
    "$ADAPTERS_TMP/explicit-only.R2.fq"
else
  adapters_fail "R2-only explicit adapter command failed"
fi

cat > "$ADAPTERS_TMP/known.none.fq" <<'EOF'
@none1
ACACACACACACACAC
+
IIIIIIIIIIIIIIII
@none2
TGTGTGTGTGTGTGTG
+
JJJJJJJJJJJJJJJJ
EOF

if "$ADAPTERS_BIN" adapters -1 "$ADAPTERS_TMP/known.none.fq" \
    -o "$ADAPTERS_TMP/known.none.out.fq" --no-indels \
    2> "$ADAPTERS_TMP/known.none.err"; then
  adapters_compare "no known-adapter hit leaves reads unchanged" \
    "$ADAPTERS_TMP/known.none.fq" "$ADAPTERS_TMP/known.none.out.fq"
  if grep -q "no known adapter detected" "$ADAPTERS_TMP/known.none.err"; then
    adapters_ok "no-hit scan reports that no known adapter was selected"
  else
    adapters_fail "no-hit scan omitted its diagnostic"
  fi
else
  adapters_fail "no-hit known-adapter scan failed"
fi

if "$ADAPTERS_BIN" adapters -a "$KNOWN_R1" \
    -1 "$ADAPTERS_TMP/known.single.fq" -o "$ADAPTERS_TMP/known.explicit.fq" \
    --no-indels 2> "$ADAPTERS_TMP/known.explicit.err"; then
  adapters_compare "explicit adapter overrides automatic known-adapter detection" \
    "$ADAPTERS_TMP/known.single.expected.fq" "$ADAPTERS_TMP/known.explicit.fq"
  if ! grep -q "known adapter detected\|detected R1 adapter" \
      "$ADAPTERS_TMP/known.explicit.err"; then
    adapters_ok "explicit adapter bypasses the known-adapter scan"
  else
    adapters_fail "explicit adapter unexpectedly ran known-adapter detection"
  fi
else
  adapters_fail "explicit known adapter command failed"
fi

if "$ADAPTERS_BIN" adapters -K -a "$KNOWN_R1" \
    -1 "$ADAPTERS_TMP/known.single.fq" -o "$ADAPTERS_TMP/known.skip-explicit.fq" \
    --no-indels 2> "$ADAPTERS_TMP/known.skip-explicit.err"; then
  adapters_compare "--skip-known-adapters is compatible with explicit adapters" \
    "$ADAPTERS_TMP/known.single.expected.fq" \
    "$ADAPTERS_TMP/known.skip-explicit.fq"
else
  adapters_fail "--skip-known-adapters rejected an explicit adapter"
fi

if "$ADAPTERS_BIN" adapters -K -1 "$ADAPTERS_TMP/known.single.fq" \
    -o "$ADAPTERS_TMP/known.skip.fq" \
    2> "$ADAPTERS_TMP/known.skip.err"; then
  adapters_compare "--skip-known-adapters disables the default scan" \
    "$ADAPTERS_TMP/known.single.fq" "$ADAPTERS_TMP/known.skip.fq"
  if [[ ! -s "$ADAPTERS_TMP/known.skip.err" ]]; then
    adapters_ok "skipping detection emits no adapter-selection diagnostic"
  else
    adapters_fail "skipping detection unexpectedly emitted a diagnostic"
  fi
else
  adapters_fail "--skip-known-adapters failed without explicit adapters"
fi

if printf '@stdin\nTTTT%s\n+\nABCD%s\n' "$KNOWN_R1" "$KNOWN_R1_Q" | \
    "$ADAPTERS_BIN" adapters -1 - -o "$ADAPTERS_TMP/known.stdin.fq" \
    >/dev/null 2> "$ADAPTERS_TMP/known.stdin.err"; then
  adapters_fail "known-adapter scan unexpectedly accepted stdin"
elif grep -q "requires seekable input" "$ADAPTERS_TMP/known.stdin.err"; then
  adapters_ok "known-adapter scan explains its seekable-input requirement"
else
  adapters_fail "known-adapter stdin rejection returned the wrong diagnostic"
fi

cat > "$ADAPTERS_TMP/known.stdin.expected.fq" <<'EOF'
@stdin
TTTT
+
ABCD
EOF
if printf '@stdin\nTTTT%s\n+\nABCD%s\n' "$KNOWN_R1" "$KNOWN_R1_Q" | \
    "$ADAPTERS_BIN" adapters -a "$KNOWN_R1" -1 - \
    -o "$ADAPTERS_TMP/known.stdin.explicit.fq" --no-indels; then
  adapters_compare "explicit adapter input bypasses scanning and accepts stdin" \
    "$ADAPTERS_TMP/known.stdin.expected.fq" \
    "$ADAPTERS_TMP/known.stdin.explicit.fq"
else
  adapters_fail "explicit adapter stdin command failed"
fi

if "$ADAPTERS_BIN" primers --fwd ACGTACGT --rev AGTCAGTC \
    -1 "$ADAPTERS_TMP/single.fq" -o "$ADAPTERS_TMP/single.out.fq.gz" \
    --no-indels && gzip -t "$ADAPTERS_TMP/single.out.fq.gz" &&
    gzip -dc "$ADAPTERS_TMP/single.out.fq.gz" > "$ADAPTERS_TMP/single.unzipped.fq"; then
  adapters_compare "gzip output is valid and has the exact FASTQ payload" \
    "$ADAPTERS_TMP/single.expected.fq" "$ADAPTERS_TMP/single.unzipped.fq"
else
  adapters_fail "gzip output failed validation"
fi

head -n 4 "$ADAPTERS_TMP/R2.fq" > "$ADAPTERS_TMP/R2.short.fq"
if "$ADAPTERS_BIN" primers --fwd AACCGGTT --rev AGTCCGTA \
    -1 "$ADAPTERS_TMP/R1.fq" -2 "$ADAPTERS_TMP/R2.short.fq" \
    -o "$ADAPTERS_TMP/mismatch.fq" > /dev/null 2> "$ADAPTERS_TMP/mismatch.err"; then
  adapters_fail "paired EOF mismatch unexpectedly succeeded"
elif grep -q "ended prematurely" "$ADAPTERS_TMP/mismatch.err"; then
  adapters_ok "paired EOF mismatch reports an error"
else
  adapters_fail "paired EOF mismatch returned the wrong diagnostic"
fi

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Adapters tests: $PASS passed, $ERRORS failed"
  [[ $ERRORS -eq 0 ]]
fi
