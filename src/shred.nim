import std/[math, os, random, strutils, tables]

import docopt
import readfx

import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "undef"
const programVersion = if NimblePkgVersion == "undef": "0.0.1-alpha"
                       else: NimblePkgVersion

type
  StrandMode = enum
    smFwd, smRev, smAlt, smBoth

  ShredOptions = object
    readLength: int
    fragLength: int
    fragSd: float
    step: int
    paired: bool
    circular: bool
    tail: bool
    amplicon: bool
    maxN: float
    strand: StrandMode

proc version(cmdName: string): string =
  return cmdName & " " & programVersion

proc die(cmdName, msg: string) {.noreturn.} =
  stderr.writeLine("[", cmdName, "] ERROR: ", msg)
  quit(1)

proc optStr(args: Table[string, Value], key: string): string =
  ## Returns the option value, or an empty string if it was not provided
  let v = args[key]
  if v.kind == vkNone: "" else: $v

proc optInt(args: Table[string, Value], key, cmdName: string): int =
  try:
    parseInt($args[key])
  except ValueError:
    die(cmdName, key & " must be an integer, got: " & $args[key])

proc optFloat(args: Table[string, Value], key, cmdName: string): float =
  try:
    parseFloat($args[key])
  except ValueError:
    die(cmdName, key & " must be a number, got: " & $args[key])

proc sampleFragLength(o: ShredOptions, rng: var Rand): int =
  ## Nominal segment length, or a normally distributed fragment length
  ## (never shorter than a read) when --frag-sd is set in paired-end mode
  if not o.paired:
    return o.readLength
  if o.fragSd <= 0:
    return o.fragLength
  max(o.readLength, int(round(rng.gauss(float(o.fragLength), o.fragSd))))

iterator fragments(seqLen: int, o: ShredOptions, rng: var Rand): tuple[start, length: int] =
  ## Yields (0-based start, length) of each segment to extract from a sequence.
  ## In circular mode start + length can exceed seqLen (the segment wraps).
  if o.amplicon:
    if seqLen > 0:
      yield (0, seqLen)
  else:
    let nominal = if o.paired: o.fragLength else: o.readLength
    if o.circular:
      for start in countup(0, seqLen - 1, o.step):
        let length = sampleFragLength(o, rng)
        if length <= seqLen:
          yield (start, length)
    else:
      # With a variable fragment size, a start is useful as long as a read fits
      let lastStart = if o.paired and o.fragSd > 0: seqLen - o.readLength
                      else: seqLen - nominal
      var lastEnd = 0
      for start in countup(0, lastStart, o.step):
        let length = sampleFragLength(o, rng)
        if start + length <= seqLen:
          yield (start, length)
          lastEnd = start + length
      if o.tail and seqLen >= nominal and lastEnd < seqLen:
        yield (seqLen - nominal, nominal)

proc extract(sequence: string, start, length: int): string =
  let seqLen = sequence.len
  if start + length <= seqLen:
    sequence[start ..< start + length]
  else:
    sequence[start ..< seqLen] & sequence[0 ..< start + length - seqLen]

proc nFraction(s: string): float =
  var n = 0
  for c in s:
    if c == 'N' or c == 'n':
      n += 1
  n / s.len

proc outputExt(fasta, gzip: bool): string =
  result = if fasta: ".fa" else: ".fq"
  if gzip:
    result &= ".gz"

