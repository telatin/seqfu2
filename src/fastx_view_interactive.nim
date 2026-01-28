import readfq
import tables, strutils, strformat
from os import fileExists, getEnv
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
    headRecords: seq[FQRecord]
    tailRecords: seq[FQRecord]
    dynamicCache: Table[int, FQRecord]
    index: seq[RecordIndex]
    indexComplete: bool
    totalRecords: int
    maxCacheSize: int
    filename: string

  ViewerState = object
    filename: string
    fileFormat: string
    currentTheme: int
    firstVisibleRecord: int
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

# Constants
const
  HEAD_CACHE_SIZE = 100
  TAIL_CACHE_SIZE = 100

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

proc initCache(filename: string, maxSize: int): RecordCache =
  result.headRecords = @[]
  result.tailRecords = @[]
  result.dynamicCache = initTable[int, FQRecord]()
  result.index = @[]
  result.indexComplete = false
  result.totalRecords = 0
  result.maxCacheSize = maxSize
  result.filename = filename

proc loadAllRecords(cache: var RecordCache) =
  if not fileExists(cache.filename):
    return

  var count = 0
  for record in readfq(cache.filename):
    count += 1
    if count <= HEAD_CACHE_SIZE:
      cache.headRecords.add(record)
    else:
      cache.tailRecords.add(record)
      if cache.tailRecords.len > TAIL_CACHE_SIZE:
        cache.tailRecords.delete(0)

  cache.totalRecords = count
  cache.indexComplete = true

proc getRecord(cache: var RecordCache, idx: int): FQRecord =
  if idx < 0 or idx >= cache.totalRecords:
    return FQRecord()

  # Check head cache
  if idx < cache.headRecords.len:
    return cache.headRecords[idx]

  # Check tail cache
  let tailStartIdx = cache.totalRecords - cache.tailRecords.len
  if idx >= tailStartIdx:
    return cache.tailRecords[idx - tailStartIdx]

  # Check dynamic cache
  if idx in cache.dynamicCache:
    return cache.dynamicCache[idx]

  # Load from file (inefficient but functional fallback)
  var count = 0
  for record in readfq(cache.filename):
    if count == idx:
      cache.dynamicCache[idx] = record
      return record
    count += 1

  return FQRecord()

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
                             state: ViewerState, theme: Theme, isMatch: bool) =
  ## Draw header text with search highlight if this record matches
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
    let loadingIndicator = if cache.indexComplete: "" else: " Loading..."
    let wrapStatus = if state.lineWrap: "ON" else: "OFF"
    statusText = fmt"{state.firstVisibleRecord + 1}-{lastVisible + 1}/{cache.totalRecords} | Col: {state.horizontalOffset}-{colEnd} | {state.fileFormat} | Wrap:{wrapStatus} | Theme:{themes[state.currentTheme].name}{loadingIndicator}"
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

      if state.noColor:
        tb.write(x, line, $base)
      else:
        tb.setForegroundColor(baseColor)
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

