import os, osproc, strutils
import ./seqfu_utils

proc main(argv: var seq[string]): int =
  let
    localSeqfu = getAppDir() / ("seqfu" & ExeExt)
    seqfuBin = if fileExists(localSeqfu): localSeqfu else: "seqfu"

  stderr.writeLine(" ---------------- DEPRECATION NOTICE ----------------")
  stderr.writeLine(" 'fu-shred' has moved to 'seqfu shred'.")
  stderr.writeLine(" ----------------------------------------------------")
  stderr.writeLine("Starting: " & seqfuBin & " shred " & argv.join(" "))
  sleep(3000)

  var forwardedArgs = @["shred"]
  forwardedArgs.add(argv)
  let process = startProcess(seqfuBin, args = forwardedArgs,
    options = {poParentStreams})
  result = waitForExit(process)
  close(process)

when isMainModule:
  main_helper(main)
