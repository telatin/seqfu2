# Simple example that prints out the size of the terminal window and
# demonstrates the basic structure of a full-screen app.

import os, strformat, strutils
import illwill
import readfq
import docopt
import tables

type
  ColorType = enum
    base, match, both, none
 

  msa = object 
    seqs: seq[string]
    names: seq[string]
    matches: seq[bool]
    gaps: seq[bool]
    consensus: string
    common: string


  coordinates = object
    firstseq: int
    firstbase: int
    colortype: ColorType
    showconsensus: bool
    labelwidth: int
    message: string
    mouse: bool
    click_x, click_y: int
    exit_x, exit_y: int

proc exitProc() {.noconv.} =
  
  illwillDeinit()
  showCursor()
  echo "Bye bye!"
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
  
  # Load sequences
  for record in readfq(f):
    seqs.add(record.sequence)
    names.add(record.name)
    if length == -1:
      length = len(record.sequence)
    elif length != len(record.sequence):
      stderr.writeLine("ERROR: Sequence length mismatch: ", record.name, "is", len(record.sequence), "but previous sequences have length", length)
  result.seqs = seqs
  result.names = names
  result.common = "X".repeat(length)
  result.consensus = "X".repeat(length)

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
      case c.toUpperAscii()
      of 'A':
        fgColor = fgRed
      of 'C':
        fgColor = fgBlue
      of 'G':
        fgColor = fgGreen
      of 'T':
        if coords.colortype == base:
          fgColor = fgYellow
        elif bg[i] == true:
          fgColor = fgBlack
      of '-':
        fgColor = fgMagenta
      else:
        fgColor = fgWhite
    
    tb.write(start + 1 + i, line, bgColor, fgColor, $c, fgWhite, bgBlack)

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

  
proc drawSeqs(MSA: msa, coords: coordinates) =
  let
    MAX_LEN = coords.labelwidth
    spacer = " ".repeat(MAX_LEN)
  var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
  
  tb.setForegroundColor(fgWhite)
  tb.setBackgroundColor(bgBlack)
  # Title
  tb.setForegroundColor(illwill.ForegroundColor.fgGreen, bright=true)
  
  # First two lines for title
  let
    title = "SeqFu MSAview [BETA]"
    mouse = if coords.exit_x > 0: fmt"{coords.click_x},{coords.click_y} {coords.exit_x},{coords.exit_y}"
            else: ""  # fmt"{coords.click_x},{coords.click_y}"  # fmt"{coords.click_x},{coords.click_y} {coords.exit_x},{coords.exit_y}"
    info  = fmt"  Screen:{tb.width}x{tb.height}  Color:{coords.colortype} {coords.message}"
    
    endspace = " ".repeat(tb.width - len(title) - len(info) - 2 - len(mouse))
  tb.write(1, 1, title, fgWhite, info, endspace, mouse)
  tb.setForegroundColor(illwill.ForegroundColor.fgCyan)
  let ruler = getRuler(coords.firstbase, tb.width - MAX_LEN)
  tb.write(1, 2, fmt"{spacer}{ruler}")

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
  tb.write(1, offset - 1,   fgWhite, fmt"{name}{nameSpacer} ")
  for screenPos in MAX_LEN + 1 ..< tb.width - 1:
    let basePos = screenPos - (MAX_LEN + 1 ) + coords.firstbase
    if basePos < len(MSA.consensus):
      let
        base = if coords.showconsensus == true: MSA.consensus[basePos]
              else: MSA.common[basePos]
        color = if coords.showconsensus == true: fgWhite
                else: fgCyan
      tb.write(screenPos, offset - 1,   color, fmt"{base}")
    else:
      tb.write(screenPos, offset - 1,    fmt" ")


  # Draw sequences
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
    #tb.write(1, seqIndex + 20, $MSA.matches[coords.firstbase ..< min(coords.firstbase + tb.width - MAX_LEN - 4, len(MSA.seqs[seqIndex]))])

  # Fill black lines
  for index in min(coords.firstseq + seqNum, len(MSA.seqs)) ..< coords.firstseq + seqNum:
    tb.write(1, index - coords.firstseq + offset, bgBlack, fgWhite, " ".repeat(tb.width - 2))
  tb.drawRect(0, 0, tb.width-1, 3)
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

  Options:
    -m, --mouse             Enable mouse
    -n, --norefresh         Disable autorefresh
    -w, --label-width INT   Sequence label width [default: 20]

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
  """, version="1.0", argv=commandLineParams())
  
  if not fileExists($args["<MSAFILE>"]):
    stderr.writeLine("File not found: ", args["<MSAFILE>"])
    quit(1)
  
  let
    msa = readMSA($args["<MSAFILE>"])

  var
    help = false
    autorefresh = not bool(args["--norefresh"])
    coord  = coordinates(firstseq: 0, 
      firstbase: 0, 
      colortype: base, 
      labelwidth: parseInt($args["--label-width"]),
      message: "[Hor scroll: L,K, ShiftL, ShiftK; Vert: A,Z...]",
      mouse: bool(args["--mouse"]),
      click_x: 0,
      click_y: 0,
      exit_x: -1,
      exit_y: -1
    )

  illwillInit(fullscreen=true, mouse=true)
  setControlCHook(exitProc)
  hideCursor()

  drawSeqs(msa, coord)
  
  while true:
    var
      key = getKey()
      blockSize = 10
    case key
    of Key.Escape, Key.Q: exitProc()

    # SCROLL LEFT
    of Key.Left:
      if coord.firstbase >= 1:
        coord.firstbase -= 1
      else:
        coord.firstbase = 0
      drawSeqs(msa, coord)
    of Key.Right:
      if coord.firstbase <= len(msa.seqs[0]) - 1:
        coord.firstbase += 1
      drawSeqs(msa, coord)
    of Key.K:
      if coord.firstbase >= blockSize:
        coord.firstbase -= blockSize
      else:
        coord.firstbase = 0
      drawSeqs(msa, coord)      
    of Key.L:
      if coord.firstbase <= len(msa.seqs[0]) - blockSize - 1:
        coord.firstbase += blockSize
      drawSeqs(msa, coord)  

    of Key.CtrlK, Key.ShiftK:
      if coord.firstbase >= 10*blockSize:
        coord.firstbase -= 10*blockSize
      else:
        coord.firstbase = 0
      drawSeqs(msa, coord)      
    of Key.CtrlL, Key.ShiftL:
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
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 2) ))
      drawSeqs(msa, coord)  
    of Key.Three:
      # Fifty Percent
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 3) ))
      drawSeqs(msa, coord)  
    of Key.Four:
      # Fifty Percent
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 4) ))
      drawSeqs(msa, coord)  
    of Key.Five:
      # Fifty Percent
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 5) ))
      drawSeqs(msa, coord)  
    of Key.Six:
      # Fifty Percent
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 6) ))
      drawSeqs(msa, coord)  
    of Key.Seven:
      # Fifty Percent
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 7) ))
      drawSeqs(msa, coord)  
    of Key.Eight:
      # Fifty Percent
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 8) ))
      drawSeqs(msa, coord)  
    of Key.Nine:
      # Fifty Percent
      coord.firstbase = int(float(len(msa.seqs[0])) / (float(10 / 9) ))
      drawSeqs(msa, coord)   
 
    of Key.End, Key.Zero:
      # Jump to end of sequence
      coord.message = "[End of sequence]"
      coord.firstbase = len(msa.seqs[0]) - 1
      drawSeqs(msa, coord)  

    of Key.Up, Key.A:
      # Sequence UP
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
        coord.message = fmt"[Clicked, resetting start base to {mi.x - coord.labelwidth}]"
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

