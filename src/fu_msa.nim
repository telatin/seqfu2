import os, osproc, strutils
import ./seqfu_utils

proc main(argv: var seq[string]): int =
  let
    localSeqfu = getAppDir() / ("seqfu" & ExeExt)
    seqfuBin = if fileExists(localSeqfu): localSeqfu else: "seqfu"

  stderr.writeLine(" ---------------- DEPRECATION NOTICE ----------------")
  stderr.writeLine(" 'fu-msa' has moved to 'seqfu msa'.")
  stderr.writeLine(" ----------------------------------------------------")
  stderr.writeLine("Starting: " & seqfuBin & " msa " & argv.join(" "))
  sleep(3000)

  var forwardedArgs = @["msa"]
  forwardedArgs.add(argv)
  let process = startProcess(seqfuBin, args = forwardedArgs,
    options = {poParentStreams})
  result = waitForExit(process)
  close(process)

when isMainModule:
  main_helper(main)
