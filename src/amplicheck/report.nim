import json
import os
import sequtils
import strformat
import strutils

import ./types

proc floatArray(values: seq[float]): JsonNode =
  result = newJArray()
  for value in values:
    result.add(%value)

proc lengthJson(summary: ReadLengthSummary): JsonNode =
  %* {
    "n": summary.n,
    "mean": summary.mean,
    "sd": summary.sd,
    "min": summary.min,
    "max": summary.max,
    "mode": summary.mode
  }

proc qualityJson(summary: ReadQualitySummary): JsonNode =
  result = newJObject()
  result["n"] = %summary.n
  result["total_bases"] = %summary.totalBases
  result["skipped_too_long"] = %summary.skippedTooLong
  result["max_read_length_for_quality"] = %MaxQualityReadLength
  result["binned"] = %summary.binned
  result["distinct_values"] = %summary.distinctValues
  result["mean_quality"] = %summary.meanQuality
  result["suggested_truncLen"] = %summary.suggestedTruncLen
  result["per_position_mean"] = floatArray(summary.perPositionMean)

proc primerSideJson(side: PrimerSideSummary): JsonNode =
  %* {
    "detected": side.detected,
    "primer": side.primer,
    "label": side.label,
    "direction": side.direction,
    "target_domain": side.targetDomain,
    "typical_amplicon_region": side.region,
    "citation": side.citation,
    "consensus": side.consensus,
    "support_count": side.supportCount,
    "support_fraction": side.supportFraction,
    "score": side.score
  }

proc primerJson(summary: PrimerSummary): JsonNode =
  result = newJObject()
  result["detected"] = %summary.detected
  result["fwd_primer"] = %summary.fwdPrimer
  result["rev_primer"] = %summary.revPrimer
  result["fwd_label"] = %summary.fwdLabel
  result["rev_label"] = %summary.revLabel
  result["orientation_consistent"] = %summary.orientationConsistent
  result["r1"] = primerSideJson(summary.r1)
  result["r2"] = primerSideJson(summary.r2)

proc mergeJson(summary: MergeSummary): JsonNode =
  %* {
    "attempted": summary.attempted,
    "merged": summary.merged,
    "unmergeable": summary.unmergeable,
    "overlap_mean": summary.overlapMean,
    "overlap_sd": summary.overlapSd,
    "pct_identity_mean": summary.identityMean,
    "pct_identity_sd": summary.identitySd,
    "expected_merged_size_mean": summary.expectedMergedSizeMean,
    "expected_merged_size_sd": summary.expectedMergedSizeSd,
    "pct_unmergeable": summary.pctUnmergeable,
    "amplicon_call": summary.ampliconCall
  }

proc sweepComboJson(combo: SweepComboSummary): JsonNode =
  %* {
    "truncLen_fwd": combo.truncLenFwd,
    "truncLen_rev": combo.truncLenRev,
    "maxEE": combo.maxEE,
    "scanned": combo.scanned,
    "retained": combo.retained,
    "merged": combo.merged,
    "retention_pct": combo.retentionPct,
    "merge_rate_pct": combo.mergeRatePct,
    "score": combo.score
  }

proc sweepJson(summary: SweepSummary): JsonNode =
  if not summary.enabled:
    return newJNull()
  result = newJObject()
  result["best"] = sweepComboJson(summary.best)
  result["grid"] = newJArray()
  for combo in summary.combos:
    result["grid"].add(sweepComboJson(combo))

proc recommendationJson(rec: Recommendation): JsonNode =
  result = newJObject()
  result["truncLen_fwd"] = %rec.truncLenFwd
  result["truncLen_rev"] = %rec.truncLenRev
  result["maxEE"] = floatArray(rec.maxEE)
  result["truncQ"] = %rec.truncQ
  result["strategy"] = %rec.strategy
  result["note"] = %rec.note

proc toJson*(report: AmplicheckReport): JsonNode =
  result = newJObject()
  result["sample_id"] = %report.sampleId
  result["r1"] = %report.r1
  result["r2"] = %report.r2
  if report.nReadsTotalKnown:
    result["n_reads_total"] = %report.nReadsScanned
  else:
    result["n_reads_total"] = newJNull()
  result["n_reads_scanned"] = %report.nReadsScanned
  result["n_reads_sampled"] = %report.nReadsSampled

  result["primers"] =
    if report.primersEnabled: primerJson(report.primers) else: newJNull()

  if report.lengthEnabled:
    result["length"] = %* {
      "r1": lengthJson(report.lengthR1),
      "r2": lengthJson(report.lengthR2)
    }
  else:
    result["length"] = newJNull()

  if report.qualityEnabled:
    result["quality"] = %* {
      "r1": qualityJson(report.qualityR1),
      "r2": qualityJson(report.qualityR2)
    }
  else:
    result["quality"] = newJNull()

  result["merge"] =
    if report.mergeEnabled: mergeJson(report.merge) else: newJNull()
  result["sweep"] =
    if report.sweepEnabled: sweepJson(report.sweep) else: newJNull()
  result["recommendation"] =
    if report.recommendationEnabled: recommendationJson(report.recommendation) else: newJNull()

