import os
import klib
import ./seqfu_utils
import strutils

type
  QualityStrategy = enum
    qsFirst,      # Use quality from first read
    qsLowest,     # Use lowest quality score
    qsHighest,    # Use highest quality score
    qsRecalculate # Recalculate qualities based on matches

type
  MergeOptions = object
    minOverlap: int           # Minimum overlap length
    minIdentity: float        # Minimum identity in overlap region
    acceptedIdentity: float   # Identity threshold to accept immediately
    qualityMethod: QualityStrategy
    keepUnmerged: bool        # Keep unmerged reads (output R1)
    minResultLength: int      # Minimum length of merged sequence
    maxResultLength: int      # Maximum length of merged sequence

type
  MergeResult = object
    success: bool             # Whether merge was successful
    record: FastxRecord       # The resulting record
    overlapLength: int        # Length of overlap
    identity: float          # Identity in overlap region
    message: string          # Any error/warning messages

proc mergeQuality(q1, q2: string, strategy: QualityStrategy): string =
  ## Merge quality scores according to selected strategy
  result = newString(len(q1))
  for i in 0..<len(q1):
    let
      qual1 = charToQual(q1[i])
      qual2 = charToQual(q2[i])
    
    case strategy:
      of qsFirst:
        result[i] = q1[i]
      of qsLowest:
        result[i] = qualToChar(min(qual1, qual2))
      of qsHighest:
        result[i] = qualToChar(max(qual1, qual2))
      of qsRecalculate:
        # Add 2 to quality if bases match, subtract 2 if they mismatch
        let adjQual = if q1[i] == q2[i]: min(qual1 + 2, 40)
                     else: max(qual1 - 2, 0)
        result[i] = qualToChar(adjQual)

proc findBestOverlap(r1seq, r2seq: string, minOverlap: int, minIdentity: float): tuple[pos: int, identity: float] =
  ## Find the best overlap between sequences
  ## Returns: (pos: overlap length, identity: match ratio)
  result = (pos: -1, identity: 0.0)
  
  # Try each possible overlap position
  for i in countdown(min(len(r1seq), len(r2seq)), minOverlap):
    let
      s1 = r1seq[len(r1seq)-i .. len(r1seq)-1] # End of R1
      s2 = r2seq[0 .. i-1]                      # Start of R2
    
    if len(s1) != len(s2):
      continue
      
    var matches = 0
    for j in 0..<len(s1):
      if s1[j] == s2[j]:
        matches += 1
    
    let identity = matches.float / float(len(s1))
    
    # Update if this is the best match so far
    if identity > result.identity:
      result = (pos: i, identity: identity)
      if identity >= 0.95: # Early exit for very good matches
        return result

  # If we found a good enough match, return it
  if result.identity >= minIdentity:
    return result
  
  # Otherwise indicate no valid overlap found
  result = (pos: -1, identity: 0.0)

proc mergeReads(r1, r2: FastxRecord, opts: MergeOptions): MergeResult =
  ## Merge paired-end reads with overlap detection
  result.success = false
  
  # Validate input reads
  if r1.seq.len == 0 or r2.seq.len == 0:
    result.message = "Empty sequence found"
    return
  
  if r1.qual.len != r1.seq.len or r2.qual.len != r2.seq.len:
    result.message = "Quality length mismatch"
    return
    
  # Get reverse complement of R2
  let rc2 = revcompl(r2)
  
  # Find best overlap
  let overlap = findBestOverlap(r1.seq, rc2.seq, opts.minOverlap, opts.minIdentity)
  
  if overlap.pos == -1:
    if opts.keepUnmerged:
      result.record = r1
      result.message = "No valid overlap found"
    else:
      result.message = "Failed to merge: no valid overlap"
    return
    
  if overlap.identity < opts.minIdentity:
    if opts.keepUnmerged:
      result.record = r1
      result.message = "Overlap identity too low"
    else:
      result.message = "Failed to merge: low overlap identity"
    return
  
  # Construct merged sequence
  let
    mergedSeq = r1.seq & rc2.seq[overlap.pos..^1]
    mergedQual = if opts.qualityMethod == qsFirst: r1.qual & rc2.qual[overlap.pos..^1]
                 else: mergeQuality(r1.qual, rc2.qual[overlap.pos..^1], opts.qualityMethod)
  
  # Length validation
  if len(mergedSeq) < opts.minResultLength:
    result.message = "Merged sequence too short"
    return
  
  if len(mergedSeq) > opts.maxResultLength:
    result.message = "Merged sequence too long"
    return
  
  # Construct result
  result.success = true
  # Create the merged record matching FastxRecord tuple definition
  result.record = (
    seq: mergedSeq,
    qual: mergedQual,
    name: r1.name,
    comment: r1.comment & ";overlap=" & $overlap.pos & ";identity=" & $overlap.identity,
    status: mergedSeq.len,
    lastChar: 0
  )
  result.overlapLength = overlap.pos
  result.identity = overlap.identity

