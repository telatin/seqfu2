# Simple example that prints out the size of the terminal window and
# demonstrates the basic structure of a full-screen app.

import os, strformat
import illwill


proc exitProc() {.noconv.} =
  echo "Bye bye!"
  illwillDeinit()
  showCursor()
  quit(0)

proc window(s = "Default", cmdList: seq[string]) =
  var tb = newTerminalBuffer(terminalWidth(), terminalHeight())
  tb.setForegroundColor(fgWhite)
  tb.drawRect(0, 0, tb.width-1, 3)
  tb.drawRect(0, 4, tb.width-1, tb.height-1)
  tb.setBackgroundColor(bgRed)
  tb.setForegroundColor(fgWhite, bright=true)
  
  # First two lines for title
  tb.write(1, 1, fmt"Width:  {tb.width}  {s} stack: {len(cmdList)}")
  tb.write(1, 2, fmt"Height: {tb.height}   Press Q, Esc or Ctrl-C to quit")

  tb.resetAttributes()
  #tb.write(1, 5, "Press Q, Esc or Ctrl-C to quit")
  #tb.write(1, 6, "Resize the terminal window and see what happens :)")
  for idx in 0 ..< min(len(cmdList), tb.height - 6):
      let i = idx + 5
      tb.write(1, i, fmt"{idx}: {cmdList[idx]}")
      
  
  tb.display()

proc encode(s: Key): string =
  return "You pressed: " & $(s) 
  
proc main() =
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
        myList.add(" ----------------------- ")
        text = " TAB saves lives "
        
    else:
        if text != encode(key) and $key != "None":
          text = encode(key)
          window(text, myList)
        else:
          # Just refresh
          window(text, myList)



    sleep(20)

main()

