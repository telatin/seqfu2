import readfq
import tables, strutils, strformat, algorithm
from os import fileExists, getEnv, sleep
import docopt
import ./seqfu_utils
import illwill

# Type definitions
type
  Theme = object
    name: string
    barFg, barBg: illwill.ForegroundColor
    defaultFg, defaultBg: illwill.ForegroundColor
    seqNameFg, seqCommentFg: illwill.ForegroundColor
    coloredA, coloredC, coloredG, coloredT, coloredN: illwill.ForegroundColor
    qualColors: array[8, illwill.ForegroundColor]
    oligoMatch1Bg, oligoMatch2Bg: illwill.BackgroundColor
    searchMatchBg: illwill.BackgroundColor

  RecordIndex = object
    byteOffset: int64
    seqLength: int
    isFastq: bool

  RecordCache = object
    records: seq[FQRecord]       # All loaded records so far
    indexComplete: bool
    totalRecords: int            # Known count (grows during loading)
    maxCacheSize: int
    filename: string
    # Streaming state
    loadIterator: iterator(): FQRecord {.closure.}
    batchSize: int               # Records to load per idle frame

  ViewerState = object
    filename: string
    fileFormat: string
    currentTheme: int
    firstVisibleRecord: int
    wrapLineOffset: int  # Line offset within the first visible record (for wrap mode)
    horizontalOffset: int
    lineWrap: bool
    showRecordNumbers: bool
    searchPattern: string
    searchIsOligo: bool
    oligo1, oligo2: string
    oligo1Matches: Table[int, seq[seq[int]]]
    oligo2Matches: Table[int, seq[seq[int]]]
    searchOligoMatches: Table[int, seq[seq[int]]]  # For oligo search highlighting
    searchMatches: seq[int]
    currentSearchIdx: int
    inputMode: bool
    inputBuffer: string
    inputPrompt: string
    statusMessage: string
    isLoading: bool
    mouseEnabled: bool
    qualThresholds: seq[int]
    matchThs: float
    minMatches: int
    maxMismatches: int
    useAscii: bool
    useQualChars: bool
    noColor: bool
    helpMode: bool
    helpScrollOffset: int
    compactFastqView: bool
    colorSequence: bool
    # Windowed search state
    searchWindowStart: int   # First record index that has been searched
    searchWindowEnd: int     # Last record index + 1 that has been searched
    searchComplete: bool     # True if entire file has been searched

# Constants
const
  INITIAL_LOAD = 50          # Records to load before first display
  BATCH_LOAD = 200           # Records to load per idle frame
  SEARCH_WINDOW = 500        # Records to search per window/section
  HELP_TEXT = staticRead("seqfu_less_help.txt")

proc initThemes(): seq[Theme] =
  var themes: seq[Theme] = @[]
  # Dark theme (default)
  themes.add(Theme(
    name: "Dark",
    barFg: illwill.fgWhite, barBg: illwill.fgBlue,
    defaultFg: illwill.fgWhite, defaultBg: illwill.fgBlack,
    seqNameFg: illwill.fgWhite, seqCommentFg: illwill.fgCyan,
    coloredA: illwill.fgRed, coloredC: illwill.fgCyan, coloredG: illwill.fgGreen, coloredT: illwill.fgYellow, coloredN: illwill.fgWhite,
    qualColors: [illwill.fgWhite, illwill.fgWhite, illwill.fgRed, illwill.fgRed, illwill.fgYellow, illwill.fgYellow, illwill.fgGreen, illwill.fgGreen],
    oligoMatch1Bg: illwill.bgBlue, oligoMatch2Bg: illwill.bgRed,
    searchMatchBg: illwill.bgMagenta
  ))

  # Light theme
  themes.add(Theme(
    name: "Light",
    barFg: illwill.fgBlack, barBg: illwill.fgWhite,
    defaultFg: illwill.fgBlack, defaultBg: illwill.fgWhite,
    seqNameFg: illwill.fgBlack, seqCommentFg: illwill.fgBlue,
    coloredA: illwill.fgRed, coloredC: illwill.fgCyan, coloredG: illwill.fgGreen, coloredT: illwill.fgYellow, coloredN: illwill.fgBlack,
    qualColors: [illwill.fgBlack, illwill.fgBlack, illwill.fgRed, illwill.fgRed, illwill.fgYellow, illwill.fgYellow, illwill.fgGreen, illwill.fgGreen],
    oligoMatch1Bg: illwill.bgCyan, oligoMatch2Bg: illwill.bgRed,
    searchMatchBg: illwill.bgMagenta
  ))

  # Solarized theme
  themes.add(Theme(
    name: "Solarized",
    barFg: illwill.fgCyan, barBg: illwill.fgBlue,
    defaultFg: illwill.fgCyan, defaultBg: illwill.fgBlack,
    seqNameFg: illwill.fgYellow, seqCommentFg: illwill.fgCyan,
    coloredA: illwill.fgRed, coloredC: illwill.fgBlue, coloredG: illwill.fgGreen, coloredT: illwill.fgYellow, coloredN: illwill.fgCyan,
    qualColors: [illwill.fgCyan, illwill.fgCyan, illwill.fgRed, illwill.fgRed, illwill.fgYellow, illwill.fgYellow, illwill.fgGreen, illwill.fgGreen],
    oligoMatch1Bg: illwill.bgBlue, oligoMatch2Bg: illwill.bgRed,
    searchMatchBg: illwill.bgMagenta
  ))
  return themes

proc parseMemorySize(s: string): int =
  var size = s.toUpperAscii().strip()
  if size.endsWith("G"):
    return parseInt(size[0..^2]) * 1024 * 1024 * 1024
  elif size.endsWith("M"):
    return parseInt(size[0..^2]) * 1024 * 1024
  elif size.endsWith("K"):
    return parseInt(size[0..^2]) * 1024
  else:
    return parseInt(size)

proc makeReadfqIterator(filename: string): iterator(): FQRecord {.closure.} =
  ## Create a closure iterator over readfq records
  result = iterator(): FQRecord {.closure.} =
    for record in readfq(filename):
      yield record

proc initCache(filename: string, maxSize: int): RecordCache =
  result.records = @[]
  result.indexComplete = false
  result.totalRecords = 0
  result.maxCacheSize = maxSize
  result.filename = filename
  result.batchSize = BATCH_LOAD
  {.cast(gcsafe).}:
    if fileExists(filename):
      result.loadIterator = makeReadfqIterator(filename)

proc loadInitialRecords(cache: var RecordCache, count: int = INITIAL_LOAD) =
  ## Load the first `count` records (blocking). Called once at startup.
  {.cast(gcsafe).}:
    if cache.loadIterator == nil:
      cache.indexComplete = true
      return
    for i in 0 ..< count:
      let record = cache.loadIterator()
      if finished(cache.loadIterator):
        cache.indexComplete = true
        break
      cache.records.add(record)
    cache.totalRecords = cache.records.len

proc loadMoreRecords(cache: var RecordCache): bool =
  ## Load a batch of records. Returns true if there are more to load.
  ## Call this during idle frames in the main loop.
  {.cast(gcsafe).}:
    if cache.indexComplete or cache.loadIterator == nil:
      return false
    for i in 0 ..< cache.batchSize:
      let record = cache.loadIterator()
      if finished(cache.loadIterator):
        cache.indexComplete = true
        return false
      cache.records.add(record)
    cache.totalRecords = cache.records.len
    return true