proc drawRecord(tb: var TerminalBuffer, record: FQRecord, startLine: int, state: ViewerState,
                theme: Theme, recordNum: int, cache: RecordCache): int =
  ## Draw a record and return the number of lines used
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
  if record.comment.len > 0:
    headerText &= " " & record.comment

  if state.lineWrap:
    # LINE WRAP MODE: wrap header if needed
    let displayHeader = headerText[0 ..< min(headerText.len, width)]
    drawHeaderWithHighlight(tb, displayHeader, line, 0, width, state, theme, isSearchMatch)
    line += 1

    # Wrap long headers (mainly for FASTQ with long comments)
    var headerPos = width
    while headerPos < headerText.len and line < tb.height - 1:
      let remaining = headerText[headerPos ..< min(headerText.len, headerPos + width - 2)]
      # Draw continuation with highlighting
      tb.write(0, line, "  ")  # Indent
      drawHeaderWithHighlight(tb, remaining, line, 2, width, state, theme, isSearchMatch)
      line += 1
      headerPos += width - 2

    if line >= tb.height - 1:
      return line - startLine

    # For FASTQ in wrap mode: show sequence chunk then quality chunk, alternating
    var seqPos = 0
    while seqPos < record.sequence.len and line < tb.height - 1:
      let chunkEnd = min(seqPos + width, record.sequence.len)

      # Draw sequence chunk
      drawSequenceLine(tb, record, seqPos, chunkEnd, line, 0, state, theme, oligo1Matches, oligo2Matches, searchOligoMatches)
      line += 1

      if line >= tb.height - 1:
        return line - startLine

      # Draw quality chunk (for FASTQ only)
      if not isFasta and record.quality.len > 0:
        drawQualityLine(tb, record, seqPos, chunkEnd, line, 0, state, theme)
        line += 1

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
    drawSequenceLine(tb, record, seqStart, seqStart + width, line, 0, state, theme, oligo1Matches, oligo2Matches, searchOligoMatches)
    line += 1

    if line >= tb.height - 1:
      return line - startLine

    # Quality line (for FASTQ)
    if not isFasta and record.quality.len > 0:
      drawQualityLine(tb, record, seqStart, seqStart + width, line, 0, state, theme)
      line += 1

  return line - startLine

proc render(state: var ViewerState, cache: var RecordCache, themes: seq[Theme]) =
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

  while currentLine < tb.height - 1 and recordIdx < cache.totalRecords:
    let record = cache.getRecord(recordIdx)
    if record.sequence.len == 0 and record.name.len == 0:
      recordIdx += 1
      continue

    let linesUsed = drawRecord(tb, record, currentLine, state, theme, recordIdx, cache)
    currentLine += linesUsed
    recordIdx += 1

  # Draw status bar
  drawStatusBar(tb, state, theme, cache, themes)

  tb.display()

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

  if isOligo:
    # Search for oligo in sequences - store match positions for highlighting
    for i in 0 ..< cache.totalRecords:
      let record = cache.getRecord(i)
      let matches = findPrimerMatches(record.sequence, query, state.matchThs, state.maxMismatches, state.minMatches)
      if matches[0].len > 0 or matches[1].len > 0:
        state.searchMatches.add(i)
        state.searchOligoMatches[i] = matches
    state.statusMessage = fmt"Found oligo in {state.searchMatches.len} records"
  else:
    # Search in names and comments (case-insensitive)
    let upperQuery = query.toUpperAscii()
    for i in 0 ..< cache.totalRecords:
      let record = cache.getRecord(i)
      if upperQuery in record.name.toUpperAscii() or upperQuery in record.comment.toUpperAscii():
        state.searchMatches.add(i)
    state.statusMessage = fmt"Found '{query}' in {state.searchMatches.len} records"

  # Jump to first match
  if state.searchMatches.len > 0:
    state.currentSearchIdx = 0
    state.firstVisibleRecord = state.searchMatches[0]
  else:
    state.statusMessage = "No matches found"

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

    if target + 1 != originalTarget:
      state.statusMessage = fmt"Jumped to {target + 1} (clamped from {originalTarget})"
    else:
      state.statusMessage = fmt"Jumped to record {target + 1}"
  except ValueError:
    state.statusMessage = "Invalid number"

