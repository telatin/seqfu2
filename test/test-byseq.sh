#!/usr/bin/env bash

BYSEQ_BIN="${SEQFU_BIN:-${BINDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/}/seqfu}"
BYSEQ_TMP=$(mktemp -d)
PASS=${PASS:-0}
ERRORS=${ERRORS:-0}
OK=${OK:-'\033[0;32mOK\033[0m'}
FAIL=${FAIL:-'\033[0;31mFAIL\033[0m'}
trap 'rm -rf "$BYSEQ_TMP"' EXIT

byseq_ok() {
  echo -e "$OK: by-seq: $1"
  PASS=$((PASS+1))
}

byseq_fail() {
  echo -e "$FAIL: by-seq: $1"
  ERRORS=$((ERRORS+1))
}

byseq_names() {
  local label=$1 expected=$2
  shift 2
  if ! "$BYSEQ_BIN" by-seq "$@" > "$BYSEQ_TMP/actual"; then
    byseq_fail "$label (command failed)"
    return
  fi
  local actual
  actual=$(awk '/^[>@]/{sub(/^[>@]/, "", $1); print $1}' "$BYSEQ_TMP/actual" | paste -sd, -)
  if [[ "$actual" == "$expected" ]]; then
    byseq_ok "$label"
  else
    byseq_fail "$label (expected '$expected', got '$actual')"
  fi
}

byseq_error() {
  local label=$1
  shift
  if "$BYSEQ_BIN" by-seq "$@" > "$BYSEQ_TMP/error.out" 2> "$BYSEQ_TMP/error.err"; then
    byseq_fail "$label (unexpected success)"
  else
    byseq_ok "$label"
  fi
}

cat > "$BYSEQ_TMP/reads.fa" <<'EOF'
>overlap
AAAAA
>iupac
ACGTA
>reverse
ACT
>wrap
GGTT
>ambiguous
ACNTA
>lower
acgta
>repeat
ACTACT
EOF

cat > "$BYSEQ_TMP/R1.fq" <<'EOF'
@pair1/1 first
AAAA
+
I!I!
@pair2/1 second
TTTT
+
####
@pair3/1 third
ACT
+
III
EOF

cat > "$BYSEQ_TMP/R2.fq" <<'EOF'
@pair1/2 first
TTTT
+
JJJJ
@pair2/2 second
AAAA
+
!!!!
@pair3/2 third
ACT
+
HHH
EOF

cat > "$BYSEQ_TMP/interleaved.fq" <<'EOF'
@pair1/1 first
AAAA
+
I!I!
@pair1/2 first
TTTT
+
JJJJ
@pair2/1 second
TTTT
+
####
@pair2/2 second
AAAA
+
!!!!
@pair3/1 third
ACT
+
III
@pair3/2 third
ACT
+
HHH
EOF

cat > "$BYSEQ_TMP/pal.fa" <<'EOF'
>pal
AT
EOF

cat > "$BYSEQ_TMP/patterns.txt" <<'EOF'
# named patterns
alpha	AAA
theta	TTT
EOF

byseq_names 'IUPAC query degeneracy' 'iupac,lower' -e ACGTR "$BYSEQ_TMP/reads.fa"
byseq_names 'target N is uncallable in IUPAC mode' 'iupac,lower' -e ACNTA "$BYSEQ_TMP/reads.fa"
byseq_names 'literal target N' 'ambiguous' --literal -e ACNTA "$BYSEQ_TMP/reads.fa"
byseq_names 'case-sensitive IUPAC' 'iupac' --case-sensitive -e ACGTA "$BYSEQ_TMP/reads.fa"
byseq_names 'forward default' '' -e AGT "$BYSEQ_TMP/reads.fa"
byseq_names 'reverse complement' 'reverse,repeat' -e AGT --strand reverse "$BYSEQ_TMP/reads.fa"
byseq_names 'one mismatch' 'iupac,lower' -e ACCTA -m 1 "$BYSEQ_TMP/reads.fa"
byseq_names 'exactly three overlapping sites' 'overlap' -e AAA --occurrences 3 "$BYSEQ_TMP/reads.fa"
byseq_names 'exactly five circular sites' 'overlap' -e AAA --circular --occurrences 5 "$BYSEQ_TMP/reads.fa"
byseq_names 'circular origin match' 'wrap' -e TTGG --circular "$BYSEQ_TMP/reads.fa"
byseq_names 'linear excludes origin match' '' -e TTGG "$BYSEQ_TMP/reads.fa"
byseq_names 'motif longer than molecule does not lap' '' -e ACTACTACT --circular "$BYSEQ_TMP/reads.fa"
byseq_names 'zero means absence' 'overlap,reverse,wrap,ambiguous,repeat' -e ACGTA --occurrences 0 "$BYSEQ_TMP/reads.fa"
byseq_names 'regex counts overlaps' 'overlap' --regex -e AA --occurrences 4 "$BYSEQ_TMP/reads.fa"
byseq_names 'regex defaults to case-insensitive' 'iupac,lower' --regex -e ACGTA "$BYSEQ_TMP/reads.fa"
byseq_names 'regex zero-length does not count' 'overlap,iupac,reverse,wrap,ambiguous,lower,repeat' --regex -e '^' --occurrences 0 "$BYSEQ_TMP/reads.fa"
byseq_names 'inverted final selection' 'iupac,reverse,wrap,ambiguous,lower,repeat' -e AAA -v "$BYSEQ_TMP/reads.fa"
byseq_names 'paired any with all patterns' 'pair1/1,pair1/2,pair2/1,pair2/2' -e AAA -e TTT --logic all -1 "$BYSEQ_TMP/R1.fq" -2 "$BYSEQ_TMP/R2.fq"
byseq_names 'paired both with exact count' 'pair3/1,pair3/2' -e ACT --occurrences 1 --pair-mode both -1 "$BYSEQ_TMP/R1.fq" -2 "$BYSEQ_TMP/R2.fq"
byseq_names 'named pattern file and pair logic' 'pair1/1,pair1/2,pair2/1,pair2/2' -f "$BYSEQ_TMP/patterns.txt" --logic all -1 "$BYSEQ_TMP/R1.fq" -2 "$BYSEQ_TMP/R2.fq"
byseq_names 'interleaved input' 'pair1/1,pair1/2,pair2/1,pair2/2' -e AAA --interleaved "$BYSEQ_TMP/interleaved.fq"
byseq_names 'multiple single-end inputs' 'overlap,overlap' -e AAA "$BYSEQ_TMP/reads.fa" "$BYSEQ_TMP/reads.fa"
byseq_names 'range of occurrences' 'overlap' -e AAA --min-occurrences 2 --max-occurrences 3 "$BYSEQ_TMP/reads.fa"