proc getRecord(cache: var RecordCache, idx: int): FQRecord =
  if idx < 0 or idx >= cache.records.len:
    return FQRecord()
  return cache.records[idx]

proc formatQualChar(qChar: char, thresholds: seq[int], useAscii: bool, useQualChars: bool): tuple[glyph: string, colorIdx: int] =
  let
    unicodeGlyphs = ["_", "\u2582", "\u2583", "\u2584", "\u2585", "\u2586", "\u2587", "\u2588"]
    asciiGlyphs = ["x", "_", "_", "o", "o", "i", "i", "I"]

  let val = charToQual(qChar)
  var idx = 0
  if val <= thresholds[0]: idx = 0
  elif val <= thresholds[1]: idx = 1
  elif val <= thresholds[2]: idx = 2
  elif val <= thresholds[3]: idx = 3
  elif val <= thresholds[4]: idx = 4
  elif val <= thresholds[5]: idx = 5
  elif val <= thresholds[6]: idx = 6
  else: idx = 7

  var displayChar: string
  if useQualChars:
    displayChar = $qChar
  elif useAscii:
    displayChar = asciiGlyphs[idx]
  else:
    displayChar = unicodeGlyphs[idx]

  return (displayChar, idx)

proc getBaseColor(c: char, theme: Theme): illwill.ForegroundColor =
  case c.toUpperAscii()
  of 'A': return theme.coloredA
  of 'C': return theme.coloredC
  of 'G': return theme.coloredG
  of 'T', 'U': return theme.coloredT
  else: return theme.coloredN

proc getQualityColor(qChar: char, thresholds: seq[int]): tuple[fg: illwill.ForegroundColor, bright: bool] =
  ## Map quality score to color for compact FASTQ view
  ## Gray (dim white): very low, Red: low, Yellow: medium, Green: good
  let val = charToQual(qChar)
  if val <= thresholds[0]:      # <= 3: very low (gray)
    return (illwill.fgBlack, true)  # bright black = gray in most terminals
  elif val <= thresholds[2]:    # <= 25: low (red)
    return (illwill.fgRed, false)
  elif val <= thresholds[4]:    # <= 30: medium (yellow)
    return (illwill.fgYellow, false)
  else:                         # > 30: good (green)
    return (illwill.fgGreen, false)

proc isInOligoMatch(pos: int, matches: seq[seq[int]], oligoLen: int): bool =
  if matches.len == 0:
    return false
  for direction in matches:
    for matchPos in direction:
      let start = if matchPos >= 0: matchPos else: 0
      let stop = if matchPos >= 0: matchPos + oligoLen else: oligoLen + matchPos
      if pos >= start and pos < stop:
        return true
  return false

proc findTextMatches(text, pattern: string): seq[int] =
  ## Find all starting positions of pattern in text (case-insensitive)
  result = @[]
  if pattern.len == 0:
    return
  let upperText = text.toUpperAscii()
  let upperPattern = pattern.toUpperAscii()
  var pos = 0
  while pos <= upperText.len - upperPattern.len:
    if upperText[pos ..< pos + upperPattern.len] == upperPattern:
      result.add(pos)
      pos += 1  # Allow overlapping matches
    else:
      pos += 1

proc isInTextMatch(pos: int, matchStarts: seq[int], patternLen: int): bool =
  ## Check if position is within any text match
  for start in matchStarts:
    if pos >= start and pos < start + patternLen:
      return true
  return false

proc drawHeaderWithHighlight(tb: var TerminalBuffer, headerText: string, line, startX, endX: int,
                             state: ViewerState, theme: Theme, isMatch: bool, commentStartPos: int) =
  ## Draw header text with search highlight if this record matches
  ## commentStartPos: position where comment starts (for different styling)
  let matchStarts = if isMatch and not state.searchIsOligo and state.searchPattern.len > 0:
    findTextMatches(headerText, state.searchPattern)
  else:
    @[]

  for x in startX ..< endX:
    let charPos = x - startX
    if charPos < headerText.len:
      let c = headerText[charPos]
      if isInTextMatch(charPos, matchStarts, state.searchPattern.len):
        # Highlight matching text
        tb.setBackgroundColor(illwill.bgMagenta)
        tb.setForegroundColor(illwill.fgWhite, bright=true)
        tb.write(x, line, $c)
        tb.resetAttributes()
      else:
        # Check if we're in the comment portion
        if commentStartPos >= 0 and charPos >= commentStartPos:
          # Comment: use seqCommentFg without bold
          tb.setForegroundColor(theme.seqCommentFg, bright=false)
        else:
          # Identifier: use seqNameFg with bold
          tb.setForegroundColor(theme.seqNameFg, bright=true)
        tb.write(x, line, $c)
    else:
      tb.write(x, line, " ")

proc drawTopBar(tb: var TerminalBuffer, state: ViewerState, theme: Theme) =
  let
    width = tb.width
    title = state.filename
    padding = max(0, (width - len(title)) div 2)

  tb.setBackgroundColor(illwill.bgBlue)
  tb.setForegroundColor(illwill.fgWhite, bright=true)

  # Fill the bar
  for x in 0 ..< width:
    tb.write(x, 0, " ")

  # Center the title
  tb.write(padding, 0, title)
  tb.resetAttributes()

proc drawStatusBar(tb: var TerminalBuffer, state: ViewerState, theme: Theme, cache: RecordCache, themes: seq[Theme]) =
  let
    width = tb.width
    height = tb.height
    y = height - 1

  # Calculate visible records
  let
    visibleCount = max(1, (height - 3) div 4)  # Rough estimate: 4 lines per record
    lastVisible = min(state.firstVisibleRecord + visibleCount - 1, cache.totalRecords - 1)
    colEnd = state.horizontalOffset + width - 10

  var statusText: string
  if state.inputMode:
    statusText = state.inputPrompt & state.inputBuffer & "_"
  else:
    let wrapStatus = if state.lineWrap: "ON" else: "OFF"
    var wrapLineInfo = ""
    if state.lineWrap and state.wrapLineOffset > 0:
      wrapLineInfo = fmt" L+{state.wrapLineOffset}"
    let totalDisplay = if cache.indexComplete:
      $cache.totalRecords
    else:
      let rounded = (cache.totalRecords div 10000) * 10000
      if rounded > 0: fmt">{rounded}" else: fmt">{cache.totalRecords}"
    let loadingIndicator = if cache.indexComplete: "" else: " [Loading...]"
    let colInfo = if state.lineWrap: "" else: fmt" | Col: {state.horizontalOffset}-{colEnd}"
    let compactInfo = if state.compactFastqView: " | Compact" else: ""
    statusText = fmt"{state.firstVisibleRecord + 1}{wrapLineInfo}-{lastVisible + 1}/{totalDisplay}{colInfo} | {state.fileFormat}{compactInfo} | Wrap:{wrapStatus} | Theme:{themes[state.currentTheme].name}{loadingIndicator}"
    if state.statusMessage.len > 0:
      statusText = statusText & " | " & state.statusMessage

  tb.setBackgroundColor(illwill.bgBlue)
  tb.setForegroundColor(illwill.fgWhite, bright=true)

  # Fill the bar
  for x in 0 ..< width:
    tb.write(x, y, " ")

  # Write status
  let displayText = if statusText.len > width - 2: statusText[0 ..< width - 2] else: statusText
  tb.write(1, y, displayText)
  tb.resetAttributes()

