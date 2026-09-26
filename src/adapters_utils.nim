import std/[math, sequtils, sets, strutils, tables]
import malebolgia
import readfx
import ./filter_utils
import ./known_adapters

type
  AdapterEnd* = object
    sequence*: string
    masks*: seq[uint8]

  AdapterSpec* = object
    fivePrime*: AdapterEnd
    threePrime*: AdapterEnd
    hasFivePrime*: bool
    hasThreePrime*: bool

  AdapterMatch* = object
    matched*: bool
    adapterStart*, adapterStop*: int
    readStart*, readStop*: int
    errors*, score*: int

  AdapterDiscardReason* = enum
    adrNone, adrMissingFivePrime, adrMissingThreePrime, adrEmptyInsert

  AdapterTrimResult* = object
    matchedFivePrime*, matchedThreePrime*: bool
    trimStart*, trimEnd*: int
    record*: FQRecord
    discardReason*: AdapterDiscardReason

  AdapterMatchOptions* = object
    errorRate*: float
    minOverlap*: int
    allowIndels*: bool

  AdapterStats* = object
    processed*, written*, trimmedFivePrime*, trimmedThreePrime*, discarded*: int64

  AdapterBatch* = object
    first*, second*: seq[FQRecord]
    resultsFirst*, resultsSecond*: seq[AdapterTrimResult]
    paired*: bool

  AdapterWorkerOptions* = object
    firstSpec*, secondSpec*: AdapterSpec
    matchOptions*: AdapterMatchOptions
    hasFirstSpec*, hasSecondSpec*: bool

  KnownAdapterDetection* = object
    found*: bool
    adapter*: KnownAdapter
    hits*, scannedReads*: int
    scannedBases*: int64

  KnownAdapterSeed = object
    adapterIndex, offset: int

const
  KNOWN_ADAPTER_SCAN_READS* = 100_000
  KNOWN_ADAPTER_SCAN_BASES* = 100_000_000'i64
  KNOWN_ADAPTER_SEED_LENGTH = 8
  KNOWN_ADAPTER_MIN_OVERLAP = 12

proc adapterBaseMask*(base: char): uint8 {.inline.} =
  case base.toUpperAscii()
  of 'A': 1
  of 'C': 2
  of 'G': 4
  of 'T', 'U': 8
  of 'R': 5
  of 'Y': 10
  of 'S': 6
  of 'W': 9
  of 'K': 12
  of 'M': 3
  of 'B': 14
  of 'D': 13
  of 'H': 11
  of 'V': 7
  of 'N': 15
  else: 0

proc normalizeAdapterDna*(sequence: string): string =
  if sequence.len == 0:
    raise newException(ValueError, "Adapter sequence cannot be empty")
  result = newString(sequence.len)
  for i, base in sequence:
    let normalized = if base.toUpperAscii() == 'U': 'T' else: base.toUpperAscii()
    if adapterBaseMask(normalized) == 0:
      raise newException(ValueError, "Invalid IUPAC DNA base '" & $base &
        "' in adapter: " & sequence)
    result[i] = normalized

proc reverseComplementAdapter*(sequence: string): string =
  let normalized = normalizeAdapterDna(sequence)
  result = newString(normalized.len)
  for i, base in normalized:
    result[normalized.len - i - 1] = case base
      of 'A': 'T'
      of 'C': 'G'
      of 'G': 'C'
      of 'T': 'A'
      of 'R': 'Y'
      of 'Y': 'R'
      of 'S': 'S'
      of 'W': 'W'
      of 'K': 'M'
      of 'M': 'K'
      of 'B': 'V'
      of 'D': 'H'
      of 'H': 'D'
      of 'V': 'B'
      of 'N': 'N'
      else: 'N'

proc prepareAdapterEnd(sequence: string): AdapterEnd =
  result.sequence = normalizeAdapterDna(sequence)
  result.masks = newSeq[uint8](result.sequence.len)
  for i, base in result.sequence:
    result.masks[i] = adapterBaseMask(base)

