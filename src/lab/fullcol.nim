# Simple example that prints out the size of the terminal window and
# demonstrates the basic structure of a full-screen app.

import os, strformat, strutils
import illwill
import readfq
import docopt

type
  msa = object 
    seqs: seq[string]
    names: seq[string]

  coordinates = object
    firstseq: int
    firstbase: int

proc exitProc() {.noconv.} =
  
  illwillDeinit()
  showCursor()
  echo "Bye bye!"
  quit(0)

proc readMSA(f: string): msa =
  var
    seqs = newSeq[string]()
    names = newSeq[string]()

  for record in readfq(f):
    seqs.add(record.sequence)
    names.add(record.name)
  
  result.seqs = seqs
  result.names = names
  return



proc window(s = "Default", cmdList: seq[string]) =

  var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
  tb.setForegroundColor(fgWhite)
  tb.drawRect(0, 0, tb.width-1, 3)
  tb.drawRect(0, 4, tb.width-1, tb.height-1)
  #tb.setBackgroundColor(bgRed)
  tb.setForegroundColor(fgGreen, bright=true)
  
  # First two lines for title
  tb.write(1, 1, fmt" {tb.width}x{tb.height}   <<{s}>> stack: {len(cmdList)}")
  tb.setForegroundColor(fgRed)
  tb.write(1, 2, fmt" Press Q, Esc or Ctrl-C to quit | Press C, A, Tab or Enter for fun")

  tb.resetAttributes()
  #tb.write(1, 5, "Press Q, Esc or Ctrl-C to quit")
  #tb.write(1, 6, "Resize the terminal window and see what happens :)")
  for idx in 0 ..< min(len(cmdList), tb.height - 6):
    let
      i = idx + 5
      revitemidx = len(cmdList) - idx - 1
    var
      text = $revitemidx & ": " & cmdList[revitemidx]
    if (cmdList[revitemidx])[0] == '-':
      tb.setForegroundColor(fgRed, bright=true)
      text = "-".repeat(tb.width-3)
    elif idx mod 2 == 0:
      tb.setBackgroundColor(bgBlue)
      tb.setForegroundColor(fgWhite, bright=true)
    else:
      tb.resetAttributes()
      tb.setForegroundColor(fgCyan)
    let
      spacer = " ".repeat(tb.width - 3 - len(text))
    tb.write(1, i, fmt"{text}{spacer}")
    tb.resetAttributes()
      
  
  tb.display()

proc encode(s: Key): string =
  return "You pressed: " & $(s) 
  
proc main() =
  let args = docopt("""
  Usage:
    full <MSAFILE>
  """, version="1.0", argv=commandLineParams())
  
  if not fileExists($args["<MSAFILE>"]):
    stderr.writeLine("File not found: ", args["<MSAFILE>"])
    quit(1)
  
  let
    msa = readMSA($args["<MSAFILE>"])
  
  var
    coord  = coordinates(firstseq: 0, firstbase: 0)
  illwillInit(fullscreen=true)
  setControlCHook(exitProc)
  hideCursor()
  var
    text = ""
    c = 0
    myList = newSeq[string]()
  while true:
    c += 1

    var key = getKey()
    case key
    of Key.Escape, Key.Q: exitProc()

    of Key.A:
        text = " Pressed A "
        myList.add("The A key was pressed, and it's VERY special")
        window(text, myList)
    of Key.C:
        text = " This is good! "
        myList.add("The C key was pressed, and it's special. And good.")
        window(text, myList)
    of Key.Tab:
        myList.add("----------------TAB----")
        text = " TAB saves lives "
    of Key.Enter:
        myList.add("---------------ENTER---")
        text = " ENTER saves lives "
        
    else:
        if text != encode(key) and $key != "None":
          text = encode(key)
          window(text, myList)
        else:
          # Just refresh
          window(text, myList)



    sleep(20)

main()

