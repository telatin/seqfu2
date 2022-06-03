import sequtils
import tables
import readfq
import algorithm
## Seqfu Stats

type
  FastxStats*   = tuple[filename: string, count, sum, min, max, n25, n50, n75, n90: int, auN, avg: float]

proc toTable*(s: FastxStats): Table[string, string] =
  result["Filename"] = s.filename
  result["Total"] = $s.sum
  result["Count"] = $s.count
  result["Min"] = $s.min
  result["Max"] = $s.max
  result["N25"] = $s.n25
  result["N50"] = $s.n50
  result["N75"] = $s.n75
  result["N90"] = $s.n90
  result["Avg"] = $s.avg
  result["AuN"] = $s.auN

proc getFastxStats*(filename: string): FastxStats {.discardable.} =
  result.filename = filename
  var
    totalBases = 0
    nseq  = 0
    ctgSizes = initOrderedTable[int, int]()

    accum = 0
    auN    : float
    i      = 0

  try:
    for r in readfq(filename):
      var ctgLen = len(r.sequence)
      if not (ctgLen in ctgSizes):
        ctgSizes[ctgLen] = 1
      else:
        ctgSizes[ctgLen]+=1
      totalBases += ctgLen
      nseq  += 1
  except Exception as e:
    stderr.writeLine("Warning: ignoring file ", filename, ": ", e.msg)
    return

  if totalBases == 0:
    stderr.writeLine("Warning: file <", filename, "> is empty or malformed.")
    return 
  result.sum = totalBases

  var
    ctgSizesKeys  = toSeq(keys(ctgSizes))

  sort(ctgSizesKeys, proc(a, b: int): int =
      if a < b: return -1
      else: return 1
  )
  result.max = ctgSizesKeys[^1]
  result.min = ctgSizesKeys[0]
  result.auN = 0.0
  # calculate thresholds
  #for index in nIndexes:
  #  let quote = float(total) * float((100 - index) / 100)

  for ctgLen in ctgSizesKeys:

    let
      count = ctgSizes[ctgLen]
      ctgLengths = (ctgLen * count)

    i += 1
    accum += ctgLengths
    auN += float( ctgLen * ctgLen / totalBases);

    if (result.n25 == 0)  and (float(accum) >=  float( totalBases)  * float((100 - 25) / 100) )  :
      result.n25 = ctgLen
    if (result.n50 == 0)  and (float(accum) >=  float( totalBases)  * float((100 - 50) / 100) )  :
      result.n50 = ctgLen
    if (result.n75 == 0)  and (float(accum) >=  float( totalBases)  * float((100 - 75) / 100) )  :
      result.n75 = ctgLen
    if (result.n90 == 0)  and (float(accum) >=  float( totalBases)  * float((100 - 90) / 100) )  :
      result.n90 = ctgLen


  result.auN = auN
  result.count = nseq

  result.avg   =float( totalBases / nseq )