proc parseAdapterSpec*(spec: string): AdapterSpec =
  let firstEllipsis = spec.find("...")
  if firstEllipsis < 0:
    result.threePrime = prepareAdapterEnd(spec)
    result.hasThreePrime = true
    return
  if spec.find("...", firstEllipsis + 3) >= 0:
    raise newException(ValueError, "Adapter spec may contain only one '...': " & spec)
  let left = spec[0 ..< firstEllipsis]
  let right = spec[firstEllipsis + 3 .. ^1]
  if left.len == 0 and right.len == 0:
    raise newException(ValueError, "Adapter spec cannot be only '...'")
  if left.len > 0:
    result.fivePrime = prepareAdapterEnd(left)
    result.hasFivePrime = true
  if right.len > 0:
    result.threePrime = prepareAdapterEnd(right)
    result.hasThreePrime = true

proc linkedPrimerSpec*(fivePrime, oppositePrimer: string): AdapterSpec =
  result.fivePrime = prepareAdapterEnd(fivePrime)
  result.threePrime = prepareAdapterEnd(reverseComplementAdapter(oppositePrimer))
  result.hasFivePrime = true
  result.hasThreePrime = true

proc addKnownAdapterSeed(index: var Table[string, seq[KnownAdapterSeed]],
                         sequence: string, seed: KnownAdapterSeed) =
  index.mgetOrPut(sequence, @[]).add(seed)

proc knownAdapterSeedIndex(): Table[string, seq[KnownAdapterSeed]] =
  ## Index exact and one-substitution 8-mers. With a 10% error rate, at least
  ## one such seed remains discoverable for any accepted 12+ base overlap.
  const bases = ['A', 'C', 'G', 'T']
  for adapterIndex, adapter in KNOWN_ADAPTERS:
    if adapter.sequence.len < KNOWN_ADAPTER_SEED_LENGTH:
      continue
    for offset in countup(0, adapter.sequence.len - KNOWN_ADAPTER_SEED_LENGTH,
                          KNOWN_ADAPTER_SEED_LENGTH):
      let seed = adapter.sequence[offset ..< offset + KNOWN_ADAPTER_SEED_LENGTH]
      result.addKnownAdapterSeed(seed,
        KnownAdapterSeed(adapterIndex: adapterIndex, offset: offset))
      for position in 0 ..< seed.len:
        for base in bases:
          if base == seed[position]:
            continue
          var variant = seed
          variant[position] = base
          result.addKnownAdapterSeed(variant,
            KnownAdapterSeed(adapterIndex: adapterIndex, offset: offset))

proc knownAdapterCandidate(sequence, adapter: string, startPos, minOverlap: int,
                           errorRate: float): tuple[matched: bool,
                                                    overlap, errors: int] =
  if startPos < 0 or startPos >= sequence.len:
    return
  result.overlap = min(adapter.len, sequence.len - startPos)
  if result.overlap < minOverlap:
    return
  for i in 0 ..< result.overlap:
    if sequence[startPos + i].toUpperAscii() != adapter[i]:
      inc result.errors
  result.matched = float(result.errors) <=
    float(result.overlap) * errorRate + 1.0e-12

