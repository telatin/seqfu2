import os, strformat, strutils
import illwill
import readfq
import docopt
import tables

# Custom types
type
  FQViewMode = enum
    fqSE, fqPEinterleaved, fqPEjoined, fqPEinline

# High-order custom types
type
  FuLessOptions = object
    mode: FQViewMode
    inputFile: string
    pairedFile: string
type
  # Color scheme for the MSA
  ColorType = enum
    base, match, both, none
 
  # The screen coordinates
  screenCoord = tuple
    x, y: int
  
  # MSA coordinates: index of first base in the MSA, and the index of the first base in the sequence
  seqCoord = tuple
    seqIndex, baseIndex: int

  # All the sequences are stored in an object
  msa = object 
    seqs: seq[string]
    names: seq[string]
    matches: seq[bool]
    gaps: seq[bool]
    consensus: string
    common: string
    protein: bool

  # All the settings for "rendering" an MSA
  coordinates = object
    firstseq: int           # <- this could be a coordinate tuple, but it wasnt at the beginning
    firstbase: int
    colortype: ColorType
    showconsensus: bool
    labelwidth: int
    message: string
    mouse: bool
    click_x, click_y: int
    exit_x, exit_y: int
    protein: bool

let
  noCoord : seqCoord = (seqIndex: -1, baseIndex: -1)

proc exitProc(c: coordinates, screenshot: bool)   =
  if screenshot == true:
    showCursor()
    quit(0)
    
  illwillDeinit()
  showCursor()
  if c.firstbase > -1:
    echo "Seq:" & $(c.firstseq) & ":" & $(c.firstbase) & ":" & $(c.labelwidth)
  quit(0)

proc exitDefProc {.noconv.} =
  illwillDeinit()
  showCursor()
  echo "Aborted. Exit with Q/Esc to print coordinates."
  quit(0)  

proc RotateColorType(c: var coordinates) =
  case c.colortype
  #base, match, both, none
  of base:
    c.colortype = match
  of match:
    c.colortype = both
  of both:
    c.colortype = none
  of none:
    c.colortype = base

proc toString(a: seq[Key]): string =
  let
    convert = {"One": "1", 
      "Two": "2",
      "Three": "3",
      "Four": "4",
      "Five": "5",
      "Six": "6",
      "Seven" : "7",
      "Eight": "8",
      "Nine": "9",
      "Zero": "0",
      "Colon": ":",
      "Hash": "#",
      "At": "@"}.toTable
  for key in a:
    let keyString = $key
    if len(keyString) == 1:
      result &= keyString
    elif keyString[0 .. 4] == "Shift":
      result &= keyString[^1]
    elif keyString in convert:
      result &= convert[keyString]


proc `$`(t: ColorType): string =
  case t
  of base:
    "Bases"
  of match:
    "Mismatches"
  of both:
    "Bases/Mismatches"
  of none:
    "None"

proc readMSA(f: string): msa =
  var
    seqs = newSeq[string]()
    names = newSeq[string]()
    length = -1
    prot = false
  # Load sequences
  for record in readfq(f):
    seqs.add(record.sequence)
    names.add(record.name)
    if length == -1:
      length = len(record.sequence)
    elif length != len(record.sequence):
      stderr.writeLine("ERROR: Sequence length mismatch: ", record.name, "is", len(record.sequence), "but previous sequences have length", length)
    
    if prot == false and ('L' in record.sequence or 'J' in record.sequence or 'E' in record.sequence or 'M' in record.sequence):
      prot = true
  
  result.protein = prot
  result.seqs = seqs
  result.names = names
  result.common = "?".repeat(length)
  result.consensus = "?".repeat(length)

  let
    ths = int(float(len(seqs) / 2))
  for pos in 0 ..< length:
    var
      c = 0
      base = ""
      baseCounts  = initCountTable[char]()
    result.matches.add(true)
    result.gaps.add(false)
    for seqIdx in 0 ..< len(seqs):
      baseCounts.inc(seqs[seqIdx][pos])
      if seqs[seqIdx][pos] == '-':
        result.gaps[pos] = true
      if c == 0:
        base = $(seqs[seqIdx][pos]).toUpperAscii()
        result.consensus[pos] = base[0]
      elif base != $(seqs[seqIdx][pos]).toUpperAscii():
        result.matches[pos] = false
        result.consensus[pos] = '.'
      c += 1

      # Get the most common base
      if baseCounts.largest()[1] > ths:
        result.common[pos] = baseCounts.largest()[0]
      else:
        result.common[pos] = '.'    
      
  return

