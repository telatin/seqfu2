import readfq
import tables, strutils
from os import fileExists, createDir, `/`, splitFile
import docopt
import ./seqfu_utils



type
  ListOptions = object
    withComments : bool
    partialMatch : bool
    minLength    : int

proc getListFromFile(filename: string, opts: ListOptions): Table[string, int] =

  if not fileExists(filename):
    stderr.writeLine("ERROR: List file not found: ", filename)
    quit(1)

  for line in lines filename:
    var
      name = line

    if line.len == 0 or line.startsWith("#"):
      continue
    # remove first char if it is ">" or "@"
    if line[0] == '>' or line[0] == '@':
      name = line[1 .. ^1]

    if name.len == 0:
      continue

    # remove trailing spaces or tabs
    var
      stripLen = 0
      pos = len(name) - 1
    while name[pos] == ' ' or name[pos] == '\t':
      stripLen += 1
      pos -= 1

    if stripLen > 0:
      name = name[0 ..< len(name) - stripLen]

    if not opts.withComments:
      name = ( name.split(' ')[0] ).split('\t')[0]
    else:
      var initialPart = ""
      for i, c in name:
        if len(initialPart) > 0 and (c == ' ' or c == '\t'):
          name = initialPart & " " & name[i+1 .. ^1]
          break
        initialPart &= c

    if len(name) < opts.minLength:
      continue
    result[name] = 0


proc getOutSuffix(fastxFile: string): string =
  ## Derive uncompressed output suffix from an input filename.
  ## Strips .gz first, then maps known extensions to .fastq or .fasta.
  ## Returns "" when the extension is not recognised (caller detects from content).
  var f = fastxFile.toLowerAscii()
  if f.endsWith(".gz"):
    f = f[0 ..< f.len - 3]
  if   f.endsWith(".fastq") or f.endsWith(".fq"):                       return ".fastq"
  elif f.endsWith(".fasta") or f.endsWith(".fa") or
       f.endsWith(".fna")   or f.endsWith(".faa"):                       return ".fasta"
  else:                                                                   return ""


proc writeRecord(f: File, record: FQRecord) =
  f.writeLine($record)


proc matchRecord(seqList: var Table[string, int],
                 sequenceName: string,
                 partialMatch: bool): bool =
  ## Returns true if sequenceName matches any entry in seqList,
  ## and increments the count(s) for matched entries.
  if partialMatch:
    for listEntry, count in seqList.mpairs:
      if listEntry in sequenceName:
        count += 1
        result = true        # keep iterating to count all matching entries
  else:
    if sequenceName in seqList:
      seqList[sequenceName] += 1
      result = true


proc reportCounts(seqList: Table[string, int], label: string = "") =
  var found = 0
  stderr.writeLine("# SEQUENCES REPORT", if label.len > 0: " (" & label & ")" else: "")
  for name, counts in seqList:
    stderr.writeLine("# Sequence '", name, "' found ", counts, " times")
    if counts > 0:
      found += 1
  stderr.writeLine("Total sequences found: ", found, "/", len(seqList))


proc checkStrict(seqList: Table[string, int], label: string = ""): bool =
  ## Returns true if any listed name was never found.
  for name, counts in seqList:
    if counts == 0:
      let loc = if label.len > 0: " (list: " & label & ")" else: ""
      stderr.writeLine("ERROR: Listed name not found in input: '", name, "'", loc)
      result = true