proc detectKnownAdapter*(path: string, errorRate: float,
                         requestedOverlap: int): KnownAdapterDetection =
  ## Select one database adapter from a bounded input sample. Detection is a
  ## separate pass so trimming remains fast and deterministic for every read.
  if path == "-":
    raise newException(ValueError,
      "automatic known-adapter detection requires seekable input files; " &
      "stdin is not supported")
  let minOverlap = max(KNOWN_ADAPTER_MIN_OVERLAP, requestedOverlap)
  let seedIndex = knownAdapterSeedIndex()
  var counts = newSeq[int](KNOWN_ADAPTERS.len)
  var alignedBases = newSeq[int64](KNOWN_ADAPTERS.len)
  var errorCounts = newSeq[int64](KNOWN_ADAPTERS.len)
  var bestOverlap = newSeq[int](KNOWN_ADAPTERS.len)
  var bestErrors = newSeq[int](KNOWN_ADAPTERS.len)

  for record in readFQPtr(path):
    if record.qualityLen == 0:
      raise newException(ValueError, "adapters requires FASTQ input")
    if result.scannedReads >= KNOWN_ADAPTER_SCAN_READS or
        result.scannedBases >= KNOWN_ADAPTER_SCAN_BASES:
      break
    inc result.scannedReads
    result.scannedBases += record.sequenceLen
    let sequence = filterPtrString(record.sequence, record.sequenceLen)
    if sequence.len < minOverlap:
      continue
    var matchedAdapters: seq[int]
    var testedStarts = initHashSet[int]()
    for position in 0 .. sequence.len - KNOWN_ADAPTER_SEED_LENGTH:
      let seedText = sequence[position ..< position + KNOWN_ADAPTER_SEED_LENGTH]
        .toUpperAscii()
      if seedText notin seedIndex:
        continue
      for seed in seedIndex[seedText]:
        let startPos = position - seed.offset
        if startPos < 0:
          continue
        let startKey = seed.adapterIndex * (sequence.len + 1) + startPos
        if startKey in testedStarts:
          continue
        testedStarts.incl(startKey)
        let candidate = knownAdapterCandidate(sequence,
          KNOWN_ADAPTERS[seed.adapterIndex].sequence, startPos, minOverlap,
          errorRate)
        if not candidate.matched:
          continue
        if bestOverlap[seed.adapterIndex] == 0:
          matchedAdapters.add(seed.adapterIndex)
          bestOverlap[seed.adapterIndex] = candidate.overlap
          bestErrors[seed.adapterIndex] = candidate.errors
        elif candidate.overlap > bestOverlap[seed.adapterIndex] or
            (candidate.overlap == bestOverlap[seed.adapterIndex] and
             candidate.errors < bestErrors[seed.adapterIndex]):
          bestOverlap[seed.adapterIndex] = candidate.overlap
          bestErrors[seed.adapterIndex] = candidate.errors
    for adapterIndex in matchedAdapters:
      inc counts[adapterIndex]
      alignedBases[adapterIndex] += bestOverlap[adapterIndex]
      errorCounts[adapterIndex] += bestErrors[adapterIndex]
      bestOverlap[adapterIndex] = 0
      bestErrors[adapterIndex] = 0

  var best = -1
  for adapterIndex in 0 ..< KNOWN_ADAPTERS.len:
    if counts[adapterIndex] == 0:
      continue
    if best < 0 or counts[adapterIndex] > counts[best] or
        (counts[adapterIndex] == counts[best] and
         alignedBases[adapterIndex] > alignedBases[best]) or
        (counts[adapterIndex] == counts[best] and
         alignedBases[adapterIndex] == alignedBases[best] and
         errorCounts[adapterIndex] < errorCounts[best]) or
        (counts[adapterIndex] == counts[best] and
         alignedBases[adapterIndex] == alignedBases[best] and
         errorCounts[adapterIndex] == errorCounts[best] and
         KNOWN_ADAPTERS[adapterIndex].sequence.len <
           KNOWN_ADAPTERS[best].sequence.len):
      best = adapterIndex

  if best < 0:
    return
  let minimumHits = if result.scannedReads < 20: 1
                    else: max(2, int(ceil(float(result.scannedReads) / 200.0)))
  if counts[best] >= minimumHits:
    result.found = true
    result.adapter = KNOWN_ADAPTERS[best]
    result.hits = counts[best]

proc sliceAdapterRecord*(record: FQRecord, startPos, endPos: int): FQRecord =
  if startPos < 0 or endPos < startPos or endPos > record.sequence.len:
    raise newException(ValueError, "Invalid trim coordinates")
  result.name = record.name
  result.comment = record.comment
  if startPos < endPos:
    result.sequence = record.sequence[startPos ..< endPos]
    if record.quality.len > 0:
      if record.quality.len != record.sequence.len:
        raise newException(ValueError, "Sequence and quality lengths differ for " & record.name)
      result.quality = record.quality[startPos ..< endPos]

type AdapterCell = object
  cost, score: int

proc betterCell(candidate, current: AdapterCell): bool {.inline.} =
  candidate.cost < current.cost or
    (candidate.cost == current.cost and candidate.score > current.score)

