## seqfu tail — Print the last sequences from FASTA/FASTQ files.
##
## Selects sequences from the end of each input file, with optional
## subsampling via --skip. Must read the entire file to determine the
## last N sequences. Supports renaming, format conversion, and
## streaming from stdin.

import readfq
import strutils
import deques
import math
from os import fileExists, dirExists
import docopt
import ./seqfu_utils


proc keepSeq(pool: var Deque[FQRecord], sequence: FQRecord, max: int) =
  ## Maintain a sliding window of the last `max` sequences using a deque.
  ## O(1) per operation, unlike seq.delete(0) which is O(n).
  if pool.len >= max:
    pool.popFirst()
  pool.addLast(sequence)


proc fastx_tail(argv: var seq[string]): int =
    let args = docopt("""
Usage: tail [options] [<inputfile> ...]

Print the last sequences from FASTA/FASTQ files. The entire file must
be read to determine which sequences are last.

If no files are provided, reads from standard input.

Options:
  -n, --num NUM          Print the last NUM sequences [default: 10]
  -k, --skip SKIP        Print one sequence every SKIP (0 to disable) [default: 0]
  -p, --prefix STRING    Rename sequences with prefix + incremental number
  -s, --strip-comments   Remove comments
  -b, --basename         Prepend basename to sequence name
  -v, --verbose          Verbose output
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

    try:
      num  = parseInt($args["--num"])
      skip = parseInt($args["--skip"])
      printBasename = args["--basename"]
      separator = $args["--sep"]
    except:
      stderr.writeLine("Error: invalid value for --num or --skip (expected integer).")
      quit(1)

    if args["--prefix"]:
      prefix = $args["--prefix"]

    # --- Collect input files ---
    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu tail] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
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
        y = 0
        c = 0
        lastSequences = initDeque[FQRecord](nextPowerOfTwo(num))

      for record in readfq(filename):
        var outRecord: FQRecord = record
        c += 1

        # Subsampling: when skip > 0, only consider every skip-th sequence
        if skip > 0:
          y = c mod skip

        if y == 0:
          if len(prefix) > 0:
            outRecord.name = prefix & separator & $c
          if printBasename:
            outRecord.name = getBasename(filename) & separator & record.name
          lastSequences.keepSeq(outRecord, num)

      # --- Output the collected tail sequences ---
      for tailSeq in lastSequences:
        print_seq(tailSeq, nil)

    return 0