proc fastq_merge*(argv: var seq[string]): int =
  let args = docopt("""
Usage:
  merge [options] -1 FILE_R1 [-2 FILE_R2]
  merge [options] FILE_R1

Options:
  -1, --R1 FILE              First paired-end file
  -2, --R2 FILE              Second paired-end file (can be auto-inferred)
  
Merging options:
  -i, --min-id FLOAT         Minimum overlap identity [default: 0.90]
  -m, --min-overlap INT      Minimum overlap length [default: 20]
  --accept-id FLOAT          Accept overlap when identity exceeds [default: 0.97]
  --min-length INT           Minimum length of merged sequence [default: 30]
  --max-length INT           Maximum length of merged sequence [default: 1000]
  --keep-unmerged           Output R1 when merging fails [default: false]
  
Quality options:
  --qual-method STR         Quality handling strategy [default: first]
                           (first/lowest/highest/recalculate)
  
Other options:
  -v, --verbose             Print verbose messages
  -h, --help               Show this help
""", version=version(), argv=argv)

  # Parse options
  var opts = MergeOptions(
    minOverlap: parseInt($args["--min-overlap"]),
    minIdentity: parseFloat($args["--min-id"]),
    acceptedIdentity: parseFloat($args["--accept-id"]),
    keepUnmerged: args["--keep-unmerged"],
    minResultLength: parseInt($args["--min-length"]),
    maxResultLength: parseInt($args["--max-length"])
  )

  # Set quality method
  case $args["--qual-method"]
  of "first": opts.qualityMethod = qsFirst
  of "lowest": opts.qualityMethod = qsLowest
  of "highest": opts.qualityMethod = qsHighest
  of "recalculate": opts.qualityMethod = qsRecalculate
  else:
    stderr.writeLine("Invalid quality method: ", $args["--qual-method"])
    return 1

  # Get input files
  let
    file_R1 = $args["--R1"]
    file_R2 = if $args["--R2"] != "nil": $args["--R2"]
              else: guessR2(file_R1, "auto", "auto", true)

  # Validate input files
  if not fileExists(file_R1):
    stderr.writeLine("ERROR: Unable to find R1 file: ", file_R1)
    return 1

  if file_R2 == "":
    stderr.writeLine("ERROR: Unable to guess R2 filename")
    return 1

  if not fileExists(file_R2):
    stderr.writeLine("ERROR: Unable to find R2 file: ", file_R2)
    return 1

  # Open input files
  var
    r1 = xopen[GzFile](file_R1)
    r2 = xopen[GzFile](file_R2)
  defer:
    r1.close()
    r2.close()

  var
    read1, read2: FastxRecord
    pairNum = 0
    mergedCount = 0
    failedCount = 0

  # Process reads
  while r1.readFastx(read1):
    if not r2.readFastx(read2):
      stderr.writeLine("ERROR: R2 file ended before R1")
      return 1
    
    pairNum += 1
    
    # Verify read names match
    let
      name1 = read1.name.split(" ")[0]
      name2 = read2.name.split(" ")[0]
    
    if name1 != name2:
      stderr.writeLine("WARNING: Read names don't match at pair ", pairNum)
      stderr.writeLine("R1: ", name1)
      stderr.writeLine("R2: ", name2)
      continue

    # Attempt merge
    let result = mergeReads(read1, read2, opts)
    
    if result.success:
      echo printFastxRecord(result.record)
      mergedCount += 1
    else:
      if opts.keepUnmerged:
        echo printFastxRecord(result.record)
      failedCount += 1

  if args["--verbose"]:
    stderr.writeLine("Processed ", pairNum, " pairs")
    stderr.writeLine("Successfully merged: ", mergedCount)
    stderr.writeLine("Failed to merge: ", failedCount)

  return 0