proc adapterCompatible(mask: uint8, observed: char): bool {.inline.} =
  let observedMask = adapterBaseMask(observed)
  observedMask != 0 and (mask and observedMask) != 0

proc adapterAllowed(errors, overlap: int, rate: float): bool {.inline.} =
  overlap > 0 and float(errors) <= float(overlap) * rate + 1.0e-12

proc betterAdapterMatch(candidate, current: AdapterMatch): bool {.inline.} =
  not current.matched or candidate.score > current.score or
    (candidate.score == current.score and candidate.errors < current.errors) or
    (candidate.score == current.score and candidate.errors == current.errors and
      candidate.adapterStop - candidate.adapterStart >
        current.adapterStop - current.adapterStart) or
    (candidate.score == current.score and candidate.errors == current.errors and
      candidate.adapterStop - candidate.adapterStart ==
        current.adapterStop - current.adapterStart and
      candidate.readStart < current.readStart)

proc alignAdapterAt(sequence: string, startPos: int, adapter: AdapterEnd,
                    options: AdapterMatchOptions): AdapterMatch =
  let available = sequence.len - startPos
  if available <= 0:
    return
  let minOverlap = min(options.minOverlap, adapter.sequence.len)
  if minOverlap <= 0:
    return

  if not options.allowIndels:
    let overlap = min(adapter.sequence.len, available)
    if overlap < minOverlap or (overlap < adapter.sequence.len and available > overlap):
      return
    var errors = 0
    for i in 0 ..< overlap:
      if not adapterCompatible(adapter.masks[i], sequence[startPos + i]):
        inc errors
    if adapterAllowed(errors, overlap, options.errorRate):
      result = AdapterMatch(matched: true, adapterStart: 0, adapterStop: overlap,
        readStart: startPos, readStop: startPos + overlap,
        errors: errors, score: overlap - 2 * errors)
    return

  let maxErrors = int(floor(options.errorRate * float(adapter.sequence.len)))
  let maxRead = min(available, adapter.sequence.len + maxErrors)
  var matrix = newSeqWith(adapter.sequence.len + 1,
                          newSeq[AdapterCell](maxRead + 1))
  for i in 0 .. adapter.sequence.len:
    matrix[i][0] = AdapterCell(cost: i, score: -2 * i)
  for j in 0 .. maxRead:
    matrix[0][j] = AdapterCell(cost: j, score: -2 * j)

  for i in 1 .. adapter.sequence.len:
    for j in 1 .. maxRead:
      let compatible = adapterCompatible(adapter.masks[i - 1],
                                          sequence[startPos + j - 1])
      var best = matrix[i - 1][j - 1]
      if compatible:
        inc best.score
      else:
        inc best.cost
        dec best.score
      var deletion = matrix[i - 1][j]
      inc deletion.cost
      deletion.score -= 2
      if betterCell(deletion, best):
        best = deletion
      var insertion = matrix[i][j - 1]
      inc insertion.cost
      insertion.score -= 2
      if betterCell(insertion, best):
        best = insertion
      matrix[i][j] = best

  for readLength in 1 .. maxRead:
    let cell = matrix[adapter.sequence.len][readLength]
    if adapterAllowed(cell.cost, adapter.sequence.len, options.errorRate):
      let candidate = AdapterMatch(matched: true, adapterStart: 0,
        adapterStop: adapter.sequence.len, readStart: startPos,
        readStop: startPos + readLength, errors: cell.cost, score: cell.score)
      if betterAdapterMatch(candidate, result):
        result = candidate

  if maxRead == available:
    for adapterLength in minOverlap ..< adapter.sequence.len:
      let cell = matrix[adapterLength][maxRead]
      if adapterAllowed(cell.cost, adapterLength, options.errorRate):
        let candidate = AdapterMatch(matched: true, adapterStart: 0,
          adapterStop: adapterLength, readStart: startPos,
          readStop: startPos + maxRead, errors: cell.cost, score: cell.score)
        if betterAdapterMatch(candidate, result):
          result = candidate