proc drawSequenceLine(tb: var TerminalBuffer, record: FQRecord, seqStart, seqEnd: int,
                      line, xOffset: int, state: ViewerState, theme: Theme,
                      oligo1Matches, oligo2Matches, searchOligoMatches: seq[seq[int]]) =
  ## Draw a single line of sequence with colored bases
  let width = tb.width
  for x in xOffset ..< width:
    let seqPos = seqStart + (x - xOffset)
    if seqPos < seqEnd and seqPos < record.sequence.len:
      let base = record.sequence[seqPos]
      let baseColor = getBaseColor(base, theme)

      # Check if in oligo match region for highlighting
      # Priority: search match (magenta) > oligo1 (blue) > oligo2 (red)
      var bgCol = illwill.bgBlack
      if state.searchIsOligo and isInOligoMatch(seqPos, searchOligoMatches, state.searchPattern.len):
        bgCol = illwill.bgMagenta
      elif isInOligoMatch(seqPos, oligo1Matches, state.oligo1.len):
        bgCol = illwill.bgBlue
      elif isInOligoMatch(seqPos, oligo2Matches, state.oligo2.len):
        bgCol = illwill.bgRed

      if state.noColor or not state.colorSequence:
        tb.setBackgroundColor(bgCol)
        tb.write(x, line, $base)
        if bgCol != illwill.bgBlack:
          tb.resetAttributes()
      else:
        tb.setForegroundColor(baseColor)
        tb.setBackgroundColor(bgCol)
        tb.write(x, line, $base)
        tb.resetAttributes()
    else:
      tb.write(x, line, " ")

proc drawCompactSequenceLine(tb: var TerminalBuffer, record: FQRecord, seqStart, seqEnd: int,
                             line, xOffset: int, state: ViewerState, theme: Theme,
                             oligo1Matches, oligo2Matches, searchOligoMatches: seq[seq[int]]) =
  ## Draw a single line of sequence with bases colored by quality score (compact FASTQ view)
  let width = tb.width
  for x in xOffset ..< width:
    let seqPos = seqStart + (x - xOffset)
    if seqPos < seqEnd and seqPos < record.sequence.len:
      let base = record.sequence[seqPos]

      # Oligo/search match background (same priority as normal mode)
      var bgCol = illwill.bgBlack
      if state.searchIsOligo and isInOligoMatch(seqPos, searchOligoMatches, state.searchPattern.len):
        bgCol = illwill.bgMagenta
      elif isInOligoMatch(seqPos, oligo1Matches, state.oligo1.len):
        bgCol = illwill.bgBlue
      elif isInOligoMatch(seqPos, oligo2Matches, state.oligo2.len):
        bgCol = illwill.bgRed

      # Color by quality
      if seqPos < record.quality.len:
        let (fg, bright) = getQualityColor(record.quality[seqPos], state.qualThresholds)
        tb.setForegroundColor(fg, bright=bright)
      else:
        tb.setForegroundColor(theme.defaultFg)
      tb.setBackgroundColor(bgCol)
      tb.write(x, line, $base)
      tb.resetAttributes()
    else:
      tb.write(x, line, " ")

proc drawQualityLine(tb: var TerminalBuffer, record: FQRecord, seqStart, seqEnd: int,
                     line, xOffset: int, state: ViewerState, theme: Theme) =
  ## Draw a single line of quality scores
  let width = tb.width
  for x in xOffset ..< width:
    let seqPos = seqStart + (x - xOffset)
    if seqPos < seqEnd and seqPos < record.quality.len:
      let (glyph, colorIdx) = formatQualChar(record.quality[seqPos], state.qualThresholds, state.useAscii, state.useQualChars)
      if state.noColor:
        tb.write(x, line, glyph)
      else:
        tb.setForegroundColor(theme.qualColors[colorIdx])
        tb.write(x, line, glyph)
        tb.resetAttributes()
    else:
      tb.write(x, line, " ")

proc calcRecordLines(record: FQRecord, width: int, showRecordNumbers: bool, compactFastq: bool = false): int =
  ## Calculate how many lines a record would take in wrap mode
  let isFasta = record.quality.len == 0

  # Calculate header lines
  var headerLen = 1 + record.name.len  # prefix + name
  if showRecordNumbers:
    headerLen += 5  # "[123] " approximate
  if record.comment.len > 0:
    headerLen += 1 + record.comment.len

  var lines = 1  # First header line
  if headerLen > width:
    lines += (headerLen - width + (width - 3)) div (width - 2)  # Wrapped header lines

  # Calculate sequence/quality lines
  let seqChunks = (record.sequence.len + width - 1) div width  # ceil division
  if isFasta or compactFastq:
    lines += seqChunks  # No quality line in FASTA or compact mode
  else:
    lines += seqChunks * 2  # sequence + quality for each chunk

  return lines