cat "$BYSEQ_TMP/reads.fa" | "$BYSEQ_BIN" by-seq -e TTGG --circular > "$BYSEQ_TMP/stdin.fa"
if [[ $(awk '/^>/{print $1}' "$BYSEQ_TMP/stdin.fa") == '>wrap' ]]; then
  byseq_ok 'implicit stdin'
else
  byseq_fail 'implicit stdin'
fi

"$BYSEQ_BIN" by-seq -e ACT --pair-mode both -1 "$BYSEQ_TMP/R1.fq" -2 "$BYSEQ_TMP/R2.fq" > "$BYSEQ_TMP/pair.out"
cat > "$BYSEQ_TMP/pair.expected" <<'EOF'
@pair3/1 third
ACT
+
III
@pair3/2 third
ACT
+
HHH
EOF
if cmp -s "$BYSEQ_TMP/pair.expected" "$BYSEQ_TMP/pair.out"; then
  byseq_ok 'paired FASTQ sequence, quality, and order'
else
  byseq_fail 'paired FASTQ sequence, quality, and order'
fi

"$BYSEQ_BIN" by-seq -e ACT --pair-mode both -1 "$BYSEQ_TMP/R1.fq" -2 "$BYSEQ_TMP/R2.fq" \
  -o "$BYSEQ_TMP/selected_R1.fq.gz"
if gzip -t "$BYSEQ_TMP/selected_R1.fq.gz" "$BYSEQ_TMP/selected_R2.fq.gz" &&
    [[ $(gzip -cd "$BYSEQ_TMP/selected_R1.fq.gz" | awk '/^@/{print $1}') == '@pair3/1' ]] &&
    [[ $(gzip -cd "$BYSEQ_TMP/selected_R2.fq.gz" | awk '/^@/{print $1}') == '@pair3/2' ]]; then
  byseq_ok 'inferred split gzip outputs'
else
  byseq_fail 'inferred split gzip outputs'
fi

"$BYSEQ_BIN" by-seq -e AAA -1 "$BYSEQ_TMP/R1.fq" -2 "$BYSEQ_TMP/R2.fq" \
  -t 2 --batch-size 1 > "$BYSEQ_TMP/threaded.fq"
"$BYSEQ_BIN" by-seq -e AAA -1 "$BYSEQ_TMP/R1.fq" -2 "$BYSEQ_TMP/R2.fq" \
  > "$BYSEQ_TMP/single.fq"
if cmp -s "$BYSEQ_TMP/single.fq" "$BYSEQ_TMP/threaded.fq"; then
  byseq_ok 'threaded pair order and payload'
else
  byseq_fail 'threaded pair order and payload'
fi

"$BYSEQ_BIN" by-seq -e AAA -e TTT -1 "$BYSEQ_TMP/R1.fq" -2 "$BYSEQ_TMP/R2.fq" \
  --hits "$BYSEQ_TMP/single.tsv" > "$BYSEQ_TMP/single-hits.fq"
"$BYSEQ_BIN" by-seq -e AAA -e TTT -1 "$BYSEQ_TMP/R1.fq" -2 "$BYSEQ_TMP/R2.fq" \
  --hits "$BYSEQ_TMP/threaded.tsv" -t 2 --batch-size 1 > "$BYSEQ_TMP/threaded-hits.fq"
if cmp -s "$BYSEQ_TMP/single-hits.fq" "$BYSEQ_TMP/threaded-hits.fq" &&
    cmp -s "$BYSEQ_TMP/single.tsv" "$BYSEQ_TMP/threaded.tsv"; then
  byseq_ok 'threaded hit report and sequence order'