proc writeSeq(tb: var TerminalBuffer, s: string, bg: seq[bool], line, start: int, coords: coordinates) =
  var
    fgColor: ForegroundColor
    bgColor: BackgroundColor
  for i, c in s:
    bgColor = BackgroundColor.bgBlack
    if coords.colortype == none:
      bgColor = bgBlack
      fgColor = fgWhite
    if coords.colortype == match or coords.colortype == both:
      if bg[i] == true:
        bgColor = bgWhite
        fgColor = fgBlack
      else:
        fgColor = fgWhite

    if coords.colortype == base or coords.colortype == both:
      if coords.protein == false:
        case c.toUpperAscii()
        of 'A':
          fgColor = fgRed
        of 'C':
          fgColor = fgCyan
        of 'G':
          fgColor = fgGreen
        of 'T':
          if coords.colortype == base:
            fgColor = fgYellow
          elif bg[i] == true:
            fgColor = fgBlack
        else:
          fgColor = fgWhite
      else:
        # PROTEIN (Lesk https://www.bioinformatics.nl/~berndb/aacolour.html)
        let aa = c.toUpperAscii()
        if aa in "CVILPFYMW":         # Hydrophobic, green
          fgColor = fgGreen
        elif aa in "GAST":            # Small non polar, yellow (orange)
          if coords.colortype == base:
            fgColor = fgYellow
          elif bg[i] == true:
            fgColor = fgBlack
        elif aa in "NQH":             # Polar, magenta
          fgColor = fgMagenta
        elif aa in "DE":              # - CHARGE: red
          fgColor = fgRed
        elif aa in "KR":           # Positively charged
          fgColor = fgCyan
        else:
            fgColor = fgWhite
      
    tb.write(start + 1 + i, line, styleBright, bgColor, fgColor, $c, fgWhite, bgBlack)

proc getRuler(start, width: int): string =
  var
    pos = 0
    span = 0
  while pos <= width:
    if pos mod 50 == 0:
      result &= fmt"|{pos+start}"
      span = len(fmt"|{pos+start}")
    elif pos mod 10 == 0:
      result &= ":"
      span = 0
    else:
      span = 0
      result &= " "
    pos += 1 + span
 
proc parseSettingsString(s: string): seq[int] =
  let
    dataString = s.split(":")
  
  if s == "nil":
    return
  if len(dataString) != 4:
    stderr.writeLine "Invalid settings string. Must be in the format 'Seq:INDEX:BASE:LABELWIDTH', got len=", len(dataString), " form ", s
    quit(1)
    
  if dataString[0] != "Seq":
    stderr.writeLine "Invalid settings string. Must be in the format 'Seq:INDEX:BASE:LABELWIDTH', got len=", len(dataString), " form ", s
    quit(1)
  
  try:
    result.add(parseInt(dataString[1]))
    result.add(parseInt(dataString[2]))
    result.add(parseInt(dataString[3]))
  except:
    stderr.writeLine("Invalid settings string, should be Seq:INDEX:BASE:LABELWIDTH")
    quit(1)
  
  return
proc getStartingHighlight(startPos, seqWidth, padding, totalWidth: int): screenCoord =
  let
    # What % of the sequence is visible?
    seqVisRatio = (totalWidth - padding) / seqWidth
    barWidth = int(seqVisRatio * float(totalWidth - padding))
    x = min(100.0, (100 * float(startPos) / float(seqWidth + totalWidth - padding)))
    #y = min(100.0, (100 * float(startPos + totalWidth - padding) / float(seqWidth + totalWidth - padding)) )

  result.x = min( int( float(totalWidth) *  (x / float(100)) )  + padding, totalWidth - 2)
  result.y = if seqWidth - startPos < totalWidth - padding: totalWidth
             else: min(totalWidth, padding + result.x + barWidth)