proc drawRecord(tb: var TerminalBuffer, record: FQRecord, startLine: int, state: ViewerState,
                theme: Theme, recordNum: int, cache: RecordCache, skipLines: int = 0): int =
  ## Draw a record and return the number of lines used
  ## skipLines: number of lines to skip from the beginning (for wrap mode scrolling)
  let
    width = tb.width
    isFasta = record.quality.len == 0
    prefix = if isFasta: ">" else: "@"
  var line = startLine

  if line >= tb.height - 1:
    return 0

  # Oligo match data (command-line oligos)
  var oligo1Matches: seq[seq[int]] = @[]
  var oligo2Matches: seq[seq[int]] = @[]
  if recordNum in state.oligo1Matches:
    oligo1Matches = state.oligo1Matches[recordNum]
  if recordNum in state.oligo2Matches:
    oligo2Matches = state.oligo2Matches[recordNum]

  # Search oligo matches (from "/" search)
  var searchOligoMatches: seq[seq[int]] = @[]
  if recordNum in state.searchOligoMatches:
    searchOligoMatches = state.searchOligoMatches[recordNum]

  # Check if this record is in search results (for header highlighting)
  let isSearchMatch = recordNum in state.searchMatches

  # Header line
  var headerText = prefix
  if state.showRecordNumbers:
    headerText &= fmt"[{recordNum + 1}] "
  headerText &= record.name

  # Calculate where comment starts in headerText
  let commentStartPos = if record.comment.len > 0:
    headerText.len + 1  # Position after the space we're about to add
  else:
    -1  # No comment

  if record.comment.len > 0:
    headerText &= " " & record.comment

  if state.lineWrap:
    # LINE WRAP MODE: wrap header if needed
    # Track virtual line number (for skipLines support)
    var virtualLine = 0

    # First header line
    if virtualLine >= skipLines:
      let displayHeader = headerText[0 ..< min(headerText.len, width)]
      drawHeaderWithHighlight(tb, displayHeader, line, 0, width, state, theme, isSearchMatch, commentStartPos)
      line += 1
    virtualLine += 1

    # Wrap long headers (mainly for FASTQ with long comments)
    var headerPos = width
    while headerPos < headerText.len:
      if virtualLine >= skipLines and line < tb.height - 1:
        let remaining = headerText[headerPos ..< min(headerText.len, headerPos + width - 2)]
        # Draw continuation with highlighting
        tb.write(0, line, "  ")  # Indent
        # Adjust commentStartPos for the wrapped portion (account for indent and offset)
        let adjustedCommentStart = if commentStartPos >= 0:
          commentStartPos - headerPos
        else:
          -1
        drawHeaderWithHighlight(tb, remaining, line, 2, width, state, theme, isSearchMatch, adjustedCommentStart)
        line += 1
      virtualLine += 1
      headerPos += width - 2

    if line >= tb.height - 1:
      return line - startLine

    # For FASTQ in wrap mode: show sequence chunk then quality chunk, alternating
    var seqPos = 0
    while seqPos < record.sequence.len:
      let chunkEnd = min(seqPos + width, record.sequence.len)

      # Draw sequence chunk (only if past skipLines)
      if virtualLine >= skipLines and line < tb.height - 1:
        if state.compactFastqView and not isFasta:
          drawCompactSequenceLine(tb, record, seqPos, chunkEnd, line, 0, state, theme, oligo1Matches, oligo2Matches, searchOligoMatches)
        else:
          drawSequenceLine(tb, record, seqPos, chunkEnd, line, 0, state, theme, oligo1Matches, oligo2Matches, searchOligoMatches)
        line += 1
      virtualLine += 1

      if line >= tb.height - 1:
        return line - startLine

      # Draw quality chunk (for FASTQ only, skip in compact mode)
      if not isFasta and record.quality.len > 0 and not state.compactFastqView:
        if virtualLine >= skipLines and line < tb.height - 1:
          drawQualityLine(tb, record, seqPos, chunkEnd, line, 0, state, theme)
          line += 1
        virtualLine += 1

      seqPos = chunkEnd

  else:
    # NO-WRAP MODE: horizontal scrolling
    let displayHeader = if state.horizontalOffset < headerText.len:
      headerText[state.horizontalOffset ..< min(headerText.len, state.horizontalOffset + width)]
    else: ""

    # Draw header with search highlighting
    if displayHeader.len > 0:
      # We need to adjust match positions for horizontal offset
      let headerForMatch = headerText  # Full header for match detection
      let matchStarts = if isSearchMatch and not state.searchIsOligo and state.searchPattern.len > 0:
        findTextMatches(headerForMatch, state.searchPattern)
      else:
        @[]

      for x in 0 ..< width:
        let charPos = x + state.horizontalOffset
        if charPos < headerText.len:
          let c = headerText[charPos]
          if isInTextMatch(charPos, matchStarts, state.searchPattern.len):
            tb.setBackgroundColor(illwill.bgMagenta)
            tb.setForegroundColor(illwill.fgWhite, bright=true)
            tb.write(x, line, $c)
            tb.resetAttributes()
          else:
            # Check if we're in the comment portion
            if commentStartPos >= 0 and charPos >= commentStartPos:
              # Comment: use seqCommentFg without bold
              tb.setForegroundColor(theme.seqCommentFg, bright=false)
            else:
              # Identifier: use seqNameFg with bold
              tb.setForegroundColor(theme.seqNameFg, bright=true)
            tb.write(x, line, $c)
        else:
          tb.write(x, line, " ")
    else:
      for x in 0 ..< width:
        tb.write(x, line, " ")
    line += 1

    if line >= tb.height - 1:
      return line - startLine

    # Draw oligo1 match line if there are matches (only in no-wrap mode)
    if oligo1Matches.len > 0 and (oligo1Matches[0].len > 0 or (oligo1Matches.len > 1 and oligo1Matches[1].len > 0)):
      for x in 0 ..< width:
        let seqPos = x + state.horizontalOffset
        if seqPos < record.sequence.len:
          if isInOligoMatch(seqPos, oligo1Matches, state.oligo1.len):
            tb.setBackgroundColor(illwill.bgBlue)
            tb.setForegroundColor(illwill.fgWhite)
            tb.write(x, line, ">")
            tb.resetAttributes()
          else:
            tb.write(x, line, " ")
        else:
          tb.write(x, line, " ")
      line += 1

    # Draw oligo2 match line if there are matches (only in no-wrap mode)
    if oligo2Matches.len > 0 and (oligo2Matches[0].len > 0 or (oligo2Matches.len > 1 and oligo2Matches[1].len > 0)):
      for x in 0 ..< width:
        let seqPos = x + state.horizontalOffset
        if seqPos < record.sequence.len:
          if isInOligoMatch(seqPos, oligo2Matches, state.oligo2.len):
            tb.setBackgroundColor(illwill.bgRed)
            tb.setForegroundColor(illwill.fgWhite)
            tb.write(x, line, "<")
            tb.resetAttributes()
          else:
            tb.write(x, line, " ")
        else:
          tb.write(x, line, " ")
      line += 1

    if line >= tb.height - 1:
      return line - startLine

    # Sequence line with horizontal offset
    let seqStart = state.horizontalOffset
    if state.compactFastqView and not isFasta:
      drawCompactSequenceLine(tb, record, seqStart, seqStart + width, line, 0, state, theme, oligo1Matches, oligo2Matches, searchOligoMatches)
    else:
      drawSequenceLine(tb, record, seqStart, seqStart + width, line, 0, state, theme, oligo1Matches, oligo2Matches, searchOligoMatches)
    line += 1

    if line >= tb.height - 1:
      return line - startLine

    # Quality line (for FASTQ, skip in compact mode)
    if not isFasta and record.quality.len > 0 and not state.compactFastqView:
      drawQualityLine(tb, record, seqStart, seqStart + width, line, 0, state, theme)
      line += 1

  return line - startLine

proc renderHelp(state: var ViewerState, themes: seq[Theme]) =
  var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
  let theme = themes[state.currentTheme]

  # Clear screen
  tb.setBackgroundColor(illwill.bgBlack)
  for y in 0 ..< tb.height:
    for x in 0 ..< tb.width:
      tb.write(x, y, " ")

  # Split help text into lines
  let helpLines = HELP_TEXT.split('\n')
  let maxScroll = max(0, helpLines.len - (tb.height - 2))  # -2 for top and bottom bars

  # Clamp scroll offset
  if state.helpScrollOffset < 0:
    state.helpScrollOffset = 0
  if state.helpScrollOffset > maxScroll:
    state.helpScrollOffset = maxScroll

  # Draw top bar
  tb.setBackgroundColor(illwill.bgBlue)
  tb.setForegroundColor(illwill.fgWhite, bright=true)
  let title = "SeqFu Less - Help"
  let padding = max(0, (tb.width - len(title)) div 2)
  for x in 0 ..< tb.width:
    tb.write(x, 0, " ")
  tb.write(padding, 0, title)
  tb.resetAttributes()

  # Draw help content with explicit black background for every cell
  for i in 0 ..< tb.height - 2:
    let lineIdx = i + state.helpScrollOffset
    tb.setBackgroundColor(illwill.bgBlack)
    tb.setForegroundColor(theme.defaultFg)
    if lineIdx < helpLines.len:
      let line = helpLines[lineIdx]
      var displayLine: string
      var isBold = false
      if line.len > 0 and line[0] == '#':
        displayLine = line[1 ..< line.len].strip(leading=true, trailing=false)
        isBold = true
      else:
        displayLine = line
      if displayLine.len > tb.width - 2:
        displayLine = displayLine[0 ..< tb.width - 2]
      if isBold:
        tb.setForegroundColor(theme.defaultFg, bright=true)
        tb.setStyle({illwill.styleBright})
      tb.write(1, i + 1, displayLine)
      if isBold:
        tb.setForegroundColor(theme.defaultFg)
        tb.resetAttributes()
        tb.setBackgroundColor(illwill.bgBlack)
      # Fill remaining columns with spaces on black background
      for x in 1 + displayLine.len ..< tb.width:
        tb.write(x, i + 1, " ")
    else:
      # Empty line: fill with spaces on black background
      for x in 0 ..< tb.width:
        tb.write(x, i + 1, " ")

  # Draw status bar
  tb.setBackgroundColor(illwill.bgBlue)
  tb.setForegroundColor(illwill.fgWhite, bright=true)
  let statusY = tb.height - 1
  for x in 0 ..< tb.width:
    tb.write(x, statusY, " ")

  let statusText = if maxScroll > 0:
    fmt"Line {state.helpScrollOffset + 1}-{min(state.helpScrollOffset + tb.height - 2, helpLines.len)}/{helpLines.len} | Use Up/Down to scroll | Press Q or Esc to exit"
  else:
    "Press Q or Esc to return to viewer"

  tb.write(1, statusY, statusText[0 ..< min(statusText.len, tb.width - 2)])
  tb.resetAttributes()

  tb.display()

