#!/usr/bin/env bash

BYID_BIN="${BINDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/}/seqfu"
BYID_TMP=$(mktemp -d)
PASS=${PASS:-0}
ERRORS=${ERRORS:-0}
OK=${OK:-'\033[0;32mOK\033[0m'}
FAIL=${FAIL:-'\033[0;31mFAIL\033[0m'}

byid_ok() {
  echo -e "$OK: by-id: $1"
  PASS=$((PASS+1))
}

byid_fail() {
  echo -e "$FAIL: by-id: $1"
  ERRORS=$((ERRORS+1))
}

byid_expect_names() {
  local label=$1 expected=$2
  shift 2
  local actual
  if ! "$BYID_BIN" by-id "$@" > "$BYID_TMP/names.out"; then
    byid_fail "$label (command failed)"
    return
  fi
  actual=$(awk '/^[>@]/{sub(/^[>@]/, "", $1); print $1}' "$BYID_TMP/names.out" | paste -sd, -)
  if [[ "$actual" == "$expected" ]]; then
    byid_ok "$label"
  else
    byid_fail "$label (expected '$expected', got '$actual')"
  fi
}

byid_expect_error() {
  local label=$1
  shift
  if "$BYID_BIN" by-id "$@" > "$BYID_TMP/error.out" 2> "$BYID_TMP/error.err"; then
    byid_fail "$label (unexpected success)"
  else
    byid_ok "$label"
  fi
}

cat > "$BYID_TMP/ids.fa" <<'EOF'
>contig_001 alpha
ACG
>contig_002 beta
TTT
>contig_005
GGA
>contig_010
TTA
>NODE_25_length_900
CGC
>sampleX
CCC
>contig_999999999999999999999999
AAA
EOF

cat > "$BYID_TMP/ids2.fa" <<'EOF'
>contig_011
ATG
>other_003
TGC
EOF

cat > "$BYID_TMP/patterns.txt" <<'EOF'
# One pattern per line
>contig_001
@contig_005

EOF

cat > "$BYID_TMP/R1.fq" <<'EOF'
@pair_001/1 first
ACG
+
III
@pair_002/1 second
TTT
+
###
@pair_003/1 third
GGA
+
I!I
EOF

cat > "$BYID_TMP/R2.fq" <<'EOF'
@pair_001/2 first
TGC
+
JJJ
@pair_002/2 second
AAA
+
$$$
@pair_003/2 third
TCC
+
J!J
EOF

cat > "$BYID_TMP/R2_missing.fq" <<'EOF'
@pair_X/2 first
TGC
+
JJJ
@pair_002/2 second
AAA
+
$$$
@pair_003/2 third
TCC
+
J!J
EOF

cat > "$BYID_TMP/interleaved.fq" <<'EOF'
@pair_001/1 first
ACG
+
III
@pair_001/2 first
TGC
+
JJJ
@pair_002/1 second
TTT
+
###
@pair_002/2 second
AAA
+
$$$
@pair_003/1 third
GGA
+
I!I
@pair_003/2 third
TCC
+
J!J
EOF

if "$BYID_BIN" --help | awk '
  /  · grep[[:space:]]+:/ {
    getline
    if ($0 ~ /  · by-comment[[:space:]]+:/) getline
    if ($0 ~ /  · by-id[[:space:]]+:/) found = 1
  }
  END { exit !found }
'; then
  byid_ok "CLI help groups by-id below grep"
else
  byid_fail "CLI help groups by-id below grep"
fi

byid_expect_names "regex substring" "contig_001,contig_002,contig_005,contig_010,contig_999999999999999999999999" \
  '^contig_' "$BYID_TMP/ids.fa"
byid_expect_names "exact fixed string" "contig_002" \
  -F -x contig_002 "$BYID_TMP/ids.fa"
byid_expect_names "case-insensitive matching" "contig_001" \
  -i -F -x CONTIG_001 "$BYID_TMP/ids.fa"
byid_expect_names "repeat patterns with OR" "contig_001,contig_005" \
  -e contig_001 -e contig_005 -F -x "$BYID_TMP/ids.fa"
byid_expect_names "repeat patterns with AND" "contig_001,contig_002" \
  -e contig_ -e '00[12]$' --logic all "$BYID_TMP/ids.fa"
byid_expect_names "pattern file and marker stripping" "contig_001,contig_005" \
  -f "$BYID_TMP/patterns.txt" --strip-marker -F -x "$BYID_TMP/ids.fa"
