import readfq
import tables, strutils
from os import fileExists
import md5
import docopt
import ./seqfu_utils


type
  SubtractOptions = object
    bySeq        : bool
    relaxed      : bool
    stripComment : bool
    stripPair    : bool
    verbose      : bool


proc subtractKey(name, comment, sequence: string, opts: SubtractOptions): string =
  if opts.bySeq:
    return $toMD5(sequence.toUpperAscii())

  var n = name
  if opts.stripPair:
    if n.endsWith("/1") or n.endsWith("/2"):
      n = n[0 ..< len(n) - 2]

  if opts.stripComment:
    return n

  if len(comment) > 0:
    return n & " " & comment
  return n


proc fastx_subtract(argv: var seq[string]): int =
  let args = docopt("""
Usage: subtract [options] <file1> <file2>

Print sequences from <file1> that are not present in <file2>.
By default, every sequence in <file2> must be present in <file1>
(i.e. <file2> is a strict subset of <file1>); exit with error otherwise.

Options:
  -s, --by-seq          Match by sequence content instead of name
  -r, --relaxed         Don't error if sequences in <file2> are absent from <file1>
  -c, --strip-comment   Ignore name suffix after first space when matching
  -p, --strip-pair      Ignore /1 or /2 pair suffixes in names when matching
  -v, --verbose         Print stats summary to stderr
  --help                Show this help

  """, version=version(), argv=argv)

  let opts = SubtractOptions(
    bySeq:        args["--by-seq"],
    relaxed:      args["--relaxed"],
    stripComment: args["--strip-comment"],
    stripPair:    args["--strip-pair"],
    verbose:      args["--verbose"]
  )

  let
    file1 = $args["<file1>"]
    file2 = $args["<file2>"]

  if not fileExists(file1) and file1 != "-":
    stderr.writeLine("ERROR: File not found: ", file1)
    return 1
  if not fileExists(file2) and file2 != "-":
    stderr.writeLine("ERROR: File not found: ", file2)
    return 1

  # Pass 1: read file2, build set of keys to subtract.
  # Value tracks whether each key was found in file1.
  var subtractSet = initTable[string, bool]()

  for record in readfq(file2):
    let key = subtractKey(record.name, record.comment, record.sequence, opts)
    subtractSet[key] = false

  if opts.verbose:
    stderr.writeLine("Sequences loaded from file2: ", len(subtractSet))

  # Pass 2: stream file1; print sequences whose key is absent from subtractSet.
  var
    total   = 0
    printed = 0

  for record in readfq(file1):
    total += 1
    let key = subtractKey(record.name, record.comment, record.sequence, opts)
    if key in subtractSet:
      subtractSet[key] = true
    else:
      let comment = if len(record.comment) > 0: " " & record.comment
                    else: ""
      if len(record.quality) > 0:
        echo '@', record.name, comment, "\n", record.sequence, "\n+\n", record.quality
      else:
        echo '>', record.name, comment, "\n", record.sequence
      printed += 1

  if opts.verbose:
    stderr.writeLine("Total sequences in file1: ", total)
    stderr.writeLine("Subtracted:               ", total - printed)
    stderr.writeLine("Printed:                  ", printed)

  # Strict validation: all keys in file2 must have been seen in file1.
  if not opts.relaxed:
    var missing = 0
    for key, found in subtractSet:
      if not found:
        stderr.writeLine("ERROR: sequence in <file2> not found in <file1>: ", key)
        missing += 1
    if missing > 0:
      stderr.writeLine("ERROR: ", missing, " sequence(s) from <file2> were not present in <file1>.")
      stderr.writeLine("Use --relaxed to suppress this error.")
      return 1

  return 0