proc render(state: var ViewerState, cache: var RecordCache, themes: seq[Theme]) =
  # Check if in help mode
  if state.helpMode:
    renderHelp(state, themes)
    return

  var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
  let theme = themes[state.currentTheme]

  # Clear screen
  tb.setBackgroundColor(illwill.bgBlack)
  for y in 0 ..< tb.height:
    for x in 0 ..< tb.width:
      tb.write(x, y, " ")

  # Draw top bar
  drawTopBar(tb, state, theme)

  # Draw records
  var currentLine = 1  # Start after top bar
  var recordIdx = state.firstVisibleRecord
  var isFirstRecord = true

  while currentLine < tb.height - 1 and recordIdx < cache.totalRecords:
    let record = cache.getRecord(recordIdx)
    if record.sequence.len == 0 and record.name.len == 0:
      recordIdx += 1
      continue

    # For the first record in wrap mode, apply the line offset
    let skipLines = if isFirstRecord and state.lineWrap: state.wrapLineOffset else: 0
    let linesUsed = drawRecord(tb, record, currentLine, state, theme, recordIdx, cache, skipLines)
    currentLine += linesUsed
    recordIdx += 1
    isFirstRecord = false

  # Draw status bar
  drawStatusBar(tb, state, theme, cache, themes)

  tb.display()

proc searchWindowRange(state: var ViewerState, cache: RecordCache, start, stop: int) =
  ## Search records in range [start, stop) and add matches to state.searchMatches
  ## Maintains sorted order of searchMatches
  let query = state.searchPattern
  if query.len == 0:
    return

  for i in start ..< stop:
    if i < 0 or i >= cache.records.len:
      continue
    let record = cache.records[i]
    if state.searchIsOligo:
      let matches = findPrimerMatches(record.sequence, query, state.matchThs, state.maxMismatches, state.minMatches)
      if matches[0].len > 0 or matches[1].len > 0:
        state.searchMatches.add(i)
        state.searchOligoMatches[i] = matches
    else:
      let upperQuery = query.toUpperAscii()
      if upperQuery in record.name.toUpperAscii() or upperQuery in record.comment.toUpperAscii():
        state.searchMatches.add(i)

proc extendSearchForward(state: var ViewerState, cache: var RecordCache): bool =
  ## Extend search window forward by SEARCH_WINDOW records.
  ## Returns true if new matches were found or there are more records to search.
  let loadedCount = cache.records.len
  if state.searchWindowEnd >= loadedCount:
    if cache.indexComplete:
      state.searchComplete = true
      return false
    else:
      return false  # Can't search unloaded records yet

  let prevMatchCount = state.searchMatches.len
  let newEnd = min(state.searchWindowEnd + SEARCH_WINDOW, loadedCount)
  searchWindowRange(state, cache, state.searchWindowEnd, newEnd)
  state.searchWindowEnd = newEnd

  if state.searchWindowEnd >= loadedCount and cache.indexComplete:
    state.searchComplete = true

  return state.searchMatches.len > prevMatchCount

proc extendSearchBackward(state: var ViewerState, cache: var RecordCache): bool =
  ## Extend search window backward by SEARCH_WINDOW records.
  ## Returns true if new matches were found.
  if state.searchWindowStart <= 0:
    return false

  let prevMatchCount = state.searchMatches.len
  let newStart = max(0, state.searchWindowStart - SEARCH_WINDOW)
  searchWindowRange(state, cache, newStart, state.searchWindowStart)
  state.searchWindowStart = newStart

  # Re-sort matches since we added entries with lower indices
  if state.searchMatches.len > prevMatchCount:
    state.searchMatches.sort()
    return true
  return false

proc processSearchInput(state: var ViewerState, cache: var RecordCache) =
  let query = state.inputBuffer.strip()
  if query.len == 0:
    state.statusMessage = "Empty search"
    return

  # Store the search pattern
  state.searchPattern = query

  # Check if it's an oligo search (only IUPAC nucleotide characters)
  var isOligo = true
  for c in query.toUpperAscii():
    if c notin {'A', 'C', 'G', 'T', 'N', 'U', 'R', 'Y', 'S', 'W', 'K', 'M', 'B', 'D', 'H', 'V'}:
      isOligo = false
      break

  state.searchIsOligo = isOligo
  state.searchMatches = @[]
  state.searchOligoMatches.clear()
  state.searchComplete = false

  # Search a window around the current position
  let loadedCount = cache.records.len
  let center = state.firstVisibleRecord
  let halfWindow = SEARCH_WINDOW div 2
  state.searchWindowStart = max(0, center - halfWindow)
  state.searchWindowEnd = min(loadedCount, center + halfWindow)

  searchWindowRange(state, cache, state.searchWindowStart, state.searchWindowEnd)

  # Check if entire file was covered
  if state.searchWindowStart == 0 and state.searchWindowEnd >= loadedCount and cache.indexComplete:
    state.searchComplete = true

  let searchNote = if state.searchComplete: ""
    elif not cache.indexComplete: " (partial, still loading)"
    else: " (use n/N to search more)"

  if state.searchIsOligo:
    state.statusMessage = fmt"Found oligo in {state.searchMatches.len} records{searchNote}"
  else:
    state.statusMessage = fmt"Found '{query}' in {state.searchMatches.len} records{searchNote}"

  # Jump to closest match to current position
  if state.searchMatches.len > 0:
    # Find the match closest to current position
    state.currentSearchIdx = 0
    var bestDist = abs(state.searchMatches[0] - center)
    for i in 1 ..< state.searchMatches.len:
      let dist = abs(state.searchMatches[i] - center)
      if dist < bestDist:
        bestDist = dist
        state.currentSearchIdx = i
    state.firstVisibleRecord = state.searchMatches[state.currentSearchIdx]
    state.wrapLineOffset = 0
    state.statusMessage &= fmt" [{state.currentSearchIdx + 1}/{state.searchMatches.len}]"
  else:
    state.statusMessage = "No matches found" & searchNote