proc shredMain(args: var seq[string], cmdName = "shred"): int =
  let args = docopt("""
  Usage: $CMD$ [options] [<input>...]

  Systematically produce a "shotgun" of input sequences, as single-end or
  paired-end reads. Reads from STDIN if no input is given.

  Tiling:
    -l, --length INT           Read length [default: 100]
    -s, --step INT             Distance between consecutive segment starts [default: 10]
    -x, --coverage FLOAT       Target read coverage: computes --step (overrides -s)
    -f, --frag-len INT         Fragment (insert) length, paired-end only [default: 500]
    --frag-sd FLOAT            Standard deviation of the fragment length, paired-end
                               only; 0 keeps the tiling systematic [default: 0]
    --seed INT                 Random seed used with --frag-sd [default: 42]
    --tail                     Add a final segment anchored to the sequence end
    --circular                 Treat sequences as circular (segments wrap around)
    --amplicon                 Each input sequence is one fragment: R1 is the start,
                               R2 the reverse complement of the end
    --max-n FLOAT              Skip segments with a fraction of N above this [default: 1.0]

  Strand:
    -r, --add-rc               Reverse complement every other segment (= --strand alt)
    --strand STR               One of fwd, rev, alt, both [default: fwd]

  Output (single-end to STDOUT by default):
    -o, --out-prefix STR       Paired-end: write <STR><for-tag>.fq and <STR><rev-tag>.fq
    -1, --out-r1 FILE          Output file (single-end, or R1 with -2, or interleaved with -i)
    -2, --out-r2 FILE          Paired-end: R2 output file
    -i, --interleaved          Paired-end, interleaved (to STDOUT unless -1 is given)
    --for-tag STR              R1 tag used with --out-prefix [default: _R1]
    --rev-tag STR              R2 tag used with --out-prefix [default: _R2]

  Format:
    -q, --quality INT          Constant quality; -1 means FASTA output [default: 40]
    --fasta                    FASTA output (same as -q -1)
    -z, --gzip                 Compress output (implied by filenames ending in .gz)
    --level INT                Gzip compression level, 0-9 [default: 6]
    -t, --threads INT          Compression threads (uses pigz if available) [default: 1]

  Read names:
    -b, --basename             Prepend the file basename to the read name
    --split-basename STRING    Split the file basename at this character [default: .]
    --prefix-separator STRING  Join the basename with the rest of the read name with this [default: _]
    --pair-suffix              Append /1 and /2 to paired read names
    --coords                   Add the origin to the comment as seqname:start-end:strand

  Other:
    -v, --verbose              Verbose output
    -h, --help                 Show this help
    """.replace("$CMD$", cmdName), version=version(cmdName), argv=args)

  let
    outPrefix = optStr(args, "--out-prefix")
    outR1 = optStr(args, "--out-r1")
    outR2 = optStr(args, "--out-r2")
    interleaved = bool(args["--interleaved"])
    quality = optInt(args, "--quality", cmdName)
    fasta = bool(args["--fasta"]) or quality < 0
    gzip = bool(args["--gzip"])
    level = optInt(args, "--level", cmdName)
    threads = optInt(args, "--threads", cmdName)
    basename = bool(args["--basename"])
    separator = $args["--split-basename"]
    joinString = $args["--prefix-separator"]
    pairSuffix = bool(args["--pair-suffix"])
    addCoords = bool(args["--coords"])
    verbose = bool(args["--verbose"])
    quiet = getEnv("SEQFU_QUIET") != ""

  # Output mode
  if outPrefix != "" and (outR1 != "" or outR2 != ""):
    die(cmdName, "--out-prefix cannot be combined with --out-r1/--out-r2")
  if outR2 != "" and outR1 == "":
    die(cmdName, "--out-r2 requires --out-r1")
  if interleaved and (outPrefix != "" or outR2 != ""):
    die(cmdName, "--interleaved writes a single stream: use it alone or with --out-r1")

  var o = ShredOptions(
    readLength: optInt(args, "--length", cmdName),
    fragLength: optInt(args, "--frag-len", cmdName),
    fragSd: optFloat(args, "--frag-sd", cmdName),
    step: optInt(args, "--step", cmdName),
    paired: outPrefix != "" or outR2 != "" or interleaved,
    circular: bool(args["--circular"]),
    tail: bool(args["--tail"]),
    amplicon: bool(args["--amplicon"]),
    maxN: optFloat(args, "--max-n", cmdName))

  let strandStr = ($args["--strand"]).toLowerAscii()
  case strandStr
  of "fwd": o.strand = smFwd
  of "rev": o.strand = smRev
  of "alt": o.strand = smAlt
  of "both": o.strand = smBoth
  else: die(cmdName, "--strand must be one of fwd, rev, alt, both; got: " & strandStr)
  if bool(args["--add-rc"]):
    if o.strand notin {smFwd, smAlt}:
      die(cmdName, "--add-rc is equivalent to --strand alt and conflicts with --strand " & strandStr)
    o.strand = smAlt

  # Parameter checks
  if o.readLength <= 0:
    die(cmdName, "--length must be > 0")
  if o.step <= 0:
    die(cmdName, "--step must be > 0")
  if o.paired and not o.amplicon and o.fragLength < o.readLength:
    die(cmdName, "fragment length (" & $o.fragLength & ") must not be shorter than read length (" & $o.readLength & ")")
  if o.fragSd < 0:
    die(cmdName, "--frag-sd must be >= 0")
  if o.maxN < 0 or o.maxN > 1:
    die(cmdName, "--max-n must be between 0 and 1")
  if o.circular and o.amplicon:
    die(cmdName, "--circular and --amplicon are mutually exclusive")
  if level < 0 or level > 9:
    die(cmdName, "--level must be between 0 and 9")
  if threads < 1:
    die(cmdName, "--threads must be >= 1")
  if not fasta and quality > 93:
    die(cmdName, "--quality must be <= 93")

  let coverageStr = optStr(args, "--coverage")
  if coverageStr != "":
    if o.amplicon:
      die(cmdName, "--coverage cannot be used with --amplicon")
    let coverage = optFloat(args, "--coverage", cmdName)
    if coverage <= 0:
      die(cmdName, "--coverage must be > 0")
    # Bases produced per segment start: one or two reads, one or two strands
    var basesPerStart = float(o.readLength)
    if o.paired: basesPerStart *= 2
    if o.strand == smBoth: basesPerStart *= 2
    o.step = max(1, int(round(basesPerStart / coverage)))

  if verbose:
    if o.fragSd > 0 and not o.paired:
      stderr.writeLine("[", cmdName, "] WARNING: --frag-sd ignored in single-end mode")
    stderr.writeLine("[", cmdName, "] Mode: ", if o.paired: "paired end" else: "single end",
      if o.amplicon: " (amplicon)" elif o.circular: " (circular)" else: "")
    stderr.writeLine("[", cmdName, "] Read length: ", o.readLength)
    if not o.amplicon:
      stderr.writeLine("[", cmdName, "] Step: ", o.step, " (strand: ", strandStr, ")")
    if o.paired and not o.amplicon:
      stderr.writeLine("[", cmdName, "] Fragment length: ", o.fragLength,
        if o.fragSd > 0: " (sd " & $o.fragSd & ")" else: "")

  var inputFiles = newSeq[string]()
  if len(@(args["<input>"])) > 0:
    for f in args["<input>"]:
      if fileExists(f):
        inputFiles.add(f)
      else:
        stderr.writeLine("[", cmdName, "] ERROR: Skipping file <", f, ">: not found.")
  else:
    if not quiet:
      stderr.writeLine("[", cmdName, "] Waiting for sequences from STDIN (Ctrl-C to quit)...")
    inputFiles.add("-")

  # Writers: w1 receives single-end or R1 (or interleaved) records, w2 the R2
  let
    format = if fasta: fxfFasta else: fxfFastq
    splitPairs = o.paired and not interleaved
    path1 = if outPrefix != "": outPrefix & $args["--for-tag"] & outputExt(fasta, gzip)
            else: outR1
    path2 = if outPrefix != "": outPrefix & $args["--rev-tag"] & outputExt(fasta, gzip)
            else: outR2

  proc openWriter(path: string): FastxWriter =
    try:
      fastxWriter(format = format,
        compression = gzip or path.endsWith(".gz"),
        destination = if path == "": stdoutDestination() else: fileDestination(path),
        compressionLevel = level,
        compressionThreads = threads,
        fastaWidth = high(int32))  # never wrap reads
    except CatchableError as e:
      die(cmdName, "cannot open output " & (if path == "": "STDOUT" else: path) & ": " & e.msg)

  var w1 = openWriter(path1)
  var w2: FastxWriter
  if splitPairs:
    w2 = openWriter(path2)
  if verbose and path1 != "":
    stderr.writeLine("[", cmdName, "] Output: ", path1, if splitPairs: ", " & path2 else: "")

  let qualChar = if fasta: ' ' else: qualToChar(quality)
  var
    rng = initRand(optInt(args, "--seed", cmdName))
    totalSegments = 0
    emptySeqs = 0

  proc makeRecord(name, comment, sequence: string): FQRecord =
    FQRecord(name: name, comment: comment, sequence: sequence,
             quality: if fasta: "" else: repeat(qualChar, sequence.len))

  try:
    for inputFile in inputFiles:
      if verbose:
        stderr.writeLine("[", cmdName, "] Processing file: ", inputFile)
      let prefix = if basename: extractFilename(inputFile).split(separator)[0] & joinString
                   else: ""
      try:
        for record in readFQ(inputFile):
          let seqLen = record.sequence.len
          var
            counter = 0
            fragIndex = 0
          for (start, length) in fragments(seqLen, o, rng):
            let fragment = extract(record.sequence, start, length)
            if o.maxN < 1.0 and nFraction(fragment) > o.maxN:
              continue
            fragIndex += 1
            let strands = case o.strand
              of smFwd: @[false]
              of smRev: @[true]
              # odd segments are reversed, as in the original --add-rc
              of smAlt: @[fragIndex mod 2 == 1]
              of smBoth: @[false, true]
            for reverse in strands:
              counter += 1
              let
                oriented = if reverse: seqfuRevCompl(fragment) else: fragment
                name = prefix & record.name & joinString & $counter
                comment = if addCoords:
                            record.name & ":" & $(start + 1) & "-" &
                              $(((start + length - 1) mod seqLen) + 1) & ":" &
                              (if reverse: "-" else: "+")
                          else: ""
                readLen = min(o.readLength, oriented.len)
                r1 = makeRecord(if pairSuffix and o.paired: name & "/1" else: name,
                                comment, oriented[0 ..< readLen])
              w1.writeRecord(r1)
              if o.paired:
                let r2 = makeRecord(if pairSuffix: name & "/2" else: name, comment,
                                    seqfuRevCompl(oriented[oriented.len - readLen ..< oriented.len]))
                if splitPairs: w2.writeRecord(r2)
                else: w1.writeRecord(r2)
          if counter == 0:
            emptySeqs += 1
          totalSegments += counter
      except CatchableError as e:
        die(cmdName, "processing " & inputFile & ": " & e.msg)
  finally:
    w1.close()
    if splitPairs:
      w2.close()

  if emptySeqs > 0 and not quiet:
    stderr.writeLine("[", cmdName, "] WARNING: ", emptySeqs,
      " sequence(s) produced no reads (too short or too many Ns)")
  if verbose:
    stderr.writeLine("[", cmdName, "] ", if o.paired: "Pairs" else: "Reads", " written: ", totalSegments)

proc seqfuShred*(args: var seq[string]): int =
  return shredMain(args, "shred")