proc renderText*(report: AmplicheckReport): string =
  result.add(fmt"Sample: {report.sampleId}" & "\n")
  result.add(fmt"  R1: {report.r1}" & "\n")
  result.add(fmt"  R2: {report.r2}" & "\n")
  result.add(fmt"  Reads: scanned={report.nReadsScanned} sampled={report.nReadsSampled}" & "\n")

  if report.primersEnabled:
    result.add(fmt"  Primers: R1={report.primers.r1.label} {report.primers.r1.primer}; R2={report.primers.r2.label} {report.primers.r2.primer}; orientation_consistent={report.primers.orientationConsistent}" & "\n")
  if report.lengthEnabled:
    result.add(fmt"  Length: R1 mean={report.lengthR1.mean:.1f} sd={report.lengthR1.sd:.1f} mode={report.lengthR1.mode}; R2 mean={report.lengthR2.mean:.1f} sd={report.lengthR2.sd:.1f} mode={report.lengthR2.mode}" & "\n")
  if report.qualityEnabled:
    result.add(fmt"  Quality: R1 mean={report.qualityR1.meanQuality:.1f} distinct={report.qualityR1.distinctValues} skipped_long={report.qualityR1.skippedTooLong}; R2 mean={report.qualityR2.meanQuality:.1f} distinct={report.qualityR2.distinctValues} skipped_long={report.qualityR2.skippedTooLong}" & "\n")
  if report.mergeEnabled:
    result.add(fmt"  Overlap: merged={report.merge.merged}/{report.merge.attempted} unmergeable={report.merge.pctUnmergeable:.1f}% mean_overlap={report.merge.overlapMean:.1f} mean_identity={report.merge.identityMean:.1f}%" & "\n")
  if report.recommendationEnabled:
    var maxEEParts: seq[string]
    for value in report.recommendation.maxEE:
      maxEEParts.add($value)
    let maxEEText = maxEEParts.join(",")
    result.add(fmt"  Recommendation: strategy={report.recommendation.strategy} truncLen=({report.recommendation.truncLenFwd},{report.recommendation.truncLenRev}) truncQ={report.recommendation.truncQ} maxEE=({maxEEText})" & "\n")
  result.add("\n")

proc primerText(side: PrimerSideSummary): string =
  if not side.detected:
    return "not detected"
  let name =
    if side.label.len > 0: side.label
    else: side.primer
  fmt"{name} support={side.supportFraction * 100.0:.1f}%"

proc maxEEText(values: seq[float]): string =
  var parts: seq[string]
  for value in values:
    parts.add($value)
  parts.join(",")

proc renderVerboseSummary*(report: AmplicheckReport): string =
  result.add(fmt"amplicheck: sample {report.sampleId}: summary" & "\n")
  let totalText =
    if report.nReadsTotalKnown: $report.nReadsScanned
    else: "unknown"
  result.add(fmt"  reads: scanned={report.nReadsScanned} sampled={report.nReadsSampled} total={totalText}" & "\n")

  if report.lengthEnabled:
    result.add(fmt"  length: R1 mean={report.lengthR1.mean:.1f} mode={report.lengthR1.mode} range={report.lengthR1.min}-{report.lengthR1.max}; R2 mean={report.lengthR2.mean:.1f} mode={report.lengthR2.mode} range={report.lengthR2.min}-{report.lengthR2.max}" & "\n")

  if report.qualityEnabled:
    result.add(fmt"  quality: R1 mean={report.qualityR1.meanQuality:.1f} cycles={report.qualityR1.perPositionMean.len} skipped_long={report.qualityR1.skippedTooLong}; R2 mean={report.qualityR2.meanQuality:.1f} cycles={report.qualityR2.perPositionMean.len} skipped_long={report.qualityR2.skippedTooLong}" & "\n")

  if report.primersEnabled:
    result.add(fmt"  primers: R1={primerText(report.primers.r1)}; R2={primerText(report.primers.r2)}; orientation_consistent={report.primers.orientationConsistent}" & "\n")

  if report.mergeEnabled:
    result.add(fmt"  overlap: merged={report.merge.merged}/{report.merge.attempted} unmergeable={report.merge.pctUnmergeable:.1f}% mean_overlap={report.merge.overlapMean:.1f} mean_identity={report.merge.identityMean:.1f}%" & "\n")

  if report.sweepEnabled:
    result.add(fmt"  sweep: combos={report.sweep.combos.len} best_truncLen=({report.sweep.best.truncLenFwd},{report.sweep.best.truncLenRev}) best_maxEE={report.sweep.best.maxEE} retained={report.sweep.best.retentionPct:.1f}% merged={report.sweep.best.mergeRatePct:.1f}%" & "\n")

  if report.recommendationEnabled:
    result.add(fmt"  recommendation: strategy={report.recommendation.strategy} truncLen=({report.recommendation.truncLenFwd},{report.recommendation.truncLenRev}) truncQ={report.recommendation.truncQ} maxEE=({maxEEText(report.recommendation.maxEE)})" & "\n")

proc safeName(s: string): string =
  for c in s:
    if c.isAlphaNumeric or c in {'-', '_', '.'}:
      result.add(c)
    else:
      result.add('_')
  if result.len == 0:
    result = "sample"

proc perCycleJson(summary: ReadQualitySummary): JsonNode =
  result = newJArray()
  for counts in summary.qCounts:
    var
      n = 0
      sum = 0
      qCountsNode = newJArray()
    for q, count in counts:
      n += count
      sum += q * count
      qCountsNode.add(%count)
    result.add(%* {
      "n": n,
      "sum": sum,
      "qCounts": qCountsNode
    })

