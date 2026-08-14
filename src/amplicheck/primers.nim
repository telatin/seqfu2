import math
import strutils
import tables

import ../seqfu_utils
import ./types

const primerDbRaw = staticRead("../data/primers_db.tsv")

type
  PrimerRecord* = object
    name*, aliases*, sequence*, direction*: string
    targetDomain*, region*, citation*: string

  PrefixAccumulator = object
    totalReads: int
    counts: seq[array[5, int]]

  PrimerAccumulator* = object
    db: seq[PrimerRecord]
    observed: int
    r1Prefix, r2Prefix: PrefixAccumulator
    r1Hits, r2Hits: CountTable[string]
    r1Scores, r2Scores: Table[string, float]

  PrimerMatch = object
    found: bool
    name: string
    score: float

proc parsePrimerDb*(): seq[PrimerRecord] =
  var lineNo = 0
  for rawLine in primerDbRaw.splitLines:
    let line = rawLine.strip()
    if line.len == 0:
      continue
    lineNo += 1
    if lineNo == 1:
      continue

    let fields = rawLine.split('\t')
    if fields.len < 8:
      continue
    result.add(PrimerRecord(
      name: fields[0],
      aliases: fields[1],
      sequence: fields[2].toUpperAscii(),
      direction: fields[3].toLowerAscii(),
      targetDomain: fields[4],
      region: fields[5],
      citation: fields[7]
    ))

proc initPrimerAccumulator*(): PrimerAccumulator =
  result.db = parsePrimerDb()
  result.r1Hits = initCountTable[string]()
  result.r2Hits = initCountTable[string]()
  result.r1Scores = initTable[string, float]()
  result.r2Scores = initTable[string, float]()

proc baseIndex(c: char): int =
  case toUpperAscii(c)
  of 'A': 0
  of 'C': 1
  of 'G': 2
  of 'T', 'U': 3
  else: 4

proc addPrefix(acc: var PrefixAccumulator, sequence: string, maxLen = 30) =
  acc.totalReads += 1
  let usable = min(maxLen, sequence.len)
  if acc.counts.len < usable:
    acc.counts.setLen(usable)
  for i in 0 ..< usable:
    acc.counts[i][baseIndex(sequence[i])] += 1

proc iupacFromSeen(seen: set[char]): char =
  if seen == {'A'}: 'A'
  elif seen == {'C'}: 'C'
  elif seen == {'G'}: 'G'
  elif seen == {'T'}: 'T'
  elif seen == {'A', 'C'}: 'M'
  elif seen == {'A', 'G'}: 'R'
  elif seen == {'A', 'T'}: 'W'
  elif seen == {'C', 'G'}: 'S'
  elif seen == {'C', 'T'}: 'Y'
  elif seen == {'G', 'T'}: 'K'
  elif seen == {'A', 'C', 'G'}: 'V'
  elif seen == {'A', 'C', 'T'}: 'H'
  elif seen == {'A', 'G', 'T'}: 'D'
  elif seen == {'C', 'G', 'T'}: 'B'
  else: 'N'

proc consensus(acc: PrefixAccumulator): string =
  const bases = ['A', 'C', 'G', 'T']
  for posCounts in acc.counts:
    var total = 0
    var best = 0
    for i in 0 .. 3:
      total += posCounts[i]
      if posCounts[i] > best:
        best = posCounts[i]
    if total == 0:
      break

    var seen: set[char] = {}
    for i in 0 .. 3:
      if posCounts[i] > 0 and float(posCounts[i]) / float(total) >= 0.10:
        seen.incl(bases[i])

    if seen.card == 0:
      break
    result.add(iupacFromSeen(seen))

proc primerScore(readSeq, primer: string, minFraction = 0.60): float =
  if readSeq.len == 0 or primer.len == 0:
    return 0.0

  let
    query = readSeq.toUpperAscii()
    target = primer.toUpperAscii()
    compared = min(query.len, target.len)
    required = max(1, int(ceil(minFraction * float(target.len))))

  if compared < required:
    return 0.0

  var matches = 0
  for i in 0 ..< compared:
    if matchIUPAC(target[i], query[i]):
      matches += 1

  result = float(matches) / float(target.len)

proc bestPrimer(readSeq: string, db: seq[PrimerRecord]): PrimerMatch =
  for primer in db:
    let score = primerScore(readSeq, primer.sequence)
    if score >= 0.60:
      if not result.found or score > result.score:
        result.found = true
        result.name = primer.name
        result.score = score

proc recordByName(db: seq[PrimerRecord], name: string): PrimerRecord =
  for primer in db:
    if primer.name == name:
      return primer

proc addHit(hits: var CountTable[string], scores: var Table[string, float],
            hit: PrimerMatch) =
  if not hit.found:
    return
  hits.inc(hit.name)
  scores[hit.name] = scores.getOrDefault(hit.name, 0.0) + hit.score

proc addPrimerPair*(acc: var PrimerAccumulator, r1seq, r2seq: string) =
  acc.observed += 1
  acc.r1Prefix.addPrefix(r1seq)
  acc.r2Prefix.addPrefix(r2seq)
  acc.r1Hits.addHit(acc.r1Scores, bestPrimer(r1seq, acc.db))
  acc.r2Hits.addHit(acc.r2Scores, bestPrimer(r2seq, acc.db))

proc topHit(hits: CountTable[string]): tuple[name: string, count: int] =
  for name, count in hits.pairs:
    if count > result.count:
      result.name = name
      result.count = count

proc summarizeSide(acc: PrimerAccumulator, hits: CountTable[string],
                   scores: Table[string, float],
                   prefix: PrefixAccumulator): PrimerSideSummary =
  let top = topHit(hits)
  result.consensus = consensus(prefix)
  if top.count > 0:
    let primer = recordByName(acc.db, top.name)
    result.detected = true
    result.label = primer.name
    result.primer = primer.sequence
    result.direction = primer.direction
    result.targetDomain = primer.targetDomain
    result.region = primer.region
    result.citation = primer.citation
    result.supportCount = top.count
    if acc.observed > 0:
      result.supportFraction = float(top.count) / float(acc.observed)
    result.score = scores.getOrDefault(top.name, 0.0) / float(top.count)
  elif result.consensus.len >= 8:
    result.detected = true
    result.primer = result.consensus
    result.direction = "unknown"
    result.supportCount = prefix.totalReads
    if acc.observed > 0:
      result.supportFraction = 1.0

proc summarize*(acc: PrimerAccumulator): PrimerSummary =
  result.r1 = summarizeSide(acc, acc.r1Hits, acc.r1Scores, acc.r1Prefix)
  result.r2 = summarizeSide(acc, acc.r2Hits, acc.r2Scores, acc.r2Prefix)
  result.detected = result.r1.detected or result.r2.detected
  result.orientationConsistent =
    result.r1.direction == "forward" and result.r2.direction == "reverse"

  if result.r1.direction == "forward":
    result.fwdPrimer = result.r1.primer
    result.fwdLabel = result.r1.label
  elif result.r2.direction == "forward":
    result.fwdPrimer = result.r2.primer
    result.fwdLabel = result.r2.label
  else:
    result.fwdPrimer = result.r1.primer
    result.fwdLabel = result.r1.label

  if result.r2.direction == "reverse":
    result.revPrimer = result.r2.primer
    result.revLabel = result.r2.label
  elif result.r1.direction == "reverse":
    result.revPrimer = result.r1.primer
    result.revLabel = result.r1.label
  else:
    result.revPrimer = result.r2.primer
    result.revLabel = result.r2.label
