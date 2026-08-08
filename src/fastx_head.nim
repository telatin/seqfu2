## seqfu head — Print the first sequences from FASTA/FASTQ files.
##
## Selects sequences from the beginning of each input file, with optional
## subsampling via --skip. Supports renaming, format conversion, and
## streaming from stdin.

import readfq
import strutils
from os import fileExists, dirExists
import docopt
import ./seqfu_utils


proc fastx_head(argv: var seq[string]): int =
    let args = docopt("""
Usage: head [options] [<inputfile> ...]

Select a number of sequences from the beginning of a file, optionally
subsampling by printing one every SKIP sequences (for example, to print
100 reads selecting one every 10, use: -n 100 -k 10).

If no files are provided, reads from standard input.

Options:
  -n, --num NUM          Print the first NUM sequences [default: 10]
  -k, --skip SKIP        Print one sequence every SKIP (0 to disable) [default: 0]
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -s, --strip-comments   Remove comments
  -b, --basename         Prepend basename to sequence name
  -v, --verbose          Verbose output
  --print-last           Print the name of the last sequence to STDERR (Last:NAME)
  --fatal                Exit with error if fewer than NUM sequences are found
  --quiet                Don't print warnings
  -h, --help             Show this help

Output:
  --fasta                Force FASTA output
  --fastq                Force FASTQ output
  --sep STRING           Sequence name fields separator [default: _]
  -q, --fastq-qual INT   FASTQ default quality [default: 33]

  """, version=version(), argv=argv)

    # --- Set global output flags ---
    verbose       = args["--verbose"]
    stripComments = args["--strip-comments"]
    forceFasta    = bool(args["--fasta"])
    forceFastq    = bool(args["--fastq"])
    defaultQual   = parseInt($args["--fastq-qual"])

    # --- Parse arguments ---
    var
      num, skip    : int
      prefix       : string
      files        : seq[string]
      printBasename: bool
      separator    : string

    let
      printLast    = bool(args["--print-last"])
      fatalWarning = bool(args["--fatal"])

    try:
      num  = parseInt($args["--num"])
      skip = parseInt($args["--skip"])
      printBasename = args["--basename"]
      separator = $args["--sep"]
      if num < 0 or skip < 0:
        raise newException(ValueError, "negative value")
    except ValueError:
      stderr.writeLine("Error: invalid value for --num or --skip (expected non-negative integer).")
      quit(1)

    if args["--prefix"]:
      prefix = $args["--prefix"]

    # --- Collect input files ---
    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu head] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)

    # --- Process each file ---
    for filename in files:
      if filename != "-" and not fileExists(filename):
        if dirExists(filename):
          stderr.writeLine("WARNING: Directories are not supported. Skipping ", filename)
        else:
          stderr.writeLine("WARNING: File not found, skipping: ", filename)
        continue

      echoVerbose(filename, verbose)

      var
        subsampleIdx = 0
        seqCount = 0
        printedCount = 0
        lastPrintedName: string

      for record in readfq(filename):
        seqCount += 1

        if skip > 0:
          subsampleIdx = seqCount mod skip

        if printedCount == num:
          if verbose:
            stderr.writeLine("Stopping after ", printedCount, " sequences.")
          break

        if subsampleIdx == 0:
          var outRecord = record
          printedCount += 1
          if len(prefix) > 0:
            outRecord.name = prefix & separator & $printedCount
          if printBasename:
            outRecord.name = getBasename(filename) & separator & outRecord.name
          lastPrintedName = outRecord.name
          print_seq(outRecord, nil)

      if printedCount > 0 and printLast:
        stderr.writeLine("Last:", lastPrintedName)

      if (not args["--quiet"]) and printedCount < num:
        stderr.writeLine("WARNING: Printed fewer sequences (", printedCount, "/", num, ") than requested for ", filename, ". Try reducing --skip.")
        if fatalWarning:
          stderr.writeLine("Exiting with error.")
          quit(1)

    return 0