proc plotQualityJson(summary: ReadQualitySummary, filename: string): JsonNode =
  %* {
    "name": filename,
    "reads": summary.n,
    "totalBases": summary.totalBases,
    "skippedTooLong": summary.skippedTooLong,
    "maxReadLength": MaxQualityReadLength,
    "perCycle": perCycleJson(summary)
  }

proc plotDataJson(report: AmplicheckReport): JsonNode =
  result = %* {
    "sample_id": report.sampleId,
    "r1_file": report.r1,
    "r2_file": report.r2,
    "n_reads_scanned": report.nReadsScanned,
    "n_reads_sampled": report.nReadsSampled,
    "r1": plotQualityJson(report.qualityR1, report.r1),
    "r2": plotQualityJson(report.qualityR2, report.r2)
  }
  result["recommendation"] =
    if report.recommendationEnabled: recommendationJson(report.recommendation) else: newJNull()
  result["primers"] =
    if report.primersEnabled: primerJson(report.primers) else: newJNull()

proc jsJson(node: JsonNode): string =
  ($node).replace("</", "<\\/")

const plotTemplate = """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>SeqFu amplicheck quality plot</title>
  <style>
    :root {
      --acid-green: #B6BE00;
      --dark-green: #097E74;
      --charcoal: #2F3D46;
      --bg: #f4f6f5;
      --card: #ffffff;
      --grid: rgba(47,61,70,.16);
      --muted: rgba(47,61,70,.70);
    }
    body { font-family: system-ui, -apple-system, Segoe UI, sans-serif; margin: 0; background: var(--bg); color: var(--charcoal); }
    header { padding: 1rem 1.25rem; background: var(--charcoal); color: white; border-bottom: 5px solid var(--dark-green); }
    main { max-width: 1280px; margin: 0 auto; padding: 1rem; }
    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: .75rem; margin-bottom: 1rem; }
    .tile, .plotcard { background: var(--card); border-radius: 8px; padding: .9rem 1rem; box-shadow: 0 1px 8px rgba(47,61,70,.10); }
    .tile h2 { margin: 0 0 .35rem; font-size: .9rem; color: var(--dark-green); }
    .tile p { margin: 0; font-size: 1.25rem; font-weight: 700; }
    .tile .small { margin-top: .25rem; font-weight: 400; }
    .plots { display: grid; grid-template-columns: repeat(auto-fit, minmax(560px, 1fr)); gap: 1rem; }
    canvas { width: 100%; border: 1px solid rgba(47,61,70,.18); background: white; border-radius: 8px; }
    .qualityCanvas { height: 460px; }
    .heatmapCanvas { height: 330px; margin-top: .75rem; }
    .small { color: var(--muted); font-size: .9rem; overflow-wrap: anywhere; }
    a { color: var(--dark-green); }
  </style>
</head>
<body>
  <header>
    <h1 id="title">SeqFu amplicheck</h1>
    <div class="small" style="color:rgba(255,255,255,.82)">Self-contained quality report</div>
  </header>
  <main>
    <section class="summary">
      <div class="tile"><h2>Reads</h2><p id="reads"></p><div class="small" id="sampled"></div></div>
      <div class="tile"><h2>R1</h2><p id="r1reads"></p><div class="small" id="r1file"></div></div>
      <div class="tile"><h2>R2</h2><p id="r2reads"></p><div class="small" id="r2file"></div></div>
      <div class="tile"><h2>Recommendation</h2><p id="strategy"></p><div class="small" id="trunc"></div></div>
    </section>
    <section class="plots">
      <div class="plotcard">
        <canvas id="chartF" class="qualityCanvas"></canvas>
        <canvas id="heatF" class="heatmapCanvas"></canvas>
      </div>
      <div class="plotcard">
        <canvas id="chartR" class="qualityCanvas"></canvas>
        <canvas id="heatR" class="heatmapCanvas"></canvas>
      </div>
    </section>
  </main>
<script>
const SAMPLE = @@DATA@@;
const MAX_RENDER_POINTS = 900;
const THEME = {
  acid: '#B6BE00',
  green: '#097E74',
  charcoal: '#2F3D46'
};
const $ = id => document.getElementById(id);

window.addEventListener('load', () => {
  document.title = `SeqFu amplicheck: ${SAMPLE.sample_id}`;
  $('title').textContent = `SeqFu amplicheck: ${SAMPLE.sample_id}`;
  $('reads').textContent = compact(SAMPLE.n_reads_scanned);
  $('sampled').textContent = `${compact(SAMPLE.n_reads_sampled)} sampled read pairs`;
  $('r1reads').textContent = `${compact(SAMPLE.r1.reads)} reads`;
  $('r1file').textContent = `${SAMPLE.r1_file}${SAMPLE.r1.skippedTooLong ? `; skipped long reads: ${compact(SAMPLE.r1.skippedTooLong)}` : ''}`;
  $('r2reads').textContent = `${compact(SAMPLE.r2.reads)} reads`;
  $('r2file').textContent = `${SAMPLE.r2_file}${SAMPLE.r2.skippedTooLong ? `; skipped long reads: ${compact(SAMPLE.r2.skippedTooLong)}` : ''}`;
  $('strategy').textContent = SAMPLE.recommendation ? SAMPLE.recommendation.strategy : 'not available';
  $('trunc').textContent = SAMPLE.recommendation ? `truncLen ${SAMPLE.recommendation.truncLen_fwd}, ${SAMPLE.recommendation.truncLen_rev}; truncQ ${SAMPLE.recommendation.truncQ}` : '';
  drawQualityPlot('chartF', 'R1 quality', SAMPLE.r1);
  drawQualityHeatmap('heatF', 'R1 heatmap', SAMPLE.r1);
  drawQualityPlot('chartR', 'R2 quality', SAMPLE.r2);
  drawQualityHeatmap('heatR', 'R2 heatmap', SAMPLE.r2);
});

function drawQualityPlot(canvasId, title, stats) {
  const canvas = setupCanvas(canvasId, 460);
  const ctx = canvas.ctx, w = canvas.w, h = canvas.h;
  const pad = { l: 62, r: 56, t: 54, b: 58 };
  const plotW = w - pad.l - pad.r;
  const plotH = h - pad.t - pad.b;
  const rowsRaw = stats.perCycle.filter(slot => slot && slot.n > 0).map((slot, i) => {
    const q = quantilesFromCounts(slot.qCounts, slot.n);
    return { x: i + 1, mean: slot.sum / slot.n, p10: q['0.1'], q1: q['0.25'], median: q['0.5'], q3: q['0.75'], p90: q['0.9'], represented: 100 * slot.n / Math.max(1, stats.reads) };
  });
  const rows = downsampleRows(rowsRaw, MAX_RENDER_POINTS);
  const maxX = Math.max(1, stats.perCycle.length);
  const xToPx = x => pad.l + (x - 1) / Math.max(1, maxX - 1) * plotW;
  const qToPx = q => pad.t + (45 - q) / 45 * plotH;
  const pctToPx = p => pad.t + (100 - p) / 100 * plotH;
  drawPanelTitle(ctx, w, title, `${compact(stats.reads)} reads`);
  drawAxes(ctx, w, h, pad, plotW, plotH, maxX, 45, 'Quality score');
  drawBand(ctx, rows, 'p10', 'p90', xToPx, qToPx, 'rgba(9,126,116,0.10)');
  drawBand(ctx, rows, 'q1', 'q3', xToPx, qToPx, 'rgba(9,126,116,0.20)');
  drawLine(ctx, rows, 'median', xToPx, qToPx, THEME.charcoal, 2.2, []);
  drawLine(ctx, rows, 'mean', xToPx, qToPx, THEME.green, 1.8, [6, 4]);
  drawLine(ctx, rows, 'represented', xToPx, pctToPx, THEME.acid, 1.4, []);
  ctx.fillStyle = THEME.charcoal; ctx.font = '18px system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'bottom';
  ctx.fillText('Cycle', pad.l + plotW / 2, h - 8);
  ctx.fillStyle = THEME.acid; ctx.font = '16px system-ui'; ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
  ctx.fillText('100%', w - 6, pctToPx(100)); ctx.fillText('0%', w - 6, pctToPx(0));
  const ly = h - 26;
  legendLine(ctx, pad.l, ly, THEME.charcoal, [], 'median');
  legendLine(ctx, pad.l + 100, ly, THEME.green, [6,4], 'mean');
  legendLine(ctx, pad.l + 180, ly, THEME.acid, [], '% reads represented');
}

function drawQualityHeatmap(canvasId, title, stats) {
  const canvas = setupCanvas(canvasId, 330);
  const ctx = canvas.ctx, w = canvas.w, h = canvas.h;
  const pad = { l: 62, r: 56, t: 46, b: 56 };
  const plotW = w - pad.l - pad.r;
  const plotH = h - pad.t - pad.b;
  const maxX = Math.max(1, stats.perCycle.length);
  const maxQ = 45;
  const minQ = 0;
  drawPanelTitle(ctx, w, 'Quality-count heatmap', title);
  drawAxes(ctx, w, h, pad, plotW, plotH, maxX, maxQ, 'Q score');
  const binsX = Math.min(maxX, Math.max(1, Math.floor(plotW)));
  const binsQ = maxQ - minQ + 1;
  const matrix = Array.from({ length: binsX }, () => new Float64Array(binsQ));
  let maxCount = 0;
  for (let pos = 0; pos < stats.perCycle.length; pos++) {
    const slot = stats.perCycle[pos];
    if (!slot) continue;
    const bx = Math.min(binsX - 1, Math.floor(pos * binsX / maxX));
    for (let q = minQ; q <= maxQ; q++) {
      const c = slot.qCounts[q] || 0;
      if (!c) continue;
      matrix[bx][q - minQ] += c;
      if (matrix[bx][q - minQ] > maxCount) maxCount = matrix[bx][q - minQ];
    }
  }
  const cellW = plotW / binsX;
  const cellH = plotH / binsQ;
  for (let bx = 0; bx < binsX; bx++) {
    const x = pad.l + bx * cellW;
    for (let q = minQ; q <= maxQ; q++) {
      const count = matrix[bx][q - minQ];
      if (!count) continue;
      const y = pad.t + (maxQ - q) * cellH;
      ctx.fillStyle = heatColor(count, maxCount);
      ctx.fillRect(x, y, Math.ceil(cellW) + 0.5, Math.ceil(cellH) + 0.5);
    }
  }
  ctx.strokeStyle = 'rgba(47,61,70,.70)'; ctx.lineWidth = 1; ctx.strokeRect(pad.l, pad.t, plotW, plotH);
  ctx.fillStyle = THEME.charcoal; ctx.font = '18px system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'bottom';
  ctx.fillText('Cycle', pad.l + plotW / 2, h - 8);
  const lx = w - pad.r - 155, ly = h - 32, lw = 120, lh = 10;
  for (let i = 0; i < lw; i++) {
    const value = Math.pow(i / (lw - 1), 2) * maxCount;
    ctx.fillStyle = heatColor(value, maxCount);
    ctx.fillRect(lx + i, ly, 1, lh);
  }
  ctx.strokeStyle = 'rgba(47,61,70,.35)'; ctx.strokeRect(lx, ly, lw, lh);
  ctx.fillStyle = THEME.charcoal; ctx.font = '11px system-ui'; ctx.textAlign = 'left'; ctx.textBaseline = 'top';
  ctx.fillText('0', lx, ly + 13);
  ctx.textAlign = 'right'; ctx.fillText(compact(maxCount), lx + lw, ly + 13);
  ctx.textAlign = 'center'; ctx.fillText('bases per Q/cycle bin', lx + lw / 2, ly - 14);
}

function setupCanvas(id, cssHeight) {
  const canvas = $(id);
  const rect = canvas.getBoundingClientRect();
  const dpr = window.devicePixelRatio || 1;
  canvas.width = Math.max(600, Math.floor(rect.width * dpr));
  canvas.height = Math.floor(cssHeight * dpr);
  const ctx = canvas.getContext('2d');
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.scale(dpr, dpr);
  const w = canvas.width / dpr, h = canvas.height / dpr;
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = 'white'; ctx.fillRect(0, 0, w, h);
  return { canvas, ctx, w, h };
}
function drawPanelTitle(ctx, w, title, subtitle) {
  ctx.fillStyle = 'rgba(9,126,116,.12)'; ctx.fillRect(0, 0, w, 34);
  ctx.strokeStyle = 'rgba(47,61,70,.35)'; ctx.strokeRect(0.5, 0.5, w - 1, 33);
  ctx.fillStyle = THEME.charcoal; ctx.textAlign = 'center'; ctx.font = '700 15px system-ui'; ctx.textBaseline = 'middle';
  ctx.fillText(`${title}  ${subtitle}`, w / 2, 18);
}
function drawAxes(ctx, w, h, pad, plotW, plotH, maxX, maxY, yLabel) {
  const xToPx = x => pad.l + (x - 1) / Math.max(1, maxX - 1) * plotW;
  const yToPx = y => pad.t + (maxY - y) / maxY * plotH;
  ctx.strokeStyle = 'rgba(47,61,70,.14)'; ctx.lineWidth = 1;
  ctx.fillStyle = 'rgba(47,61,70,.85)'; ctx.font = '12px system-ui'; ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
  for (let y = 0; y <= maxY; y += 5) {
    if (y % 10 !== 0 && maxY > 30) continue;
    const yp = yToPx(y);
    ctx.beginPath(); ctx.moveTo(pad.l, yp); ctx.lineTo(w - pad.r, yp); ctx.stroke();
    ctx.fillText(y, pad.l - 8, yp);
  }
  ctx.textAlign = 'center'; ctx.textBaseline = 'top';
  const xStep = niceStep(maxX);
  for (let x = 0; x <= maxX; x += xStep) ctx.fillText(x, xToPx(Math.max(1, x)), h - pad.b + 10);
  ctx.strokeStyle = 'rgba(47,61,70,.70)'; ctx.strokeRect(pad.l, pad.t, plotW, plotH);
  ctx.save(); ctx.translate(18, pad.t + plotH / 2); ctx.rotate(-Math.PI / 2);
  ctx.fillStyle = THEME.charcoal; ctx.font = '16px system-ui'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(yLabel, 0, 0);
  ctx.restore();
}
function drawBand(ctx, rows, lo, hi, xToPx, yToPx, color) {
  if (!rows.length) return;
  ctx.beginPath();
  rows.forEach((r, i) => { const x = xToPx(r.x), y = yToPx(r[hi]); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); });
  for (let i = rows.length - 1; i >= 0; i--) { const r = rows[i]; ctx.lineTo(xToPx(r.x), yToPx(r[lo])); }
  ctx.closePath(); ctx.fillStyle = color; ctx.fill();
}
function drawLine(ctx, rows, key, xToPx, yToPx, color, width, dash) {
  if (!rows.length) return;
  ctx.beginPath(); ctx.strokeStyle = color; ctx.lineWidth = width; ctx.setLineDash(dash);
  rows.forEach((r, i) => { const x = xToPx(r.x), y = yToPx(r[key]); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); });
  ctx.stroke(); ctx.setLineDash([]);
}
function legendLine(ctx, x, y, color, dash, text) {
  ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.setLineDash(dash); ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + 26, y); ctx.stroke(); ctx.setLineDash([]);
  ctx.fillStyle = THEME.charcoal; ctx.font = '12px system-ui'; ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; ctx.fillText(text, x + 32, y);
}
function heatColor(count, maxCount) {
  if (!maxCount || count <= 0) return 'rgba(255,255,255,0)';
  const t = Math.sqrt(count / maxCount);
  const low = hexToRgb(THEME.acid);
  const high = hexToRgb(THEME.green);
  const r = Math.round(low.r + (high.r - low.r) * t);
  const g = Math.round(low.g + (high.g - low.g) * t);
  const b = Math.round(low.b + (high.b - low.b) * t);
  const a = 0.18 + 0.82 * t;
  return `rgba(${r},${g},${b},${a})`;
}
function hexToRgb(hex) {
  const v = hex.replace('#','');
  return { r: parseInt(v.slice(0,2),16), g: parseInt(v.slice(2,4),16), b: parseInt(v.slice(4,6),16) };
}
function quantilesFromCounts(counts, n) {
  const targets = { 0.1: Math.ceil(n * 0.10), 0.25: Math.ceil(n * 0.25), 0.5: Math.ceil(n * 0.50), 0.75: Math.ceil(n * 0.75), 0.9: Math.ceil(n * 0.90) };
  const out = {};
  let cumulative = 0;
  const keys = Object.keys(targets);
  for (let q = 0; q < counts.length; q++) {
    cumulative += counts[q];
    for (const k of keys) if (out[k] === undefined && cumulative >= targets[k]) out[k] = q;
  }
  return out;
}
function downsampleRows(rows, maxPoints) {
  if (rows.length <= maxPoints) return rows;
  const step = Math.ceil(rows.length / maxPoints);
  const out = [];
  for (let i = 0; i < rows.length; i += step) {
    const chunk = rows.slice(i, i + step);
    const avg = { x: Math.round(chunk.reduce((s, r) => s + r.x, 0) / chunk.length) };
    for (const k of ['mean','p10','q1','median','q3','p90','represented']) avg[k] = chunk.reduce((s, r) => s + r[k], 0) / chunk.length;
    out.push(avg);
  }
  return out;
}
function niceStep(maxX) {
  const raw = Math.max(1, maxX / 5);
  const pow = Math.pow(10, Math.floor(Math.log10(raw)));
  const n = raw / pow;
  return (n <= 2 ? 2 : n <= 5 ? 5 : 10) * pow;
}
function compact(n) {
  if (n >= 1e9) return (n / 1e9).toFixed(1) + 'B';
  if (n >= 1e6) return (n / 1e6).toFixed(1) + 'M';
  if (n >= 1e3) return (n / 1e3).toFixed(1) + 'K';
  return Math.round(n || 0).toLocaleString();
}
</script>
</body>
</html>
"""

