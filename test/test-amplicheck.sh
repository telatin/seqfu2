TMP_AMPLICHECK_DIR=$(mktemp -d)
AMP_ERR="$TMP_AMPLICHECK_DIR/err.log"

AMP_ART_OUT="$TMP_AMPLICHECK_DIR/art"
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  --max-reads 0 --subsample 0.5 --outdir "$AMP_ART_OUT" --text > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck direct pair writes JSON/text and honors --max-reads 0 with --subsample"
if [[ $RET -eq 0 ]] && \
   [[ -s "$AMP_ART_OUT/report.json" ]] && \
   [[ -s "$AMP_ART_OUT/report.txt" ]] && \
   grep -q '"n_reads_total": 8' "$AMP_ART_OUT/report.json" && \
   grep -q '"n_reads_scanned": 8' "$AMP_ART_OUT/report.json" && \
   grep -q '"n_reads_sampled": 4' "$AMP_ART_OUT/report.json"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_PICO_OUT="$TMP_AMPLICHECK_DIR/pico"
"$BIN" amplicheck "$FILES"/primers/pico_R1.fq.gz "$FILES"/primers/pico_R2.fq.gz \
  --max-reads 10 --subsample 0.2 --only length,quality --no-json --text \
  --outdir "$AMP_PICO_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck bounded scan samples periodically across scanned pairs"
if [[ $RET -eq 0 ]] && \
   [[ ! -e "$AMP_PICO_OUT/report.json" ]] && \
   grep -q 'Reads: scanned=10 sampled=2' "$AMP_PICO_OUT/report.txt"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_VERBOSE_OUT="$TMP_AMPLICHECK_DIR/verbose"
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  --max-reads 4 --subsample 0.5 --only length,quality,merge --no-json --text -v \
  --outdir "$AMP_VERBOSE_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck verbose mode reports progress and sample summary"
if [[ $RET -eq 0 ]] && \
   grep -q 'amplicheck: sample art: start' "$AMP_ERR" && \
   grep -q 'progress scanned=2 sampled=1' "$AMP_ERR" && \
   grep -q 'parsed scanned=4 sampled=2' "$AMP_ERR" && \
   grep -q 'amplicheck: sample art: summary' "$AMP_ERR" && \
   grep -q '  length:' "$AMP_ERR" && \
   grep -q '  quality:' "$AMP_ERR" && \
   grep -q '  overlap:' "$AMP_ERR" && \
   grep -q '  recommendation:' "$AMP_ERR"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_PLOT_OUT="$TMP_AMPLICHECK_DIR/plot"
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  "$FILES"/primers/pico_R1.fq.gz "$FILES"/primers/pico_R2.fq.gz \
  --max-reads 4 --plot --no-json --outdir "$AMP_PLOT_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck --plot writes standalone HTML quality reports as an output format"
if [[ $RET -eq 0 ]] && \
   [[ ! -e "$AMP_PLOT_OUT/report.json" ]] && \
   [[ -s "$AMP_PLOT_OUT/plots/index.html" ]] && \
   [[ -s "$AMP_PLOT_OUT/plots/art.html" ]] && \
   [[ -s "$AMP_PLOT_OUT/plots/pico.html" ]] && \
   grep -q 'const SAMPLE =' "$AMP_PLOT_OUT/plots/art.html" && \
   grep -q 'drawQualityHeatmap' "$AMP_PLOT_OUT/plots/art.html" && \
   grep -q 'const INDEX_ROWS =' "$AMP_PLOT_OUT/plots/index.html" && \
   grep -q '"sample_id":"art"' "$AMP_PLOT_OUT/plots/index.html" && \
   grep -q '"sample_id":"pico"' "$AMP_PLOT_OUT/plots/index.html" && \
   grep -q 'Avg overlap' "$AMP_PLOT_OUT/plots/index.html" && \
   grep -q 'pageSize' "$AMP_PLOT_OUT/plots/index.html" && \
   grep -q 'sortBy' "$AMP_PLOT_OUT/plots/index.html"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  --only primers --plot --outdir "$TMP_AMPLICHECK_DIR/bad-plot" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck --plot requires quality stage"
if [[ $RET -ne 0 ]] && grep -q -- '--plot requires the quality stage' "$AMP_ERR"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_BATCH_OUT="$TMP_AMPLICHECK_DIR/batch"
"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  "$FILES"/primers/pico_R1.fq.gz "$FILES"/primers/pico_R2.fq.gz \
  --max-reads 2 --outdir "$AMP_BATCH_OUT" > /dev/null 2>"$AMP_ERR"
RET=$?
NSAMPLES=$(grep -c '"sample_id"' "$AMP_BATCH_OUT/report.json" 2>/dev/null || true)
MSG="amplicheck batch mode pairs files by tag substitution"
if [[ $RET -eq 0 ]] && [[ $NSAMPLES -eq 2 ]] && \
   grep -q '"n_reads_scanned": 2' "$AMP_BATCH_OUT/report.json"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET samples=$NSAMPLES err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

AMP_16S_OUT="$TMP_AMPLICHECK_DIR/16s"
"$BIN" amplicheck "$FILES"/primers/16S_R1.fq.gz "$FILES"/primers/16S_R2.fq.gz \
  --max-reads 100 --subsample 0.1 --only primers --outdir "$AMP_16S_OUT" \
  > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck labels known primers from bundled TSV"
if [[ $RET -eq 0 ]] && \
   grep -q '"fwd_label": "341F"' "$AMP_16S_OUT/report.json" && \
   grep -q '"rev_label": "785R/805R"' "$AMP_16S_OUT/report.json" && \
   grep -q '"orientation_consistent": true' "$AMP_16S_OUT/report.json"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

"$BIN" amplicheck "$FILES"/primers/art_R1.fq.gz "$FILES"/primers/art_R2.fq.gz \
  --subsample 0 --outdir "$TMP_AMPLICHECK_DIR/bad" > /dev/null 2>"$AMP_ERR"
RET=$?
MSG="amplicheck rejects invalid --subsample"
if [[ $RET -ne 0 ]] && grep -q -- '--subsample must satisfy' "$AMP_ERR"; then
  echo -e "$OK: $MSG"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: $MSG (exit=$RET err=$(cat "$AMP_ERR"))"
  ERRORS=$((ERRORS+1))
fi

rm -rf "$TMP_AMPLICHECK_DIR"