proc searchSeq(MSA: msa, query: string): seqCoord  =
  result.seqIndex = -1
  result.baseIndex= -1

  if query[0] == ':':
    # Jump
    try:
      result.seqIndex = parseInt(query[1 .. ^1])
      return
    except:
      return
  elif query[0] == '#':
    # Search by sequence
    for i, sequence in MSA.seqs:
      let pos = find(sequence.toUpperAscii(), query[1 .. ^1])
      if pos != -1:
        result.baseIndex = pos
        return
    return
  else:
    # Search string
    for i, sequenceName in MSA.names:
      if query in sequenceName.toUpperAscii():
        result.seqIndex = i
        return
  return

proc drawSeqs(MSA: msa, coords: coordinates) =
  let
    MAX_LEN = coords.labelwidth
    #spacer = " ".repeat(MAX_LEN)
  var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
  
  tb.setForegroundColor(fgWhite, bright=true)
  tb.setBackgroundColor(bgBlack)
  # Title
  tb.setForegroundColor(fgGreen, bright=true)
  
  # First two lines for title
  let
    startHl = getStartingHighlight(coords.firstbase, len(MSA.consensus), coords.labelwidth, tb.width - 1)
    title = "SeqFu MSAview [BETA]"

    info  = fmt"  Seq:{coords.firstseq}:{coords.firstbase}  Color:{coords.colortype}"
    endspace = " ".repeat(tb.width - len(title) - len(info) - 2 - len(coords.message))
    rulerText = getRuler(coords.firstbase, tb.width - MAX_LEN + 2)
  tb.write(1, 1, title, fgWhite, info, endspace, coords.message)
  #tb.write(1, 2, fmt"{spacer}{rulerText}")
  tb.setForegroundColor(fgCyan)
  
  

  tb.resetAttributes()
 
  let
    offset = 6
    seqNum = tb.height - offset - 1
    
  # First line is consensus
  tb.setForegroundColor(fgGreen, bright=true)
  tb.setBackgroundColor(bgBlack) 


  let
    name = if coords.showconsensus == true: "Consensus"
           else: "Majority"
    nameSpacer = " ".repeat(MAX_LEN - len(name))
  tb.write(1, offset - 1,   fgRed, fmt"{name}{nameSpacer} ")

  # Draw ruler label (before the ruler itself)
  tb.write(0, 2, fgWhite, bgBlack, fmt" ".repeat(MAX_LEN + 1))
  # Draw consensus and ruler (starting from MAX_LEN (seq label))
  for screenPos in MAX_LEN + 1 ..< tb.width :
    let
      basePos = screenPos - (MAX_LEN + 1 ) + coords.firstbase
      rulerBg = if screenPos > startHl.x and screenPos < startHl.y: bgBlue
           else: bgBlack

    # Draw ruler
    
    tb.write(screenPos, 2, fgWhite, rulerBg, fmt"{rulerText[screenPos - (MAX_LEN + 1)]}")
    # Draw consensus
    if basePos < len(MSA.consensus):
      let
        base = if coords.showconsensus == true: MSA.consensus[basePos]
              else: MSA.common[basePos]
        color = if coords.showconsensus == true: fgWhite
                elif MSA.matches[basePos] == true: fgWhite          
                elif base == '.': fgBlue
                else: fgGreen
      
      tb.write(screenPos, offset - 1, bgBlack, color, styleBright, fmt"{base}")
    else:
      tb.write(screenPos, offset - 1, bgBlack,        fmt" ")


  # Draw sequences starting from line "offset" till the end of the screen - 1
  for seqIndex in coords.firstseq ..< min(coords.firstseq + seqNum, len(MSA.seqs)):
    let
      name = (MSA.names[seqIndex])[0 ..< min(len(MSA.names[seqIndex]), MAX_LEN)]
      nameSpacer = " ".repeat(MAX_LEN - len(name))
    tb.setForegroundColor(fgWhite, bright=true)
    tb.setBackgroundColor(bgBlack)
    tb.write(1, seqIndex - coords.firstseq + offset,   fgWhite, fmt"{name}{nameSpacer} ")

    tb.writeSeq(MSA.seqs[seqIndex][coords.firstbase ..< min(coords.firstbase + tb.width - MAX_LEN - 2, len(MSA.seqs[seqIndex]))], 
            MSA.matches[coords.firstbase ..< min(coords.firstbase + tb.width - MAX_LEN - 2, len(MSA.seqs[seqIndex]))],
            seqIndex - coords.firstseq + offset,
            MAX_LEN,
            coords  )     
  
  # Fill black lines when there are less sequences than the screen can display
  for index in min(coords.firstseq + seqNum, len(MSA.seqs)) ..< coords.firstseq + seqNum:
    tb.write(1, index - coords.firstseq + offset, bgBlack, fgWhite, " ".repeat(tb.width - 2))
  
  # Top rectangle (title, ruler)
  tb.drawRect(0, 0, tb.width-1, 3)
  # Bottom rectangle (consensus, sequences)
  tb.drawRect(0, 4, tb.width-1, tb.height-1)   
  tb.display()
 