proc renderPlotHtml(report: AmplicheckReport): string =
  plotTemplate.replace("@@DATA@@", jsJson(plotDataJson(report)))

proc maybeInt(enabled: bool, value: int): JsonNode =
  if enabled:
    return %value
  newJNull()

proc maybeFloat(enabled: bool, value: float): JsonNode =
  if enabled:
    return %value
  newJNull()

proc primerName(side: PrimerSideSummary): string =
  if side.label.len > 0:
    return side.label
  side.primer

proc primerSummaryText(report: AmplicheckReport): string =
  if not report.primersEnabled:
    return ""
  var labels: seq[string]
  let r1 = primerName(report.primers.r1)
  let r2 = primerName(report.primers.r2)
  if r1.len > 0:
    labels.add("R1=" & r1)
  if r2.len > 0:
    labels.add("R2=" & r2)
  labels.join("; ")

proc primerStatusText(report: AmplicheckReport): string =
  if not report.primersEnabled:
    return "n/a"
  if report.primers.detected:
    return "yes"
  "no"

proc mergeRatePct(summary: MergeSummary): float =
  if summary.attempted == 0:
    return 0.0
  100.0 * float(summary.merged) / float(summary.attempted)

proc recommendationTruncLen(report: AmplicheckReport): string =
  if not report.recommendationEnabled:
    return ""
  fmt"{report.recommendation.truncLenFwd},{report.recommendation.truncLenRev}"

