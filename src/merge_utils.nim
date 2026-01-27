import std/math
import std/algorithm
import klib
import readfq
import ./seqfu_utils

type
  Word = uint32
  HSPData* = object
    loi*, loj*: int     
    leni*, lenj*: int   
    score*: float32     
    user*: int         

type
  MergeParams* = object
    wordLength*: int     
    minOverlap*: int    
    minIdentity*: int    # Changed to int (percentage 0-100)
    matchScore*: float32
    mismatchScore*: float32
    gapOpen*: float32
    gapExtend*: float32
 

const
  MaxReps = 8  
  DefaultWordLength = 11  
  AlphaSize = 4   

const CharToLetter = block:
  var tmp: array[char, uint8]
  for c in tmp.mitems: c = 0'u8
  
  tmp['A'] = 0'u8; tmp['a'] = 0'u8
  tmp['C'] = 1'u8; tmp['c'] = 1'u8
  tmp['G'] = 2'u8; tmp['g'] = 2'u8
  tmp['T'] = 3'u8; tmp['t'] = 3'u8
  tmp['N'] = 0'u8; tmp['n'] = 0'u8
  tmp


proc seqToWords(seq: string, wordLen: int): seq[Word] =
  ## Convert sequence to k-mers using the rolling hash approach
  result = newSeq[Word]()
  if len(seq) < wordLen:
    return
  
  var word: Word = 0
  # Initialize first word
  for i in 0 ..< (wordLen-1):
    let base = CharToLetter[seq[i]]
    # Use only 2 bits per base (since we have 4 possibilities)
    word = (word shl 2) or Word(base)

  # Roll through sequence
  for i in (wordLen-1) ..< len(seq):
    let base = CharToLetter[seq[i]]
    # Remove leftmost base (2 bits) and add new base
    word = ((word shl 2) and ((1'u32 shl (2*wordLen))-1'u32)) or Word(base)
    result.add(word)
 
proc compareHSPs(x, y: (int, int)): int =
  let diag1 = x[0] - x[1]
  let diag2 = y[0] - y[1]
  if diag1 < diag2: -1
  elif diag1 > diag2: 1
  else: 0

proc findHSPs*(seq1, seq2: string, params: MergeParams): seq[HSPData] =
  result = newSeq[HSPData]()
  
  # Safety check for input sequences
  if seq1.len < params.wordLength or seq2.len < params.wordLength:
    #stderr.writeLine("[DEBUG] Sequences too short for word length: ", params.wordLength)
    return
  
  let words1 = seqToWords(seq1, params.wordLength)
  let words2 = seqToWords(seq2, params.wordLength)

  #stderr.writeLine("[DEBUG] Words found in seq1: ", words1.len)
  #stderr.writeLine("[DEBUG] Words found in seq2: ", words2.len)
  #stderr.writeLine("[DEBUG] First few words from seq1: ", words1[0..min(5, words1.len-1)])

  if words1.len == 0 or words2.len == 0:
    #stderr.writeLine("[DEBUG] No words found in one or both sequences")
    return

  # Calculate k-mer space and ensure it's reasonable
  let kmerSpace = 1 shl (2*params.wordLength)
  #stderr.writeLine("[DEBUG] K-mer space size: ", kmerSpace)

  var wordCounts = newSeq[int](kmerSpace)
  var wordPositions = newSeq[seq[int]](kmerSpace)
  
  # Process words from first sequence
  var totalPositions = 0
  for i, word in words1:
    let wordIdx = int(word)
    if wordIdx >= kmerSpace:
      #stderr.writeLine("[DEBUG] Word index ", wordIdx, " exceeds k-mer space")
      continue
    if wordCounts[wordIdx] < MaxReps:
      wordPositions[wordIdx].add(i)
      inc wordCounts[wordIdx]
      inc totalPositions

  #stderr.writeLine("[DEBUG] Total positions stored: ", totalPositions)
  
  # Find matching positions
  var matches = newSeq[(int, int)]()
  for i, word in words2:
    let wordIdx = int(word)
    if wordIdx >= kmerSpace:
      continue
    if wordCounts[wordIdx] > 0:
      for pos1 in wordPositions[wordIdx]:
        matches.add((pos1, i))

  #stderr.writeLine("[DEBUG] Matches found: ", matches.len)
  #if matches.len > 0:
    #stderr.writeLine("[DEBUG] First match: pos1=", matches[0][0], " pos2=", matches[0][1])

  # Need at least one match
  if matches.len == 0:
    #stderr.writeLine("[DEBUG] No matches found")
    return

  # Sort by diagonal
  matches.sort(compareHSPs)

  # Process matches to find HSPs
  var i = 0
  var hspsFound = 0
  while i < matches.len:
    var j = i + 1
    let baseDiag = matches[i][0] - matches[i][1]
    
    while j < matches.len and matches[j][0] - matches[j][1] == baseDiag:
      inc j

    # Extend match region
    var 
      start1 = matches[i][0]
      start2 = matches[i][1]
      extendLen = 0
      score = 0'f32
    
    if start1 >= seq1.len or start2 >= seq2.len:
      i = j
      continue

    # Debug current match being processed
    #stderr.writeLine("[DEBUG] Processing match at positions ", start1, ",", start2)

    # Extend left
    var p1 = start1
    var p2 = start2
    var leftExtension = 0
    while p1 > 0 and p2 > 0:
      if p1-1 >= seq1.len or p2-1 >= seq2.len:
        break
      if seq1[p1-1] != seq2[p2-1]: break
      dec p1
      dec p2
      inc extendLen
      inc leftExtension
      score += params.matchScore

    #stderr.writeLine("[DEBUG] Left extension: ", leftExtension, " bases")

    # Extend right
    p1 = start1 + params.wordLength
    p2 = start2 + params.wordLength
    var rightExtension = 0
    while p1 < seq1.len and p2 < seq2.len:
      if seq1[p1] != seq2[p2]: break 
      inc p1
      inc p2
      inc extendLen
      inc rightExtension
      score += params.matchScore

    #stderr.writeLine("[DEBUG] Right extension: ", rightExtension, " bases")
    #stderr.writeLine("[DEBUG] Total extension: ", extendLen, " bases")
    #stderr.writeLine("[DEBUG] Score: ", score)

    # Add HSP if meets criteria
    if extendLen >= params.minOverlap:
      inc hspsFound
      result.add HSPData(
        loi: p1,
        loj: p2, 
        leni: extendLen,
        lenj: extendLen,
        score: score
      )
      #stderr.writeLine("[DEBUG] HSP added with length ", extendLen)

    i = j

  #stderr.writeLine("[DEBUG] Total HSPs found: ", hspsFound)

proc mergeSeqs*(seq1, seq2: string, qual1, qual2: string, 
                params: MergeParams): FastxRecord =
  # Initialize with empty/default values
  result = (seq: "", qual: "", name: "", comment: "", status: 0, lastChar: 0)
  
  # Safety checks
  if seq1.len == 0 or seq2.len == 0:
    return
  if qual1.len != seq1.len or qual2.len != seq2.len:
    return

  let hsps = findHSPs(seq1, seq2, params)
 
  if hsps.len == 0:
    return

  # Find best scoring HSP
  var bestScore = -Inf
  var bestHspIndex = -1
  for i, hsp in hsps:
    if hsp.score > bestScore:
      bestScore = hsp.score
      bestHspIndex = i

  if bestHspIndex == -1:
    return

  let bestHsp = hsps[bestHspIndex]

  # Calculate overlap identity
  let
    overlapLen = bestHsp.leni
    overlapIdentity = (bestHsp.score / (params.matchScore * float32(overlapLen))) * 100.0

  if overlapIdentity < float32(params.minIdentity):
    return

  # Bounds checks for merging
  if bestHsp.loi >= seq1.len or bestHsp.loj >= seq2.len:
    return
  if bestHsp.loi + overlapLen > seq1.len or bestHsp.loj + overlapLen > seq2.len:
    return

  # Create merged sequence safely
  try:
    # Copy sequence parts
    let
      prefix = seq1[0 ..< bestHsp.loi]
      overlap = seq1[bestHsp.loi ..< bestHsp.loi + overlapLen]
      suffix = seq2[bestHsp.loj + overlapLen .. ^1]

    result.seq = prefix & overlap & suffix

    # Handle quality scores
    if qual1.len > 0 and qual2.len > 0:
      let
        prefixQual = qual1[0 ..< bestHsp.loi]
        suffixQual = qual2[bestHsp.loj + overlapLen .. ^1]
      
      var mergedQual = prefixQual
      
      # Merge overlap qualities
      for i in 0 ..< overlapLen:
        if bestHsp.loi + i < qual1.len and bestHsp.loj + i < qual2.len:
          mergedQual.add(max(
            qual1[bestHsp.loi + i],
            qual2[bestHsp.loj + i]
          ))
      
      mergedQual.add(suffixQual)
      result.qual = mergedQual
  except:
    result = (seq: "", qual: "", name: "", comment: "", status: 0, lastChar: 0)
proc fxToString*(r: FastxRecord): string =
  ## Convert FastxRecord to FASTX format string
  if r.qual.len > 0:
    # FASTQ format: @name comment\nsequence\n+\nquality\n
    result = "@" & r.name
    if r.comment.len > 0:
      result.add " " & r.comment
    result.add "\n"
    result.add r.seq & "\n"
    result.add "+\n"
    result.add r.qual & "\n"
  else:
    # FASTA format: >name comment\nsequence\n
    result = ">" & r.name
    if r.comment.len > 0:
      result.add " " & r.comment
    result.add "\n"
    result.add r.seq & "\n"