proc findFivePrimeAdapter*(sequence: string, adapter: AdapterEnd,
                           options: AdapterMatchOptions): AdapterMatch =
  alignAdapterAt(sequence, 0, adapter, options)

proc findThreePrimeAdapter*(sequence: string, adapter: AdapterEnd,
                            searchStart: int,
                            options: AdapterMatchOptions): AdapterMatch =
  let minimum = min(options.minOverlap, adapter.sequence.len)
  if sequence.len - searchStart < minimum:
    return
  for startPos in searchStart .. sequence.len - minimum:
    let candidate = alignAdapterAt(sequence, startPos, adapter, options)
    if candidate.matched and betterAdapterMatch(candidate, result):
      result = candidate

proc trimAdapterRecord*(record: FQRecord, spec: AdapterSpec,
                        options: AdapterMatchOptions): AdapterTrimResult =
  result.trimStart = 0
  result.trimEnd = record.sequence.len
  result.record = record

  if spec.hasFivePrime:
    let fiveMatch = findFivePrimeAdapter(record.sequence, spec.fivePrime, options)
    if not fiveMatch.matched:
      result.discardReason = adrMissingFivePrime
      return
    result.matchedFivePrime = true
    result.trimStart = fiveMatch.readStop

  if spec.hasThreePrime:
    let threeMatch = findThreePrimeAdapter(record.sequence, spec.threePrime,
                                           result.trimStart, options)
    if threeMatch.matched:
      result.matchedThreePrime = true
      result.trimEnd = threeMatch.readStart
    elif not spec.hasFivePrime:
      result.discardReason = adrMissingThreePrime
      return

  if result.trimEnd < result.trimStart:
    result.trimEnd = result.trimStart
  result.record = sliceAdapterRecord(record, result.trimStart, result.trimEnd)
  if result.record.sequence.len == 0:
    result.discardReason = adrEmptyInsert

proc adapterSpecMatched*(trimResult: AdapterTrimResult, spec: AdapterSpec): bool {.inline.} =
  if spec.hasFivePrime: trimResult.matchedFivePrime
  elif spec.hasThreePrime: trimResult.matchedThreePrime
  else: true

proc processAdapterBatch*(batch: ptr AdapterBatch,
                          worker: ptr AdapterWorkerOptions) {.gcsafe.} =
  batch[].resultsFirst = newSeq[AdapterTrimResult](batch[].first.len)
  if batch[].paired:
    batch[].resultsSecond = newSeq[AdapterTrimResult](batch[].second.len)
  for i in 0 ..< batch[].first.len:
    if worker[].hasFirstSpec:
      batch[].resultsFirst[i] = trimAdapterRecord(batch[].first[i],
        worker[].firstSpec, worker[].matchOptions)
    else:
      batch[].resultsFirst[i] = AdapterTrimResult(
        trimEnd: batch[].first[i].sequence.len,
        record: batch[].first[i])
    if batch[].paired:
      if worker[].hasSecondSpec:
        batch[].resultsSecond[i] = trimAdapterRecord(batch[].second[i],
          worker[].secondSpec, worker[].matchOptions)
      else:
        batch[].resultsSecond[i] = AdapterTrimResult(
          trimEnd: batch[].second[i].sequence.len,
          record: batch[].second[i])

proc runAdapterWorkers*(batches: var seq[AdapterBatch],
                        worker: var AdapterWorkerOptions, threads: int) =
  if batches.len == 0:
    return
  if threads > 1 and batches.len > 1:
    var master = createMaster()
    master.awaitAll:
      for i in 0 ..< batches.len:
        master.spawn processAdapterBatch(addr batches[i], addr worker)
  else:
    for i in 0 ..< batches.len:
      processAdapterBatch(addr batches[i], addr worker)

proc updateAdapterStats*(stats: var AdapterStats, trimResult: AdapterTrimResult) =
  if trimResult.matchedFivePrime:
    inc stats.trimmedFivePrime
  if trimResult.matchedThreePrime:
    inc stats.trimmedThreePrime

proc writeAdapterResult*(writer: var FastxWriter,
                         trimResult: AdapterTrimResult) =
  writeFilterRecord(writer, trimResult.record)