proc processJumpInput(state: var ViewerState, cache: RecordCache) =
  let query = state.inputBuffer.strip()
  if query.len == 0:
    state.statusMessage = "Empty jump target"
    return

  try:
    var target = parseInt(query) - 1  # Convert to 0-based
    let originalTarget = target + 1

    # Clamp to valid range
    if target < 0:
      target = 0
    if target >= cache.totalRecords:
      target = cache.totalRecords - 1

    state.firstVisibleRecord = target
    state.wrapLineOffset = 0  # Reset line offset when jumping

    if target + 1 != originalTarget:
      state.statusMessage = fmt"Jumped to {target + 1} (clamped from {originalTarget})"
    else:
      state.statusMessage = fmt"Jumped to record {target + 1}"
  except ValueError:
    state.statusMessage = "Invalid number"

proc handleKey(key: Key, state: var ViewerState, cache: var RecordCache, themes: seq[Theme]): bool =
  ## Returns false to exit

  # Help mode handling
  if state.helpMode:
    case key
    of Key.Q, Key.Escape:
      state.helpMode = false
      state.helpScrollOffset = 0
    of Key.Up, Key.A:
      if state.helpScrollOffset > 0:
        state.helpScrollOffset -= 1
    of Key.Down, Key.Z:
      state.helpScrollOffset += 1
    of Key.PageUp:
      state.helpScrollOffset = max(0, state.helpScrollOffset - 10)
    of Key.PageDown:
      state.helpScrollOffset += 10
    of Key.Home:
      state.helpScrollOffset = 0
    else:
      discard
    return true

  # Input mode handling
  if state.inputMode:
    case key
    of Key.Escape:
      state.inputMode = false
      state.inputBuffer = ""
      state.statusMessage = ""
    of Key.Enter:
      state.inputMode = false
      if state.inputPrompt == "/":
        processSearchInput(state, cache)
      elif state.inputPrompt == ":":
        processJumpInput(state, cache)
      state.inputBuffer = ""
    of Key.Backspace:
      if state.inputBuffer.len > 0:
        state.inputBuffer = state.inputBuffer[0 ..< state.inputBuffer.len - 1]
    # Handle digits
    of Key.Zero: state.inputBuffer &= "0"
    of Key.One: state.inputBuffer &= "1"
    of Key.Two: state.inputBuffer &= "2"
    of Key.Three: state.inputBuffer &= "3"
    of Key.Four: state.inputBuffer &= "4"
    of Key.Five: state.inputBuffer &= "5"
    of Key.Six: state.inputBuffer &= "6"
    of Key.Seven: state.inputBuffer &= "7"
    of Key.Eight: state.inputBuffer &= "8"
    of Key.Nine: state.inputBuffer &= "9"
    # Handle special characters
    of Key.Space: state.inputBuffer &= " "
    of Key.Minus: state.inputBuffer &= "-"
    of Key.Underscore: state.inputBuffer &= "_"
    of Key.Dot: state.inputBuffer &= "."
    of Key.Comma: state.inputBuffer &= ","
    of Key.Colon: state.inputBuffer &= ":"
    of Key.Semicolon: state.inputBuffer &= ";"
    of Key.At: state.inputBuffer &= "@"
    of Key.Hash: state.inputBuffer &= "#"
    of Key.Plus: state.inputBuffer &= "+"
    of Key.Equals: state.inputBuffer &= "="
    of Key.Asterisk: state.inputBuffer &= "*"
    of Key.Slash: state.inputBuffer &= "/"
    of Key.Backslash: state.inputBuffer &= "\\"
    of Key.Pipe: state.inputBuffer &= "|"
    of Key.Ampersand: state.inputBuffer &= "&"
    of Key.Percent: state.inputBuffer &= "%"
    of Key.Dollar: state.inputBuffer &= "$"
    of Key.Caret: state.inputBuffer &= "^"
    of Key.Tilde: state.inputBuffer &= "~"
    else:
      # Handle letters (lowercase from illwill)
      let keyStr = $key
      if keyStr.len == 1:
        state.inputBuffer &= keyStr.toLowerAscii()
      elif keyStr.startsWith("Shift"):
        # Shifted letters are uppercase
        state.inputBuffer &= keyStr[^1].toUpperAscii()
    return true

  # Normal mode handling
  case key
  of Key.Q, Key.Escape:
    return false

  # Vertical navigation
  of Key.Up, Key.A:
    if state.lineWrap:
      # In wrap mode, scroll by lines within the current record
      if state.wrapLineOffset > 0:
        state.wrapLineOffset -= 1
        state.statusMessage = ""
      elif state.firstVisibleRecord > 0:
        # Move to previous record, start at its last line
        state.firstVisibleRecord -= 1
        let prevRecord = cache.getRecord(state.firstVisibleRecord)
        let totalLines = calcRecordLines(prevRecord, terminalWidth(), state.showRecordNumbers, state.compactFastqView)
        # Show the last screen's worth of lines from the previous record
        let screenLines = terminalHeight() - 2  # minus top and bottom bars
        state.wrapLineOffset = max(0, totalLines - screenLines)
        state.statusMessage = ""
    else:
      if state.firstVisibleRecord > 0:
        state.firstVisibleRecord -= 1
        state.statusMessage = ""

  of Key.Down, Key.Z:
    if state.lineWrap:
      # In wrap mode, scroll by lines within the current record
      let currentRecord = cache.getRecord(state.firstVisibleRecord)
      let totalLines = calcRecordLines(currentRecord, terminalWidth(), state.showRecordNumbers, state.compactFastqView)
      if state.wrapLineOffset < totalLines - 1:
        state.wrapLineOffset += 1
        state.statusMessage = ""
      elif state.firstVisibleRecord < cache.totalRecords - 1:
        # Move to next record
        state.firstVisibleRecord += 1
        state.wrapLineOffset = 0
        state.statusMessage = ""
    else:
      if state.firstVisibleRecord < cache.totalRecords - 1:
        state.firstVisibleRecord += 1
        state.statusMessage = ""

  of Key.PageUp:
    let pageSize = max(1, (terminalHeight() - 3) div 4)
    if state.lineWrap:
      # In wrap mode, scroll by screen lines
      let linesToScroll = terminalHeight() - 2
      if state.wrapLineOffset >= linesToScroll:
        state.wrapLineOffset -= linesToScroll
      else:
        # Need to scroll to previous record(s)
        var remaining = linesToScroll - state.wrapLineOffset
        state.wrapLineOffset = 0
        while remaining > 0 and state.firstVisibleRecord > 0:
          state.firstVisibleRecord -= 1
          let prevRecord = cache.getRecord(state.firstVisibleRecord)
          let prevLines = calcRecordLines(prevRecord, terminalWidth(), state.showRecordNumbers, state.compactFastqView)
          if prevLines <= remaining:
            remaining -= prevLines
          else:
            state.wrapLineOffset = prevLines - remaining
            remaining = 0
    else:
      state.firstVisibleRecord = max(0, state.firstVisibleRecord - pageSize)
    state.statusMessage = ""

  of Key.PageDown, Key.Space:
    let pageSize = max(1, (terminalHeight() - 3) div 4)
    if state.lineWrap:
      # In wrap mode, scroll by screen lines
      let linesToScroll = terminalHeight() - 2
      var remaining = linesToScroll
      while remaining > 0 and state.firstVisibleRecord < cache.totalRecords - 1:
        let currentRecord = cache.getRecord(state.firstVisibleRecord)
        let currentLines = calcRecordLines(currentRecord, terminalWidth(), state.showRecordNumbers, state.compactFastqView)
        let linesRemaining = currentLines - state.wrapLineOffset
        if linesRemaining <= remaining:
          remaining -= linesRemaining
          state.firstVisibleRecord += 1
          state.wrapLineOffset = 0
        else:
          state.wrapLineOffset += remaining
          remaining = 0
    else:
      state.firstVisibleRecord = min(cache.totalRecords - 1, state.firstVisibleRecord + pageSize)
    state.statusMessage = ""

  of Key.CtrlA:
    if state.lineWrap:
      # Jump 100 lines up
      var remaining = 100
      while remaining > 0 and (state.wrapLineOffset > 0 or state.firstVisibleRecord > 0):
        if state.wrapLineOffset >= remaining:
          state.wrapLineOffset -= remaining
          remaining = 0
        else:
          remaining -= state.wrapLineOffset
          state.wrapLineOffset = 0
          if state.firstVisibleRecord > 0:
            state.firstVisibleRecord -= 1
            let prevRecord = cache.getRecord(state.firstVisibleRecord)
            let prevLines = calcRecordLines(prevRecord, terminalWidth(), state.showRecordNumbers, state.compactFastqView)
            state.wrapLineOffset = prevLines - 1
    else:
      state.firstVisibleRecord = max(0, state.firstVisibleRecord - 100)
    state.statusMessage = "Jumped 100 up"

  of Key.CtrlZ:
    if state.lineWrap:
      # Jump 100 lines down
      var remaining = 100
      while remaining > 0 and state.firstVisibleRecord < cache.totalRecords - 1:
        let currentRecord = cache.getRecord(state.firstVisibleRecord)
        let currentLines = calcRecordLines(currentRecord, terminalWidth(), state.showRecordNumbers, state.compactFastqView)
        let linesRemaining = currentLines - state.wrapLineOffset - 1
        if linesRemaining >= remaining:
          state.wrapLineOffset += remaining
          remaining = 0
        else:
          remaining -= linesRemaining + 1
          state.firstVisibleRecord += 1
          state.wrapLineOffset = 0
    else:
      state.firstVisibleRecord = min(cache.totalRecords - 1, state.firstVisibleRecord + 100)
    state.statusMessage = "Jumped 100 down"

  of Key.Home:
    state.firstVisibleRecord = 0
    state.wrapLineOffset = 0
    state.statusMessage = "Start"

  of Key.End:
    state.firstVisibleRecord = max(0, cache.totalRecords - 1)
    state.wrapLineOffset = 0
    state.statusMessage = if cache.indexComplete: "End" else: fmt"End (loaded {cache.totalRecords} so far)"

  # Horizontal navigation
  of Key.Left:
    if state.horizontalOffset > 0:
      state.horizontalOffset -= 1

  of Key.Right:
    state.horizontalOffset += 1

  of Key.L:
    state.horizontalOffset = max(0, state.horizontalOffset - 25)

  of Key.K:
    state.horizontalOffset += 25

  of Key.CtrlL:
    state.horizontalOffset = max(0, state.horizontalOffset - 250)

  of Key.CtrlK:
    state.horizontalOffset += 250

  # Toggle options
  of Key.S:
    state.lineWrap = not state.lineWrap
    state.wrapLineOffset = 0  # Reset line offset when toggling wrap mode
    state.statusMessage = if state.lineWrap: "Line wrap ON" else: "Line wrap OFF"

  of Key.T:
    state.currentTheme = (state.currentTheme + 1) mod themes.len
    state.statusMessage = fmt"Theme: {themes[state.currentTheme].name}"

  of Key.R:
    state.showRecordNumbers = not state.showRecordNumbers
    state.statusMessage = if state.showRecordNumbers: "Record numbers ON" else: "Record numbers OFF"

  of Key.C:
    state.compactFastqView = not state.compactFastqView
    state.wrapLineOffset = 0
    state.statusMessage = if state.compactFastqView: "Compact FASTQ view ON" else: "Compact FASTQ view OFF"

  of Key.U:
    state.useQualChars = not state.useQualChars
    state.statusMessage = if state.useQualChars: "Quality chars ON" else: "Quality bars ON"

  of Key.Zero:
    state.colorSequence = not state.colorSequence
    state.statusMessage = if state.colorSequence: "Sequence coloring ON" else: "Sequence coloring OFF"

  of Key.H:
    state.helpMode = true
    state.helpScrollOffset = 0

  # Search and jump
  of Key.Slash:
    state.inputMode = true
    state.inputPrompt = "/"
    state.inputBuffer = ""
    state.statusMessage = ""

  of Key.Colon:
    state.inputMode = true
    state.inputPrompt = ":"
    state.inputBuffer = ""
    state.statusMessage = ""

  # Navigate search results
  of Key.N:
    if state.searchPattern.len > 0:
      if state.searchMatches.len > 0 and state.currentSearchIdx < state.searchMatches.len - 1:
        # There's a next match in the current window
        state.currentSearchIdx += 1
        state.firstVisibleRecord = state.searchMatches[state.currentSearchIdx]
        state.wrapLineOffset = 0
        state.statusMessage = fmt"Match {state.currentSearchIdx + 1}/{state.searchMatches.len}"
      elif not state.searchComplete:
        # Try to extend search forward
        let found = extendSearchForward(state, cache)
        if found and state.currentSearchIdx < state.searchMatches.len - 1:
          state.currentSearchIdx += 1
          state.firstVisibleRecord = state.searchMatches[state.currentSearchIdx]
          state.wrapLineOffset = 0
          state.statusMessage = fmt"Match {state.currentSearchIdx + 1}/{state.searchMatches.len}"
          if not state.searchComplete:
            state.statusMessage &= " (more to search)"
        elif state.searchMatches.len > 0:
          # Wrap around to first match
          state.currentSearchIdx = 0
          state.firstVisibleRecord = state.searchMatches[0]
          state.wrapLineOffset = 0
          state.statusMessage = fmt"Wrapped: match {state.currentSearchIdx + 1}/{state.searchMatches.len}"
          if not state.searchComplete:
            state.statusMessage &= " (more to search)"
        else:
          state.statusMessage = "No matches found (searching...)"
      elif state.searchMatches.len > 0:
        # Search complete, wrap to first match
        state.currentSearchIdx = 0
        state.firstVisibleRecord = state.searchMatches[0]
        state.wrapLineOffset = 0
        state.statusMessage = fmt"Wrapped: match 1/{state.searchMatches.len}"
      else:
        state.statusMessage = "No matches found"

  of Key.ShiftN:
    if state.searchPattern.len > 0:
      if state.searchMatches.len > 0 and state.currentSearchIdx > 0:
        # There's a previous match in the current window
        state.currentSearchIdx -= 1
        state.firstVisibleRecord = state.searchMatches[state.currentSearchIdx]
        state.wrapLineOffset = 0
        state.statusMessage = fmt"Match {state.currentSearchIdx + 1}/{state.searchMatches.len}"
      elif state.searchWindowStart > 0:
        # Try to extend search backward
        let oldLen = state.searchMatches.len
        let found = extendSearchBackward(state, cache)
        if found:
          # Matches were added at the beginning; adjust currentSearchIdx
          let newEntries = state.searchMatches.len - oldLen
          state.currentSearchIdx = newEntries - 1  # Last of the newly found (closest to previous window)
          state.firstVisibleRecord = state.searchMatches[state.currentSearchIdx]
          state.wrapLineOffset = 0
          state.statusMessage = fmt"Match {state.currentSearchIdx + 1}/{state.searchMatches.len}"
        elif state.searchMatches.len > 0:
          # Wrap to last match
          state.currentSearchIdx = state.searchMatches.len - 1
          state.firstVisibleRecord = state.searchMatches[state.currentSearchIdx]
          state.wrapLineOffset = 0
          state.statusMessage = fmt"Wrapped: match {state.currentSearchIdx + 1}/{state.searchMatches.len}"
        else:
          state.statusMessage = "No matches found"
      elif state.searchMatches.len > 0:
        # At start, wrap to last match
        state.currentSearchIdx = state.searchMatches.len - 1
        state.firstVisibleRecord = state.searchMatches[state.currentSearchIdx]
        state.wrapLineOffset = 0
        state.statusMessage = fmt"Wrapped: match {state.currentSearchIdx + 1}/{state.searchMatches.len}"
      else:
        state.statusMessage = "No matches found"

  else:
    discard

  return true