proc fastx_list(argv: var seq[string]): int =
  let args = docopt("""
Usage: list [options] <LIST> <FASTQ>...
       list [options] --outdir <DIR> [--lists <LIST>]... <FASTX>

Classic mode: print sequences from <FASTQ> whose names appear in <LIST>.
Multi mode:   for each --lists file, write matching sequences to a file in
              <DIR> named <listbasename>.<input_extension>.

List files may contain leading ">" or "@" characters.  Duplicated entries
within a list are ignored.  Lines starting with "#" and blank lines are skipped.

Options:
  -c, --with-comments    Include comments when matching sequence names
  -p, --partial-match    Match list entries as substrings of sequence names
  -m, --min-len INT      Skip list entries shorter than INT [default: 1]
  -s, --strict           Exit with error if any listed name was not found
  -v, --verbose          Verbose output
  -r, --report           Print per-list report of found sequences to stderr
  --lists <LIST>         List file for multi-output mode (repeat for each list)
  --outdir <DIR>         Output directory for multi-output mode
  -f, --force            Overwrite existing output files
  --help                 Show this help

  """, version=version(), argv=argv)

  verbose = args["--verbose"]

  let opts = ListOptions(
    withComments : args["--with-comments"],
    partialMatch : args["--partial-match"],
    minLength    : parseInt($args["--min-len"])
  )

  # ── Multi-output mode ──────────────────────────────────────────────────────
  if args["--outdir"]:
    let listFiles = @(args["--lists"])
    let fastxFile = $args["<FASTX>"]
    let outdir    = $args["--outdir"]
    let force     = args["--force"]

    if listFiles.len == 0:
      stderr.writeLine("ERROR: --outdir requires at least one --lists <LIST> argument.")
      return 1

    createDir(outdir)

    var tables   : seq[Table[string, int]] = @[]
    var basenames: seq[string]             = @[]
    for lf in listFiles:
      tables.add(getListFromFile(lf, opts))
      basenames.add(splitFile(lf).name)

    if verbose:
      stderr.writeLine("Lists loaded: ", listFiles.len)
      for i, lf in listFiles:
        stderr.writeLine("  ", lf, ": ", len(tables[i]), " entries")

    if not fileExists(fastxFile) and fastxFile != "-":
      stderr.writeLine("ERROR: File not found: ", fastxFile)
      return 1

    # Determine output suffix from input filename; "" means detect from content.
    var suffix = if fastxFile == "-": "" else: getOutSuffix(fastxFile)

    var outFiles   : seq[File] = newSeq[File](listFiles.len)
    var filesOpened             = false

    for record in readfq(fastxFile):
      # Open output files on first record if suffix wasn't known upfront.
      if not filesOpened:
        if suffix == "":
          suffix = if record.quality.len > 0: ".fastq" else: ".fasta"
        for i, base in basenames:
          let path = outdir / (base & suffix)
          if fileExists(path) and not force:
            stderr.writeLine("ERROR: Output file already exists (use --force to overwrite): ", path)
            for j in 0 ..< i:
              outFiles[j].close()
            return 1
          outFiles[i] = open(path, fmWrite)
        filesOpened = true

      let seqName = if opts.withComments and record.comment.len > 0:
                      record.name & " " & record.comment
                    else: record.name

      for i in 0 ..< tables.len:
        let matched = matchRecord(tables[i], seqName, opts.partialMatch)
        if matched:
          writeRecord(outFiles[i], record)

    for i in 0 ..< outFiles.len:
      if not outFiles[i].isNil:
        outFiles[i].close()

    var anyMissing = false
    for i, table in tables:
      if args["--report"]:
        reportCounts(table, listFiles[i])
      if args["--strict"]:
        if checkStrict(table, listFiles[i]):
          anyMissing = true

    if anyMissing:
      return 1
    return 0

  # ── Classic single-list mode ───────────────────────────────────────────────
  var sequenceList = getListFromFile($args["<LIST>"], opts)

  if verbose:
    stderr.writeLine("List loaded: ", len(sequenceList))
  if len(@(args["<FASTQ>"])) == 0:
    stderr.writeLine("No files specified. Use '-' to read STDIN, --help for help.")

  for file in @(args["<FASTQ>"]):
    if not fileExists(file) and file != "-":
      stderr.writeLine("ERROR: File not found: ", file)
      continue

    for record in readfq(file):
      let seqName = if opts.withComments and record.comment.len > 0:
                      record.name & " " & record.comment
                    else: record.name

      let matched = matchRecord(sequenceList, seqName, opts.partialMatch)
      if matched:
        echo record

  if args["--report"]:
    reportCounts(sequenceList)

  if args["--strict"]:
    if checkStrict(sequenceList):
      return 1

  return 0