else
  byseq_fail 'threaded hit report and sequence order'
fi

"$BYSEQ_BIN" by-seq -e ACT --interleaved "$BYSEQ_TMP/interleaved.fq" \
  -o "$BYSEQ_TMP/fallback.fq"
if cmp -s "$BYSEQ_TMP/fallback.fq" "$BYSEQ_TMP/pair.expected"; then
  byseq_ok 'paired -o fallback is interleaved'
else
  byseq_fail 'paired -o fallback is interleaved'
fi

"$BYSEQ_BIN" by-seq -e ACT --interleaved "$BYSEQ_TMP/interleaved.fq" \
  -o "$BYSEQ_TMP/forced_R1.fq" --interleaved-output
if cmp -s "$BYSEQ_TMP/forced_R1.fq" "$BYSEQ_TMP/pair.expected" &&
    [[ ! -e "$BYSEQ_TMP/forced_R2.fq" ]]; then
  byseq_ok 'explicit interleaved output overrides R2 inference'
else
  byseq_fail 'explicit interleaved output overrides R2 inference'
fi

"$BYSEQ_BIN" by-seq -e ACT -1 "$BYSEQ_TMP/R1.fq" -2 "$BYSEQ_TMP/R2.fq" \
  -o "$BYSEQ_TMP/explicit-1.fq" -O "$BYSEQ_TMP/explicit-2.fq"
if [[ $(awk '/^@/{print $1}' "$BYSEQ_TMP/explicit-1.fq") == '@pair3/1' ]] &&
    [[ $(awk '/^@/{print $1}' "$BYSEQ_TMP/explicit-2.fq") == '@pair3/2' ]]; then
  byseq_ok 'explicit split paired output'
else
  byseq_fail 'explicit split paired output'
fi

"$BYSEQ_BIN" by-seq -e TTGG --circular --hits "$BYSEQ_TMP/hits.tsv.gz" \
  "$BYSEQ_TMP/reads.fa" > "$BYSEQ_TMP/wrap.fa"
expected_hit=$(printf '%s\twrap\t1\tpattern_1\t+\t2\t2\t0\ttrue' "$BYSEQ_TMP/reads.fa")
actual_hit=$(gzip -cd "$BYSEQ_TMP/hits.tsv.gz" | tail -1)
if [[ "$actual_hit" == "$expected_hit" ]]; then
  byseq_ok 'circular hit coordinates and gzip report'
else
  byseq_fail "circular hit coordinates and gzip report (got '$actual_hit')"
fi

"$BYSEQ_BIN" by-seq -e AT --strand both --occurrences 1 --hits "$BYSEQ_TMP/pal.tsv" \
  "$BYSEQ_TMP/pal.fa" > "$BYSEQ_TMP/pal.out"
if [[ $(wc -l < "$BYSEQ_TMP/pal.tsv") -eq 2 ]] &&
    [[ $(tail -1 "$BYSEQ_TMP/pal.tsv") == *$'\tboth\t0\t2\t0\tfalse' ]]; then
  byseq_ok 'palindrome is one both-strand site'
else
  byseq_fail 'palindrome is one both-strand site'
fi

"$BYSEQ_BIN" by-seq -e AAA --occurrences 0 --hits "$BYSEQ_TMP/absent.tsv" \
  "$BYSEQ_TMP/reads.fa" > "$BYSEQ_TMP/absent.fa"
if [[ $(wc -l < "$BYSEQ_TMP/absent.tsv") -eq 1 ]]; then
  byseq_ok 'absence selection writes no site rows'
else
  byseq_fail 'absence selection writes no site rows'
fi

byseq_error 'exact count conflicts with explicit min' -e AAA --occurrences 1 --min-occurrences 1 "$BYSEQ_TMP/reads.fa"
byseq_error 'regex rejects reverse mode' --regex --strand both -e AA "$BYSEQ_TMP/reads.fa"
byseq_error 'regex rejects explicit mismatch zero' --regex -m 0 -e AA "$BYSEQ_TMP/reads.fa"
byseq_error 'IUPAC rejects invalid symbol' -e ACZ "$BYSEQ_TMP/reads.fa"
byseq_error 'literal reverse requires DNA' --literal --strand reverse -e ACN "$BYSEQ_TMP/reads.fa"
byseq_error 'R2 output requires paired input' -e AAA -O "$BYSEQ_TMP/R2.out" "$BYSEQ_TMP/reads.fa"
byseq_error 'hits cannot overwrite input' -e AAA --hits "$BYSEQ_TMP/reads.fa" "$BYSEQ_TMP/reads.fa"
byseq_error 'cannot overwrite pattern file' -f "$BYSEQ_TMP/patterns.txt" -o "$BYSEQ_TMP/patterns.txt" "$BYSEQ_TMP/reads.fa"
byseq_error 'invalid count bounds' -e AAA --min-occurrences 3 --max-occurrences 2 "$BYSEQ_TMP/reads.fa"

echo "by-seq: $PASS passed, $ERRORS failed"
(( ERRORS == 0 ))