proc help() =
  var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
  tb.setForegroundColor(fgWhite)
  tb.setBackgroundColor(bgBlack)
  
  for line in 0 ..< tb.height:
    tb.write(1, line, " ".repeat(tb.width))
  tb.write(1, 1, "   SeqFu MSAview [BETA]")
  tb.write(1, 2, fmt"")
  tb.write(1, 3, fgGreen,  "  Horizontal scoll")
  tb.write(1, 4, fgWhite,  "   Left, Right Arrow   Left, Right (by one base)")
  tb.write(1, 5, fgWhite,  "   L, K                Left, Right (by 10 bases)")
  tb.write(1, 6, fgWhite,  "   CtrlL, CtrlK        Left, Right (by 100 bases)")

  tb.write(1, 7, fgGreen,  "  Vertical scroll")
  tb.write(1, 8, fgWhite,  "   A, Z                Up, Down (by one line)")
  tb.write(1, 9, fgWhite,  "   ShiftA, PageUp      Up (go to top)")
  tb.write(1, 10, fgWhite, "   ShiftZ, PageDown    Down (go to bottom)")

  tb.write(1, 11, fgGreen,  "  Other")
  tb.write(1, 12, fgWhite,  "   Tab                Change color scheme")
  tb.write(1, 12, fgWhite,  "   Space              Change consensus/majority")
  tb.write(1, 13, fgWhite,  "   F5,R               Refresh")
  tb.write(1, 14, fgWhite,  "   F5,CtrlR           Toggle Autorefresh")
  tb.write(1, 15, fgWhite,  "   Q, CtrlC           Quit")
  tb.setForegroundColor(fgGreen)
  tb.drawRect(0, 0, tb.width-1, tb.height-1)   
  tb.display()