proc indexRowJson(report: AmplicheckReport, filename: string): JsonNode =
  result = newJObject()
  result["sample_id"] = %report.sampleId
  result["filename"] = %filename
  result["n_reads_total"] = maybeInt(report.nReadsTotalKnown, report.nReadsScanned)
  result["n_reads_scanned"] = %report.nReadsScanned
  result["n_reads_sampled"] = %report.nReadsSampled
  result["primers_status"] = %primerStatusText(report)
  result["primer_labels"] = %primerSummaryText(report)
  result["primer_orientation_ok"] =
    if report.primersEnabled: %report.primers.orientationConsistent else: newJNull()
  result["r1_length_mean"] = maybeFloat(report.lengthEnabled, report.lengthR1.mean)
  result["r2_length_mean"] = maybeFloat(report.lengthEnabled, report.lengthR2.mean)
  result["r1_quality_mean"] = maybeFloat(report.qualityEnabled, report.qualityR1.meanQuality)
  result["r2_quality_mean"] = maybeFloat(report.qualityEnabled, report.qualityR2.meanQuality)
  result["overlap_mean"] = maybeFloat(report.mergeEnabled, report.merge.overlapMean)
  result["merge_rate_pct"] = maybeFloat(report.mergeEnabled, mergeRatePct(report.merge))
  result["unmergeable_pct"] = maybeFloat(report.mergeEnabled, report.merge.pctUnmergeable)
  result["trunc_len"] = %recommendationTruncLen(report)
  result["strategy"] =
    if report.recommendationEnabled: %report.recommendation.strategy else: %""

