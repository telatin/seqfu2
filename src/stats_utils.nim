import sequtils
import tables
import readfq
import algorithm
import seqfu_utils
## Seqfu Stats

type
  FastxStats*   = tuple[filename: string, count, sum, min, max, n25, n50, n75, n90, l50, l75, l90: int, gc, auN, avg: float]

type
  statsOptions* = tuple[
    absolute: bool,
    basename: bool,
    precision: int,
    thousands: bool,
    header: bool, 
    gc: bool, 
    index: bool,
    scaffolds: bool, 
    delim: string, 
    fields: seq[string]
  ]

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
  result["gc"] = $s.gc
  result["L50"] = $s.l50
  result["L75"] = $s.l75
  result["L90"] = $s.l90



proc getFastxStats*(filename: string, o: statsOptions): FastxStats {.discardable.} =
  result.filename = filename
  var
    totalBases = 0
    nseq  = 0
    ctgSizes = initOrderedTable[int, int]()
    gc = 0
    realLen = 0
    accum = 0
    auN    : float
    sumSquaredLengths: float = 0.0 
    ctgIndex = 0
    ctgAccumLen   = 0

  try:
    for r in readfq(filename):
      var ctgLen = len(r.sequence)

      ## Only calculate %GC if requested
      if o.gc:
        let nucleotides = count_all(r.sequence)
        gc += nucleotides.gc
        realLen += nucleotides.tot


      if not (ctgLen in ctgSizes):
        ctgSizes[ctgLen] = 1
      else:
        ctgSizes[ctgLen]+=1
      totalBases += ctgLen
      sumSquaredLengths += float(ctgLen * ctgLen) 
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
      if a > b: return -1
      else: return 1
  )

  result.max = ctgSizesKeys[0]
  result.min = ctgSizesKeys[^1]
  result.auN = 0.0
  result.gc = float(gc) / float(realLen)
  var 
    cumulativeLength = 0
    
  for ctgLen in ctgSizesKeys:

    let
      count = ctgSizes[ctgLen]
    

    for i in 0 ..< count:
      ctgIndex += 1
      ctgAccumLen += ctgLen

      if  (result.l50 == 0)  and (float(ctgAccumLen) >=  ( float( totalBases)  * float(50 / 100) )  ):
        result.l50 = ctgIndex
      if  (result.l75 == 0)  and (float(ctgAccumLen) >=  ( float( totalBases)  * float(75 / 100) )  ):
        result.l75 = ctgIndex
      if  (result.l90 == 0)  and (float(ctgAccumLen) >=  ( float( totalBases)  * float(90 / 100) )  ):
        result.l90 = ctgIndex

    cumulativeLength += ctgLen * count
   
  
    auN += float( ctgLen * count); 
 
    if (result.n25 == 0)  and (float(cumulativeLength) >=  float( totalBases)  * float(25 / 100) )  :
      result.n25 = ctgLen
    if (result.n50 == 0)  and (float(cumulativeLength) >=  float( totalBases)  * float(50 / 100) )  :
      result.n50 = ctgLen
    if (result.n75 == 0)  and (float(cumulativeLength) >=  float( totalBases)  * float(75 / 100) )  :
      result.n75 = ctgLen
    if (result.n90 == 0)  and (float(cumulativeLength) >=  float( totalBases)  * float(90 / 100) )  :
      result.n90 = ctgLen


  result.auN = sumSquaredLengths / float(totalBases)
  result.count = nseq


  result.avg   =float( totalBases / nseq )