byid_expect_names "inverted selection" "contig_001,contig_002,contig_005,contig_010,NODE_25_length_900,sampleX" \
  -v -F -x contig_999999999999999999999999 "$BYID_TMP/ids.fa"
byid_expect_names "multiple single-end files in order" "contig_001,contig_002,contig_005,contig_010,contig_999999999999999999999999,contig_011" \
  -e contig_ "$BYID_TMP/ids.fa" "$BYID_TMP/ids2.fa"
byid_expect_names "inclusive numeric range" "contig_002,contig_005" \
  --number-range 2:5 "$BYID_TMP/ids.fa"
byid_expect_names "strict numeric bounds" "contig_005" \
  --number-gt 2 --number-lt 10 "$BYID_TMP/ids.fa"
byid_expect_names "leading zeroes compare numerically" "contig_001" \
  --number-eq 1 "$BYID_TMP/ids.fa"
byid_expect_names "custom numeric capture" "NODE_25_length_900" \
  --number-regex '^NODE_([0-9]+)_' --number-range 20:30 "$BYID_TMP/ids.fa"
byid_expect_names "text and numeric predicates" "contig_005,contig_010" \
  -e '^contig_' --number-range 5:10 "$BYID_TMP/ids.fa"
byid_expect_names "missing and overflow kept when requested" "contig_001,contig_002,contig_005,contig_010,sampleX,contig_999999999999999999999999" \
  --number-lt 20 --missing-number keep "$BYID_TMP/ids.fa"
byid_expect_error "invalid numeric interval" --number-range 10:2 "$BYID_TMP/ids.fa"
byid_expect_error "numeric regex without capture" --number-regex 'NODE_[0-9]+' --number-ge 1 "$BYID_TMP/ids.fa"
byid_expect_error "missing numeric component with error policy" --number-ge 1 --missing-number error "$BYID_TMP/ids.fa"
byid_expect_error "invalid regex" '[' "$BYID_TMP/ids.fa"

cat "$BYID_TMP/ids.fa" | "$BYID_BIN" by-id -e '^sampleX$' - > "$BYID_TMP/stdin.fa"
if [[ $(awk '/^>/{print $1}' "$BYID_TMP/stdin.fa") == '>sampleX' ]]; then
  byid_ok "explicit stdin"
else
  byid_fail "explicit stdin"
fi

cat "$BYID_TMP/ids.fa" | "$BYID_BIN" by-id -e '^sampleX$' > "$BYID_TMP/implicit-stdin.fa"
if cmp -s "$BYID_TMP/stdin.fa" "$BYID_TMP/implicit-stdin.fa"; then
  byid_ok "implicit stdin"
else
  byid_fail "implicit stdin"
fi

"$BYID_BIN" by-id -e '^contig_00[125]$' -o "$BYID_TMP/selected.fa.gz" "$BYID_TMP/ids.fa"
if gzip -t "$BYID_TMP/selected.fa.gz" &&
   [[ $(gzip -cd "$BYID_TMP/selected.fa.gz" | awk '/^>/{print $1}' | paste -sd, -) == '>contig_001,>contig_002,>contig_005' ]]; then
  byid_ok "gzip single-end output"
else
  byid_fail "gzip single-end output"
fi

byid_expect_names "paired stdout interleaved" "pair_002/1,pair_002/2" \
  -e '/1$' -e 'pair_002' --logic all -1 "$BYID_TMP/R1.fq" -2 "$BYID_TMP/R2.fq"
byid_expect_names "paired both-mate mode" "pair_001/1,pair_001/2,pair_002/1,pair_002/2" \
  -e 'pair_00[12]' --pair-mode both -1 "$BYID_TMP/R1.fq" -2 "$BYID_TMP/R2.fq"
byid_expect_names "interleaved input and numeric strip-pair" "pair_002/1,pair_002/2,pair_003/1,pair_003/2" \
  --strip-pair --number-range 2:3 --interleaved "$BYID_TMP/interleaved.fq"

"$BYID_BIN" by-id -e '^pair_' -1 "$BYID_TMP/R1.fq" -2 "$BYID_TMP/R2.fq" \
  -o "$BYID_TMP/all_R1.fq" -O "$BYID_TMP/all_R2.fq"
if cmp -s "$BYID_TMP/R1.fq" "$BYID_TMP/all_R1.fq" &&
   cmp -s "$BYID_TMP/R2.fq" "$BYID_TMP/all_R2.fq"; then
  byid_ok "paired split output preserves names, comments, sequences, and qualities"