proc indexRowsJson(rows: seq[tuple[report: AmplicheckReport, filename: string]]): JsonNode =
  result = newJArray()
  for row in rows:
    result.add(indexRowJson(row.report, row.filename))

const indexTemplate = """
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>SeqFu amplicheck plots</title>
  <style>
    :root {
      --acid-green: #B6BE00;
      --dark-green: #097E74;
      --charcoal: #2F3D46;
      --bg: #f4f6f5;
      --card: #ffffff;
      --grid: rgba(47,61,70,.16);
      --muted: rgba(47,61,70,.70);
    }
    body { font-family: system-ui, -apple-system, Segoe UI, sans-serif; margin: 0; background: var(--bg); color: var(--charcoal); }
    header { padding: 1rem 1.25rem; background: var(--charcoal); color: white; border-bottom: 5px solid var(--dark-green); }
    main { max-width: 1280px; margin: 0 auto; padding: 1rem; }
    .toolbar { display: flex; gap: .75rem; align-items: center; justify-content: space-between; flex-wrap: wrap; margin: 0 0 .8rem; }
    .toolbar label { display: inline-flex; gap: .4rem; align-items: center; font-size: .92rem; color: var(--muted); }
    input, select { border: 1px solid rgba(47,61,70,.24); border-radius: 6px; padding: .45rem .55rem; color: var(--charcoal); background: white; font: inherit; }
    input { min-width: min(360px, 80vw); }
    .table-wrap { background: var(--card); border-radius: 8px; box-shadow: 0 1px 8px rgba(47,61,70,.10); overflow: auto; }
    table { width: 100%; border-collapse: collapse; min-width: 1120px; }
    th, td { border-bottom: 1px solid var(--grid); padding: .55rem .65rem; text-align: left; vertical-align: top; font-size: .9rem; }
    th { background: rgba(9,126,116,.09); position: sticky; top: 0; z-index: 1; }
    th button { appearance: none; border: 0; background: transparent; color: var(--charcoal); font: inherit; font-weight: 700; padding: 0; cursor: pointer; text-align: left; }
    th button .mark { color: var(--dark-green); margin-left: .25rem; }
    td.num { text-align: right; font-variant-numeric: tabular-nums; }
    td.status { font-weight: 700; text-transform: uppercase; }
    a { color: var(--dark-green); font-weight: 700; }
    .muted { color: var(--muted); }
    .pager { display: flex; gap: .55rem; align-items: center; justify-content: flex-end; flex-wrap: wrap; margin-top: .8rem; }
    .pager button { border: 1px solid rgba(47,61,70,.24); border-radius: 6px; background: white; color: var(--charcoal); padding: .45rem .7rem; font: inherit; cursor: pointer; }
    .pager button:disabled { opacity: .45; cursor: default; }
  </style>
</head>
<body>
  <header>
    <h1>SeqFu amplicheck plots</h1>
    <div class="muted" style="color:rgba(255,255,255,.82)">Sample summary and quality report links</div>
  </header>
  <main>
    <div class="toolbar">
      <label>Filter <input id="filter" type="search" autocomplete="off" placeholder="sample, primer, strategy" /></label>
      <label>Rows <select id="pageSize"><option>10</option><option selected>25</option><option>50</option><option>100</option><option value="0">All</option></select></label>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr id="head"></tr></thead>
        <tbody id="body"></tbody>
      </table>
    </div>
    <div class="pager">
      <span id="count" class="muted"></span>
      <button type="button" id="prev">Previous</button>
      <span id="page" class="muted"></span>
      <button type="button" id="next">Next</button>
    </div>
  </main>
<script>
const INDEX_ROWS = @@ROWS@@;
const COLUMNS = [
  { key: 'sample_id', label: 'Sample', type: 'text' },
  { key: 'filename', label: 'Quality', type: 'link' },
  { key: 'primers_status', label: 'Primers', type: 'status' },
  { key: 'primer_labels', label: 'Primer labels', type: 'text' },
  { key: 'n_reads_total', label: 'Tot reads', type: 'number', nullText: 'unknown' },
  { key: 'n_reads_scanned', label: 'Scanned', type: 'number' },
  { key: 'n_reads_sampled', label: 'Sampled', type: 'number' },
  { key: 'r1_length_mean', label: 'R1 len', type: 'number', digits: 1 },
  { key: 'r2_length_mean', label: 'R2 len', type: 'number', digits: 1 },
  { key: 'r1_quality_mean', label: 'R1 Q', type: 'number', digits: 1 },
  { key: 'r2_quality_mean', label: 'R2 Q', type: 'number', digits: 1 },
  { key: 'overlap_mean', label: 'Avg overlap', type: 'number', digits: 1 },
  { key: 'merge_rate_pct', label: 'Merge %', type: 'number', digits: 1 },
  { key: 'unmergeable_pct', label: 'Unmergeable %', type: 'number', digits: 1 },
  { key: 'trunc_len', label: 'truncLen', type: 'text' },
  { key: 'strategy', label: 'Strategy', type: 'text' }
];
const state = { sortKey: 'sample_id', sortDir: 1, page: 1, pageSize: 25, filter: '' };
const $ = id => document.getElementById(id);

window.addEventListener('load', () => {
  buildHeader();
  $('filter').addEventListener('input', e => { state.filter = e.target.value.toLowerCase(); state.page = 1; render(); });
  $('pageSize').addEventListener('change', e => { state.pageSize = Number(e.target.value); state.page = 1; render(); });
  $('prev').addEventListener('click', () => { if (state.page > 1) { state.page--; render(); } });
  $('next').addEventListener('click', () => { state.page++; render(); });
  render();
});

function buildHeader() {
  const head = $('head');
  for (const col of COLUMNS) {
    const th = document.createElement('th');
    const button = document.createElement('button');
    button.type = 'button';
    button.dataset.sort = col.key;
    button.append(document.createTextNode(col.label));
    const mark = document.createElement('span');
    mark.className = 'mark';
    button.append(mark);
    button.addEventListener('click', () => sortBy(col.key));
    th.append(button);
    head.append(th);
  }
}

function sortBy(key) {
  if (state.sortKey === key) state.sortDir *= -1;
  else { state.sortKey = key; state.sortDir = 1; }
  state.page = 1;
  render();
}

function filteredRows() {
  const needle = state.filter;
  let rows = INDEX_ROWS;
  if (needle) {
    rows = rows.filter(row => [
      row.sample_id, row.primers_status, row.primer_labels, row.strategy, row.trunc_len
    ].join(' ').toLowerCase().includes(needle));
  }
  return rows.slice().sort((a, b) => compareValues(a[state.sortKey], b[state.sortKey]) * state.sortDir);
}

function compareValues(a, b) {
  if (a === null || a === undefined || a === '') return (b === null || b === undefined || b === '') ? 0 : 1;
  if (b === null || b === undefined || b === '') return -1;
  if (typeof a === 'number' && typeof b === 'number') return a === b ? 0 : (a < b ? -1 : 1);
  return String(a).localeCompare(String(b), undefined, { numeric: true, sensitivity: 'base' });
}

function render() {
  const rows = filteredRows();
  const pageSize = state.pageSize === 0 ? rows.length || 1 : state.pageSize;
  const pages = Math.max(1, Math.ceil(rows.length / pageSize));
  if (state.page > pages) state.page = pages;
  const start = (state.page - 1) * pageSize;
  const pageRows = rows.slice(start, start + pageSize);
  renderSortMarks();
  renderBody(pageRows);
  $('count').textContent = `${rows.length.toLocaleString()} samples`;
  $('page').textContent = `Page ${state.page} of ${pages}`;
  $('prev').disabled = state.page <= 1;
  $('next').disabled = state.page >= pages;
}

function renderSortMarks() {
  document.querySelectorAll('th button').forEach(button => {
    const mark = button.querySelector('.mark');
    mark.textContent = button.dataset.sort === state.sortKey ? (state.sortDir > 0 ? '^' : 'v') : '';
  });
}

function renderBody(rows) {
  const body = $('body');
  body.textContent = '';
  if (!rows.length) {
    const tr = document.createElement('tr');
    const td = document.createElement('td');
    td.colSpan = COLUMNS.length;
    td.className = 'muted';
    td.textContent = 'No samples match the current filter.';
    tr.append(td);
    body.append(tr);
    return;
  }
  for (const row of rows) {
    const tr = document.createElement('tr');
    for (const col of COLUMNS) tr.append(cell(row, col));
    body.append(tr);
  }
}

function cell(row, col) {
  const td = document.createElement('td');
  if (col.type === 'number') td.className = 'num';
  if (col.type === 'status') td.className = 'status';
  if (col.type === 'link') {
    const a = document.createElement('a');
    a.href = row.filename;
    a.textContent = 'heatmap';
    td.append(a);
    return td;
  }
  td.textContent = formatValue(row[col.key], col);
  return td;
}

function formatValue(value, col) {
  if (value === null || value === undefined || value === '') return col.nullText || 'n/a';
  if (col.type === 'number') {
    const opts = { maximumFractionDigits: col.digits || 0 };
    if (col.digits) opts.minimumFractionDigits = col.digits;
    return Number(value).toLocaleString(undefined, opts);
  }
  return String(value);
}
</script>
</body>
</html>
"""