proc handleKey(key: Key, state: var ViewerState, cache: var RecordCache, themes: seq[Theme]): bool =
  ## Returns false to exit

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
    if state.firstVisibleRecord > 0:
      state.firstVisibleRecord -= 1
      state.statusMessage = ""

  of Key.Down, Key.Z:
    if state.firstVisibleRecord < cache.totalRecords - 1:
      state.firstVisibleRecord += 1
      state.statusMessage = ""

  of Key.PageUp:
    let pageSize = max(1, (terminalHeight() - 3) div 4)
    state.firstVisibleRecord = max(0, state.firstVisibleRecord - pageSize)
    state.statusMessage = ""

  of Key.PageDown:
    let pageSize = max(1, (terminalHeight() - 3) div 4)
    state.firstVisibleRecord = min(cache.totalRecords - 1, state.firstVisibleRecord + pageSize)
    state.statusMessage = ""

  of Key.CtrlA:
    state.firstVisibleRecord = max(0, state.firstVisibleRecord - 100)
    state.statusMessage = "Jumped 100 up"

  of Key.CtrlZ:
    state.firstVisibleRecord = min(cache.totalRecords - 1, state.firstVisibleRecord + 100)
    state.statusMessage = "Jumped 100 down"

  of Key.Home:
    state.firstVisibleRecord = 0
    state.statusMessage = "Start"

  of Key.End:
    state.firstVisibleRecord = max(0, cache.totalRecords - 1)
    state.statusMessage = "End"

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
    state.statusMessage = if state.lineWrap: "Line wrap ON" else: "Line wrap OFF"

  of Key.T:
    state.currentTheme = (state.currentTheme + 1) mod themes.len
    state.statusMessage = fmt"Theme: {themes[state.currentTheme].name}"

  of Key.R:
    state.showRecordNumbers = not state.showRecordNumbers
    state.statusMessage = if state.showRecordNumbers: "Record numbers ON" else: "Record numbers OFF"

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
    if state.searchMatches.len > 0:
      state.currentSearchIdx = (state.currentSearchIdx + 1) mod state.searchMatches.len
      state.firstVisibleRecord = state.searchMatches[state.currentSearchIdx]
      state.statusMessage = fmt"Match {state.currentSearchIdx + 1}/{state.searchMatches.len}"

  of Key.ShiftN:
    if state.searchMatches.len > 0:
      state.currentSearchIdx = (state.currentSearchIdx - 1 + state.searchMatches.len) mod state.searchMatches.len
      state.firstVisibleRecord = state.searchMatches[state.currentSearchIdx]
      state.statusMessage = fmt"Match {state.currentSearchIdx + 1}/{state.searchMatches.len}"

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
  Up/Down, A/Z         Scroll one record up/down
  PgUp/PgDown          Scroll one page up/down
  Ctrl+A/Ctrl+Z        Jump 100 records up/down
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
    statusMessage: "Loading...",
    isLoading: true,
    mouseEnabled: bool(args["--mouse"]) or getEnv("SEQFU_MOUSE") == "1",
    qualThresholds: thresholds,
    matchThs: parseFloat($args["--match-ths"]),
    minMatches: parseInt($args["--min-matches"]),
    maxMismatches: parseInt($args["--max-mismatches"]),
    useAscii: bool(args["--ascii"]),
    useQualChars: bool(args["--qual-chars"]),
    noColor: bool(args["--nocolor"])
  )

  # Initialize cache and load records
  var cache = initCache(filename, maxCache)
  loadAllRecords(cache)

  # Determine file format
  if cache.headRecords.len > 0:
    state.fileFormat = if cache.headRecords[0].quality.len > 0: "FASTQ" else: "FASTA"

  # Pre-compute oligo matches if specified
  if state.oligo1.len > 0:
    for i in 0 ..< cache.totalRecords:
      let record = cache.getRecord(i)
      let matches = findPrimerMatches(record.sequence, state.oligo1, state.matchThs, state.maxMismatches, state.minMatches)
      if matches[0].len > 0 or matches[1].len > 0:
        state.oligo1Matches[i] = matches

  if state.oligo2.len > 0:
    for i in 0 ..< cache.totalRecords:
      let record = cache.getRecord(i)
      let matches = findPrimerMatches(record.sequence, state.oligo2, state.matchThs, state.maxMismatches, state.minMatches)
      if matches[0].len > 0 or matches[1].len > 0:
        state.oligo2Matches[i] = matches

  state.isLoading = false
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

        sleep(20)
    finally:
      illwillDeinit()
      showCursor()

  return 0