proc main() =
  let args = docopt("""
  Usage:
    full [options] <MSAFILE>
  
  Keys:
    Scroll Horizontally     Left and Right arrow
      By 10 bases           L, K
      By 100 bases          ShiftL, ShiftK
      To the beginning      1
      To middle parts       2..9
      To the end            0

    Scroll Vertically       A, Up Arrow/ Z, Down Arrow
      Jump to top           ShiftA, PageUp
      Jump to bottom        ShiftZ, PageDown

    Rotate color scheme     Tab
    Refresh screen          F5
    Resize seq labels       -,+
    Search                  / (seqname, ":INT", "#SEQ")
    Quit                    Q, CtrlC

  Options:
    -m, --mouse               Enable mouse
    -n, --norefresh           Disable autorefresh
    -j, --jumpsize INT        Jump size (big jump is 10X) [default: 10]

  Visualization settings:
    -i, --seqindex INT        Start visualization at this sequence [default: 0]
    -p, --seqpos INT          Start visualization at this nucleotide [default: 0]
    -w, --label-width INT     Sequence label width [default: 20]
    -s, --setting-string STR  Settings string (overrrides all other settings) is in the
                              format Seq:{seqindex}:{seqpos}:{labelwidth} and is the 
                              return value of the program when it is closed.
    --screenshot              Do not clean the screen on exit

    More documentation online at https://telatin.github.io/seqfu2/
  """, version="1.0", argv=commandLineParams())
  
  if not fileExists($args["<MSAFILE>"]):
    stderr.writeLine("File not found: ", args["<MSAFILE>"])
    quit(1)
  
  let
    msa = readMSA($args["<MSAFILE>"])
    optSettings = parseSettingsString($args["--setting-string"])
    optFirstBase = if len(optSettings) > 0: optSettings[1]
                   else: parseInt($args["--seqpos"])
    optFirstSeq  = if len(optSettings) > 0: optSettings[0]
                   else: parseInt($args["--seqindex"])
    optLabelWidth = if len(optSettings) > 0: optSettings[2]
                   else: parseInt($args["--label-width"])
  
  # Override?
  var
    readTerm = false
    query = newSeq[Key]()
    autorefresh = not bool(args["--norefresh"])
    help = false

    coord  = coordinates(firstseq: optFirstSeq, 
      firstbase: optFirstBase, 
      colortype: base, 
      labelwidth: optLabelWidth,
      message: "[Help: H|Hor scroll: L,K|Vert: A,Z...]",
      mouse: bool(args["--mouse"]),
      click_x: 0,
      click_y: 0,
      exit_x: -1,
      exit_y: -1,
      protein: msa.protein
    )

  illwillInit(fullscreen=true, mouse=true)
  setControlCHook(exitDefProc)
  hideCursor()

  drawSeqs(msa, coord)
  
  while true:
    var
      key = getKey()
      blockSize = parseInt($args["--jumpsize"])
    
    let
      c : seqCoord = (seqIndex: coord.firstseq, baseIndex: coord.firstbase)
    
    if readTerm == true:
      if key == Key.Escape:
        readTerm = false
      elif key == Key.Enter:
        readTerm = false
        coord.message = "Not found"
        # Do something
        let c = searchSeq(msa, query.toString())
        
        if c.seqIndex > 0:
          coord.message = "Moving to: " & $(c.seqIndex)
          coord.firstseq = c.seqIndex
        elif c.baseIndex > 0:
          coord.message = "Motif found at " & $(c.baseIndex)
          coord.firstbase = c.baseIndex

        query.setlen(0)
        drawSeqs(msa, coord)

      else:
        query.add(key)
        coord.message = "/" & query.toString()
        drawSeqs(msa, coord)
      continue
    
    if bool(args["--screenshot"]):
      exitProc(coord, true)
    case key
 
    of Key.Escape, Key.Q: exitProc(coord, bool(args["--screenshot"]))

    # SCROLL LEFT
    of Key.Left:
      coord.message = "[Scroll -1]"
      if coord.firstbase >= 1:
        coord.firstbase -= 1
      else:
        coord.firstbase = 0
      drawSeqs(msa, coord)
    of Key.Right:
      coord.message = "[Scroll +1]"
      if coord.firstbase <= len(msa.seqs[0]) - 1:
        coord.firstbase += 1
      drawSeqs(msa, coord)
    of Key.K:
      coord.message = "[Scroll left]"
      if coord.firstbase >= blockSize:
        coord.firstbase -= blockSize
      else:
        coord.firstbase = 0
      drawSeqs(msa, coord)      
    of Key.L:
      coord.message = "[Scroll right]"
      if coord.firstbase <= len(msa.seqs[0]) - blockSize - 1:
        coord.firstbase += blockSize
      drawSeqs(msa, coord)  

    of Key.CtrlK, Key.ShiftK:
      coord.message = "[Big scroll left]"
      if coord.firstbase >= 10*blockSize:
        coord.firstbase -= 10*blockSize
      else:
        coord.firstbase = 0
      drawSeqs(msa, coord)      
    of Key.CtrlL, Key.ShiftL:
      coord.message = "[Big scroll right]"
      if coord.firstbase <= len(msa.seqs[0]) - 10*blockSize:
        coord.firstbase += 10*blockSize
      else:
        coord.firstbase = len(msa.seqs[0]) - 1
      drawSeqs(msa, coord)  
    of Key.Home, Key.One:
      # First base of sequence
      coord.message = "[Start of sequence]"
      coord.firstbase = 0
      drawSeqs(msa, coord)  


    of Key.Two:
      # Fifty Percent
      coord.message = "[20%]"
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 2) ))
      drawSeqs(msa, coord)  
    of Key.Three:
      # Fifty Percent
      coord.message = "[30%]"
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 3) ))
      drawSeqs(msa, coord)  
    of Key.Four:
      # Fifty Percent
      coord.message = "[40%]"
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 4) ))
      drawSeqs(msa, coord)  
    of Key.Five:
      # Fifty Percent
      coord.message = "[Middle]"
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 5) ))
      drawSeqs(msa, coord)  
    of Key.Six:
      # Fifty Percent
      coord.message = "[60%]"
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 6) ))
      drawSeqs(msa, coord)  
    of Key.Seven:
      # Fifty Percent
      coord.message = "[70%]"
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 7) ))
      drawSeqs(msa, coord)  
    of Key.Eight:
      # Fifty Percent
      coord.message = "[80%]"
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 8) ))
      drawSeqs(msa, coord)  
    of Key.Nine:
      # Fifty Percent
      coord.message = "[90%]"
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 9) ))
      drawSeqs(msa, coord)   
 
    of Key.End, Key.Zero:
      # Jump to end of sequence
      coord.message = "[End of sequence]"
      coord.firstbase = len(msa.seqs[0]) - 1
      drawSeqs(msa, coord)  

    of Key.Up, Key.A:
      # Sequence UP
      coord.message = "[Scroll up]"
      if coord.firstseq >= 1:
        coord.firstseq -= 1
        drawSeqs(msa, coord)
    of Key.Down, Key.Z:
      # Sequence Down
      if coord.firstseq <= len(msa.seqs) - 1:
        coord.firstseq += 1
        drawSeqs(msa, coord)

    of Key.PageUp, Key.ShiftA:
      # Jump to top of screen
      coord.message = "[Jump to top]"
      coord.firstseq = 1
      drawSeqs(msa, coord)
    of Key.PageDown, Key.ShiftZ:
      # Jump to bottom
      coord.message = "[Jump to top]"
      coord.firstseq = len(msa.seqs) - 1
      drawSeqs(msa, coord)


    of Key.Tab:
      # Rotate color scheme
      coord.message = "[Changed color scheme]"
      RotateColorType(coord)
      drawSeqs(msa, coord)
    of Key.Space:
      coord.message = "[Toggle consensus]"
      coord.showconsensus = not coord.showconsensus
      drawSeqs(msa, coord)
    of Key.F5, Key.R:
      # Refresh
      coord.message = "[Refreshed]"
      drawSeqs(msa, coord)
    of Key.F6, Key.ShiftR, Key.CtrlR:
      autorefresh = not ( autorefresh )
      coord.message = if autorefresh: "[autorefresh: on]" 
      else: "[autorefresh: off]"
      drawSeqs(msa, coord)

    of Key.M:
      coord.mouse = not ( coord.mouse )
      coord.message = if coord.mouse: "[mouse: on]" 
                      else: "[mouse: off]"
      drawSeqs(msa, coord)
    of Key.H, Key.F1:
      # Help
      help = not help
      help()

    of Key.Minus:
      if coord.labelwidth > 3:
        coord.labelwidth -= 1
        drawSeqs(msa, coord)
    of Key.Plus:
      if coord.labelwidth < 100:
        coord.labelwidth += 1
        drawSeqs(msa, coord)

    of Key.Slash:
      readTerm = true
      coord.message = "Query: "
      drawSeqs(msa, coord)
      
    of Key.Mouse:
      if coord.mouse == false:
        continue
      let mi = getMouse()
      if mi.action == MouseButtonAction.mbaPressed:
        case mi.button
        of mbLeft:
          coord.click_x = mi.x
          coord.click_y = mi.y
        else: discard
      elif mi.action == MouseButtonAction.mbaReleased:
        coord.message = fmt"[Clicked, shifting {mi.x - coord.labelwidth}]"
        if mi.x < coord.labelwidth:
          # Scroll left
          if coord.firstbase - (coord.labelwidth - mi.x) >= 0:
            coord.firstbase -= (coord.labelwidth - mi.x)
          else:
            coord.firstbase = 0
        elif  coord.firstbase + mi.x - coord.labelwidth - 1 > len(msa.seqs[0]) - 1:
          # End of sequence
          coord.firstbase = len(msa.seqs[0]) - 1
        elif mi.x - coord.labelwidth - 1 > 0:
          # Scroll right
          coord.firstbase += mi.x - coord.labelwidth - 1

        drawSeqs(msa, coord)
        coord.exit_x = -1
        coord.exit_y = -1

    else:
      if autorefresh and not help:
        drawSeqs(msa, coord)
      else:
        continue




    sleep(20)

main()