proc renderPlotIndex(rows: seq[tuple[report: AmplicheckReport, filename: string]]): string =
  indexTemplate.replace("@@ROWS@@", jsJson(indexRowsJson(rows)))

proc writePlots(reports: seq[AmplicheckReport], outdir: string) =
  let plotsDir = outdir / "plots"
  createDir(plotsDir)
  var entries: seq[tuple[report: AmplicheckReport, filename: string]]
  for i, report in reports:
    let filename = safeName(report.sampleId) & ".html"
    let uniqueFilename =
      if entries.anyIt(it.filename == filename): safeName(report.sampleId) & "_" & $(i + 1) & ".html"
      else: filename
    writeFile(plotsDir / uniqueFilename, renderPlotHtml(report))
    entries.add((report: report, filename: uniqueFilename))
  writeFile(plotsDir / "index.html", renderPlotIndex(entries))

proc writeReports*(reports: seq[AmplicheckReport], outdir: string,
                   writeJson, writeText, writePlotsEnabled: bool) =
  createDir(outdir)

  if writeJson:
    var jsonReports = newJArray()
    for report in reports:
      jsonReports.add(report.toJson())
    writeFile(outdir / "report.json", jsonReports.pretty)

  if writeText:
    var text = ""
    for report in reports:
      text.add(report.renderText())
    writeFile(outdir / "report.txt", text)

  if writePlotsEnabled:
    writePlots(reports, outdir)