else
  byid_fail "paired split output preserves names, comments, sequences, and qualities"
fi

"$BYID_BIN" by-id -e '^pair_' -1 "$BYID_TMP/R1.fq" -2 "$BYID_TMP/R2.fq" \
  -o "$BYID_TMP/inferred_R1.fq.gz"
if gzip -t "$BYID_TMP/inferred_R1.fq.gz" && gzip -t "$BYID_TMP/inferred_R2.fq.gz" &&
   cmp -s "$BYID_TMP/R1.fq" <(gzip -cd "$BYID_TMP/inferred_R1.fq.gz") &&
   cmp -s "$BYID_TMP/R2.fq" <(gzip -cd "$BYID_TMP/inferred_R2.fq.gz"); then
  byid_ok "paired R2 filename inference and gzip"
else
  byid_fail "paired R2 filename inference and gzip"
fi

"$BYID_BIN" by-id -e '^pair_' -1 "$BYID_TMP/R1.fq" -2 "$BYID_TMP/R2.fq" \
  -o "$BYID_TMP/combined.fq"
if cmp -s "$BYID_TMP/interleaved.fq" "$BYID_TMP/combined.fq"; then
  byid_ok "paired -o fallback is interleaved"
else
  byid_fail "paired -o fallback is interleaved"
fi

"$BYID_BIN" by-id -e '^pair_' -1 "$BYID_TMP/R1.fq" -2 "$BYID_TMP/R2.fq" \
  -o "$BYID_TMP/forced_R1.fq" --interleaved-output
if cmp -s "$BYID_TMP/interleaved.fq" "$BYID_TMP/forced_R1.fq" &&
   [[ ! -e "$BYID_TMP/forced_R2.fq" ]]; then
  byid_ok "forced interleaved output overrides inference"
else
  byid_fail "forced interleaved output overrides inference"
fi

"$BYID_BIN" by-id -e '^pair_' -t 2 --batch-size 1 -1 "$BYID_TMP/R1.fq" -2 "$BYID_TMP/R2.fq" \
  -o "$BYID_TMP/thread_R1.fq" -O "$BYID_TMP/thread_R2.fq"
if cmp -s "$BYID_TMP/R1.fq" "$BYID_TMP/thread_R1.fq" &&
   cmp -s "$BYID_TMP/R2.fq" "$BYID_TMP/thread_R2.fq"; then
  byid_ok "threaded paired output stays ordered and exact"
else
  byid_fail "threaded paired output stays ordered and exact"
fi

byid_expect_names "threaded single-end selection" "contig_001,contig_002,contig_005,contig_010,contig_999999999999999999999999" \
  -e '^contig_' -t 2 --batch-size 1 "$BYID_TMP/ids.fa"

byid_expect_error "missing numeric component in R2 is not skipped" \
  --strip-pair --number-ge 1 --missing-number error -1 "$BYID_TMP/R1.fq" -2 "$BYID_TMP/R2_missing.fq"

byid_expect_error "paired input needs both files" -e pair -1 "$BYID_TMP/R1.fq"
byid_expect_error "paired input rejects positional files" -e pair -1 "$BYID_TMP/R1.fq" -2 "$BYID_TMP/R2.fq" "$BYID_TMP/ids.fa"
byid_expect_error "output cannot overwrite input" -e contig -o "$BYID_TMP/ids.fa" "$BYID_TMP/ids.fa"
byid_expect_error "output cannot overwrite pattern file" -f "$BYID_TMP/patterns.txt" \
  -o "$BYID_TMP/patterns.txt" "$BYID_TMP/ids.fa"
ln -s "$BYID_TMP/ids.fa" "$BYID_TMP/ids-link.fa"
byid_expect_error "output symlink cannot overwrite input" -e contig \
  -o "$BYID_TMP/ids-link.fa" "$BYID_TMP/ids.fa"
byid_expect_error "single-end rejects -O" -e contig -O "$BYID_TMP/extra.fa" "$BYID_TMP/ids.fa"
byid_expect_error "single-end rejects interleaved output switch" -e contig \
  --interleaved-output "$BYID_TMP/ids.fa"
byid_expect_error "interleaved input needs one stream" -e pair --interleaved "$BYID_TMP/R1.fq" "$BYID_TMP/R2.fq"

rm -r "$BYID_TMP"