proc exitProc() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)

proc fastx_less*(argv: var seq[string]): int {.gcsafe.} =
  let args = docopt("""
Usage: less [options] <inputfile>

Interactive viewer for FASTA/FASTQ files (like Unix less for sequences).

Navigation:
  Up/Down, A/Z         Scroll one record (or line in wrap mode)
  PgUp/PgDown, Space   Scroll one page up/down
  Ctrl+A/Ctrl+Z        Jump 100 records/lines up/down
  Home/End             Jump to start/end
  Left/Right           Scroll 1bp horizontally (no-wrap mode)
  L/K                  Scroll 25bp left/right
  Ctrl+L/Ctrl+K        Scroll 250bp left/right

Commands:
  /                    Search pattern (ID, comment, or oligo)
  :                    Jump to record number
  n/N                  Next/previous search match
  S                    Toggle line wrap
  T                    Cycle theme (Dark/Light/Solarized)
  R                    Toggle record numbers
  Q, Esc               Quit

Options:
  -S, --no-line-wrap       Disable line wrapping [default: false]
  -c, --cache-size SIZE    Cache size [default: 1G]
  -m, --mouse              Enable mouse support
  -o, --oligo1 OLIGO       Highlight oligo (blue background)
  -r, --oligo2 OLIGO       Second oligo to highlight (red background)
  -q, --qual-scale STR     Quality thresholds [default: 3:15:25:28:30:35:40]
  --match-ths FLOAT        Oligo match threshold [default: 0.75]
  --min-matches INT        Oligo min matches [default: 5]
  --max-mismatches INT     Oligo max mismatches [default: 2]
  --ascii                  Use ASCII quality chars
  -Q, --qual-chars         Show quality characters instead of bars
  -n, --nocolor            Disable colors
  -h, --help               Show this help
  """, version=version(), argv=argv)

  let filename = $args["<inputfile>"]

  if not fileExists(filename):
    stderr.writeLine("Error: input file not found: ", filename)
    return 1

  # Parse quality thresholds
  var thresholds = @[3, 15, 25, 28, 30, 35, 40]
  try:
    let parts = ($args["--qual-scale"]).split(':')
    if parts.len == 7:
      for i, p in parts:
        thresholds[i] = parseInt(p)
  except:
    stderr.writeLine("Warning: invalid qual-scale, using defaults")

  # Parse cache size
  var maxCache = 1024 * 1024 * 1024  # 1G default
  try:
    maxCache = parseMemorySize($args["--cache-size"])
  except:
    discard

  # Initialize themes
  let themes = initThemes()

  # Initialize state
  var state = ViewerState(
    filename: filename,
    fileFormat: "FASTA",  # Will be updated
    currentTheme: 0,
    firstVisibleRecord: 0,
    wrapLineOffset: 0,
    horizontalOffset: 0,
    lineWrap: not bool(args["--no-line-wrap"]),
    showRecordNumbers: false,
    searchPattern: "",
    searchIsOligo: false,
    oligo1: if $args["--oligo1"] != "nil": $args["--oligo1"] else: "",
    oligo2: if $args["--oligo2"] != "nil": $args["--oligo2"] else: "",
    oligo1Matches: initTable[int, seq[seq[int]]](),
    oligo2Matches: initTable[int, seq[seq[int]]](),
    searchOligoMatches: initTable[int, seq[seq[int]]](),
    searchMatches: @[],
    currentSearchIdx: 0,
    inputMode: false,
    inputBuffer: "",
    inputPrompt: "",
    statusMessage: "",
    isLoading: true,
    mouseEnabled: bool(args["--mouse"]) or getEnv("SEQFU_MOUSE") == "1",
    qualThresholds: thresholds,
    matchThs: parseFloat($args["--match-ths"]),
    minMatches: parseInt($args["--min-matches"]),
    maxMismatches: parseInt($args["--max-mismatches"]),
    useAscii: bool(args["--ascii"]),
    useQualChars: bool(args["--qual-chars"]),
    noColor: bool(args["--nocolor"]),
    helpMode: false,
    helpScrollOffset: 0,
    compactFastqView: false,
    colorSequence: true,
    searchWindowStart: 0,
    searchWindowEnd: 0,
    searchComplete: false
  )

  # Initialize cache and load only the first screenful
  var cache = initCache(filename, maxCache)
  loadInitialRecords(cache, INITIAL_LOAD)

  # Determine file format
  if cache.records.len > 0:
    state.fileFormat = if cache.records[0].quality.len > 0: "FASTQ" else: "FASTA"

  # Track how many records have been oligo-scanned
  var oligoScanIdx = 0

  state.statusMessage = ""

  # Initialize terminal
  illwillInit(fullscreen=true, mouse=state.mouseEnabled)
  setControlCHook(exitProc)
  hideCursor()

  # Main loop - use cast(gcsafe) because illwill uses global state
  {.cast(gcsafe).}:
    try:
      while true:
        render(state, cache, themes)

        let key = getKey()
        if key != Key.None:
          if not handleKey(key, state, cache, themes):
            break

        # Incremental loading: load more records during idle frames
        if not cache.indexComplete:
          let hadMore = loadMoreRecords(cache)
          if cache.indexComplete:
            state.isLoading = false
            state.statusMessage = fmt"{cache.totalRecords} records loaded"

        # Incremental oligo scanning for newly loaded records
        if state.oligo1.len > 0 or state.oligo2.len > 0:
          let scanEnd = min(oligoScanIdx + BATCH_LOAD, cache.records.len)
          for i in oligoScanIdx ..< scanEnd:
            let record = cache.records[i]
            if state.oligo1.len > 0:
              let matches = findPrimerMatches(record.sequence, state.oligo1, state.matchThs, state.maxMismatches, state.minMatches)
              if matches[0].len > 0 or matches[1].len > 0:
                state.oligo1Matches[i] = matches
            if state.oligo2.len > 0:
              let matches = findPrimerMatches(record.sequence, state.oligo2, state.matchThs, state.maxMismatches, state.minMatches)
              if matches[0].len > 0 or matches[1].len > 0:
                state.oligo2Matches[i] = matches
          oligoScanIdx = scanEnd

        sleep(16)
    finally:
      illwillDeinit()
      showCursor()

  return 0
