# tofasta.nim - Convert various sequence formats to FASTA
# Integrated into SeqFu suite

import tables, strutils, sets, hashes
from os import fileExists, getTempDir, `/`, removeFile
import docopt
import ./seqfu_utils
import ./lib/klib

type
  Format = enum
    fmtUnknown, fmtGenBank, fmtEMBL, fmtGFF, fmtClustal,
    fmtStockholm, fmtFasta, fmtFastq, fmtGFA

  ToFastaOptions = object
    replaceIupac: bool
    lowercase: bool
    uppercase: bool
    outputFile: string
    verbose: bool

  Entry = object
    id: string
    seq: string

# Character mapping table for transformations
var mapTbl: array[256, char]

proc buildMap(opt: ToFastaOptions) =
  # Initialize identity mapping
  for i in 0..255:
    mapTbl[i] = chr(i)

  # Replace non-IUPAC characters with N
  if opt.replaceIupac:
    for i in 0..255:
      let c = chr(i)
      if c in {'\n', '\r', '-'}: continue
      let u = c.toUpperAscii
      if u notin {'A', 'T', 'G', 'C', 'N'}:
        mapTbl[i] = 'N'

  # Apply case transformations
  if opt.lowercase:
    for i in 0..255:
      mapTbl[i] = mapTbl[i].toLowerAscii
  if opt.uppercase:
    for i in 0..255:
      mapTbl[i] = mapTbl[i].toUpperAscii

proc purifySeq(s: string): string =
  result = newString(s.len)
  for i in 0..<s.len:
    result[i] = mapTbl[ord(s[i])]

proc isBlankLine(s: string): bool =
  for c in s:
    if c notin {' ', '\t'}: return false
  return true

proc detectFormat(line: string): Format =
  if line.len == 0: return fmtUnknown
  if line.len > 5 and line.startsWith("LOCUS") and line[5] in {' ', '\t'}: return fmtGenBank
  if line.len > 2 and line.startsWith("ID") and line[2] in {' ', '\t'}: return fmtEMBL
  if line.startsWith("##gff"): return fmtGFF
  if line.startsWith("# STOCKHOLM"): return fmtStockholm
  if line.startsWith("CLUST") or line.startsWith("MUSCL"): return fmtClustal
  if line[0] == '>': return fmtFasta
  if line[0] == '@': return fmtFastq
  if line.len >= 2 and line[0] in {'A'..'Z'} and line[1] == '\t': return fmtGFA
  return fmtUnknown

proc parseFasta(f: var Bufio[GzFile], firstLine: string, output: File): int =
  var count = 0
  var line: string

  # Handle first line
  if not isBlankLine(firstLine):
    if firstLine[0] == '>':
      output.writeLine(firstLine)
      count.inc
    else:
      output.writeLine(purifySeq(firstLine))

  # Read remaining lines
  while f.readLine(line):
    if isBlankLine(line): continue
    if line[0] == '>':
      output.writeLine(line)
      count.inc
    else:
      output.writeLine(purifySeq(line))

  return count

proc parseFastq(f: var Bufio[GzFile], firstLine: string, output: File): int =
  var count = 0
  var l1 = firstLine

  while true:
    var l2, l3, l4: string
    if not f.readLine(l2): break
    if not f.readLine(l3): break
    if not f.readLine(l4): break

    if l1.len < 1 or l1[0] != '@':
      stderr.writeLine("ERROR: FASTQ record does not start with '@'")
      quit(1)

    output.write('>')
    output.writeLine(l1[1..^1])
    output.writeLine(purifySeq(l2))
    count.inc

    if not f.readLine(l1): break

  return count

proc parseGFF(f: var Bufio[GzFile], firstLine: string, output: File): int =
  var count = 0
  var atSeq = false
  var line: string

  if firstLine[0] == '>':
    atSeq = true
    output.writeLine(firstLine)
    count.inc

  while f.readLine(line):
    if line[0] == '>':
      atSeq = true
      output.writeLine(line)
      count.inc
    elif atSeq:
      output.writeLine(purifySeq(line))

  return count

proc parseGFA(f: var Bufio[GzFile], firstLine: string, output: File): int =
  var count = 0

  proc handleLine(ln: string) =
    if ln.len < 2 or ln[0] != 'S' or ln[1] != '\t': return

    let fields = ln.split('\t')
    if fields.len < 3: return

    let name = fields[1].strip()
    let sequence = fields[2].strip()

    output.write('>')
    output.writeLine(name)
    output.writeLine(purifySeq(sequence))
    count.inc

  handleLine(firstLine)

  var line: string
  while f.readLine(line):
    handleLine(line)

  return count

proc parseGenBank(f: var Bufio[GzFile], firstLine: string, output: File): int =
  var count = 0
  var acc = "UNKNOWN"
  var inSeq = false
  var printedHeader = false
  var seqBuffer = ""

  proc printHeaderIfNeeded() =
    if not printedHeader:
      output.write('>')
      output.writeLine(acc)
      printedHeader = true

  proc finishEntry() =
    if printedHeader and seqBuffer.len > 0:
      output.writeLine(purifySeq(seqBuffer))
      count.inc
    acc = "UNKNOWN"
    inSeq = false
    printedHeader = false
    seqBuffer = ""

  proc handleLine(ln: string) =
    if ln.len >= 2 and ln[0] == '/' and ln[1] == '/':
      finishEntry()
      return

    if not inSeq:
      if ln.startsWith("LOCUS") and ln.len > 5 and ln[5] in {' ', '\t'}:
        let parts = ln[6..^1].strip().split(Whitespace)
        if parts.len > 0:
          acc = parts[0]
        return
      if ln.startsWith("ORIGIN"):
        inSeq = true
        printHeaderIfNeeded()
        return
    else:
      # In sequence section, extract sequence characters (skip numbers and spaces)
      for i, c in ln:
        if i < 10: continue  # Skip line number prefix
        if c notin {' ', '\t', '0'..'9'}:
          seqBuffer.add(c)

  handleLine(firstLine)

  var line: string
  while f.readLine(line):
    handleLine(line)

  # Finish last entry if needed
  finishEntry()

  return count

proc parseEMBL(f: var Bufio[GzFile], firstLine: string, output: File): int =
  var count = 0
  var acc = "UNKNOWN"
  var inSeq = false
  var printedHeader = false
  var seqBuffer = ""

  proc printHeaderIfNeeded() =
    if not printedHeader:
      output.write('>')
      output.writeLine(acc)
      printedHeader = true

  proc finishEntry() =
    if printedHeader and seqBuffer.len > 0:
      output.writeLine(purifySeq(seqBuffer))
      count.inc
    acc = "UNKNOWN"
    inSeq = false
    printedHeader = false
    seqBuffer = ""

  proc handleLine(ln: string) =
    if ln.len >= 2 and ln[0] == '/' and ln[1] == '/':
      finishEntry()
      return

    if not inSeq:
      if ln.startsWith("ID") and ln.len > 2 and ln[2] in {' ', '\t'}:
        let parts = ln[3..^1].strip().split({';', ' ', '\t'})
        if parts.len > 0:
          acc = parts[0].strip()
        return
      if ln.startsWith("SQ") and ln.len > 2 and ln[2] in {' ', '\t'}:
        inSeq = true
        printHeaderIfNeeded()
        return
    else:
      # Extract sequence characters (skip spaces, tabs, and numbers)
      for c in ln:
        if c notin {' ', '\t', '0'..'9'}:
          seqBuffer.add(c)

  handleLine(firstLine)

  var line: string
  while f.readLine(line):
    handleLine(line)

  # Finish last entry if needed
  finishEntry()

  return count

proc parseClustal(f: var Bufio[GzFile], firstLine: string, output: File): int =
  var entries: seq[Entry] = @[]
  var idMap: Table[string, int] = initTable[string, int]()

  var line: string
  while f.readLine(line):
    let ln = line.strip()
    if ln.len == 0: continue

    let fields = ln.splitWhitespace()
    if fields.len < 2: continue

    let id = fields[0]
    let sequence = fields[1]

    # Validate sequence (only letters and gaps)
    var valid = true
    for c in sequence:
      if c.toUpperAscii notin {'A'..'Z', '-'}:
        valid = false
        break
    if not valid: continue

    # Check for trailing numbers (Clustal format allows position numbers)
    if fields.len == 3:
      var isNumber = true
      for c in fields[2]:
        if c notin {'0'..'9'}:
          isNumber = false
          break
      if not isNumber: continue
    elif fields.len > 3: continue

    # Add or append to entry
    if id in idMap:
      let idx = idMap[id]
      entries[idx].seq.add(sequence)
    else:
      idMap[id] = entries.len
      entries.add(Entry(id: id, seq: sequence))

  # Output all entries
  for e in entries:
    output.write('>')
    output.writeLine(e.id)
    output.writeLine(purifySeq(e.seq))

  return entries.len

proc parseStockholm(f: var Bufio[GzFile], firstLine: string, output: File): int =
  var entries: seq[Entry] = @[]
  var idMap: Table[string, int] = initTable[string, int]()

  var line: string
  while f.readLine(line):
    let ln = line.strip()
    if ln.len == 0: continue
    if ln[0] == '#': continue
    if ln.len >= 2 and ln[0] == '/' and ln[1] == '/': break

    let fields = ln.splitWhitespace()
    if fields.len < 2: continue

    let id = fields[0]
    var sequence = fields[1]

    # Validate sequence
    var valid = true
    for c in sequence:
      if c.toUpperAscii notin {'A'..'Z', '.', '-'}:
        valid = false
        break
    if not valid: continue

    # Check for trailing numbers (Stockholm format allows position numbers)
    if fields.len == 3:
      var isNumber = true
      for c in fields[2]:
        if c notin {'0'..'9'}:
          isNumber = false
          break
      if not isNumber: continue
    elif fields.len > 3: continue

    # Convert '.' to '-' (Stockholm convention)
    sequence = sequence.replace('.', '-')

    # Add or append to entry
    if id in idMap:
      let idx = idMap[id]
      entries[idx].seq.add(sequence)
    else:
      idMap[id] = entries.len
      entries.add(Entry(id: id, seq: sequence))

  # Output all entries
  for e in entries:
    output.write('>')
    output.writeLine(e.id)
    output.writeLine(purifySeq(e.seq))

  return entries.len

proc processFile(filename: string, opt: ToFastaOptions, output: File, seenIds: var HashSet[string]): int =
  if not fileExists(filename):
    stderr.writeLine("ERROR: File not found: ", filename)
    quit(1)

  if opt.verbose:
    stderr.writeLine("Processing: ", filename)

  var f: Bufio[GzFile]
  discard f.open(filename)

  var firstLine: string
  if not f.readLine(firstLine):
    discard f.close()
    stderr.writeLine("ERROR: File appears to be empty: ", filename)
    quit(1)

  let fmt = detectFormat(firstLine)
  var nseq = 0

  # Store output temporarily to check for duplicate IDs before writing
  var tempOutput: string = ""
  var tempFile: File
  var tempFilePath: string = ""
  if opt.outputFile != "":
    # Create temporary file
    tempFilePath = getTempDir() / "seqfu_tofasta_temp_" & $hash(filename).abs()
    tempFile = open(tempFilePath, fmWrite)
  else:
    tempFile = output

  case fmt
  of fmtGenBank:
    if opt.verbose: stderr.writeLine("  Format: GenBank")
    nseq = parseGenBank(f, firstLine, tempFile)
  of fmtEMBL:
    if opt.verbose: stderr.writeLine("  Format: EMBL")
    nseq = parseEMBL(f, firstLine, tempFile)
  of fmtGFF:
    if opt.verbose: stderr.writeLine("  Format: GFF")
    nseq = parseGFF(f, firstLine, tempFile)
  of fmtClustal:
    if opt.verbose: stderr.writeLine("  Format: Clustal")
    nseq = parseClustal(f, firstLine, tempFile)
  of fmtStockholm:
    if opt.verbose: stderr.writeLine("  Format: Stockholm")
    nseq = parseStockholm(f, firstLine, tempFile)
  of fmtFasta:
    if opt.verbose: stderr.writeLine("  Format: FASTA")
    nseq = parseFasta(f, firstLine, tempFile)
  of fmtFastq:
    if opt.verbose: stderr.writeLine("  Format: FASTQ")
    nseq = parseFastq(f, firstLine, tempFile)
  of fmtGFA:
    if opt.verbose: stderr.writeLine("  Format: GFA")
    nseq = parseGFA(f, firstLine, tempFile)
  else:
    discard f.close()
    stderr.writeLine("ERROR: Unknown or unsupported format in file: ", filename)
    quit(1)

  discard f.close()

  # If writing to output file, check for duplicates
  if opt.outputFile != "":
    tempFile.close()
    tempFile = open(tempFilePath, fmRead)

    var line: string
    while tempFile.readLine(line):
      if line.len > 0 and line[0] == '>':
        let id = line[1..^1].split(Whitespace)[0]
        if id in seenIds:
          tempFile.close()
          try:
            removeFile(tempFilePath)
          except:
            discard
          stderr.writeLine("ERROR: Duplicate sequence ID found: ", id)
          stderr.writeLine("  First occurrence in a previous file")
          stderr.writeLine("  Second occurrence in: ", filename)
          quit(1)
        seenIds.incl(id)
      output.writeLine(line)

    tempFile.close()
    # Clean up temporary file
    try:
      removeFile(tempFilePath)
    except:
      discard

  if opt.verbose:
    stderr.writeLine("  Sequences: ", nseq)

  if nseq == 0:
    stderr.writeLine("ERROR: No sequences found in file: ", filename)
    quit(1)

  return nseq

proc tofasta*(argv: var seq[string]): int =
  let args = docopt("""
Usage: tofasta [options] <inputfile>...

Convert various sequence formats to FASTA format.

Supported formats:
  - FASTA, FASTQ (Sanger, Illumina, Solexa)
  - GenBank, EMBL
  - GFF (with embedded sequences)
  - GFA (Graphical Fragment Assembly)
  - Clustal, Stockholm (multiple sequence alignments)

Options:
  -n, --replace-iupac    Replace non-IUPAC characters with 'N'
  -l, --to-lowercase     Convert sequences to lowercase
  -u, --to-uppercase     Convert sequences to uppercase
  -o, --output FILE      Write output to FILE (default: stdout)
                         Note: checks for duplicate IDs across all files
  -v, --verbose          Print progress information to stderr
  -h, --help             Show this help

Notes:
  - Input files can be gzip compressed (.gz)
  - When using -o/--output, duplicate sequence IDs will cause an error
  - Without -o/--output, sequences are written to stdout
  - Use only one of -l or -u (uppercase takes precedence)

  """, version=version(), argv=argv)

  let opt = ToFastaOptions(
    replaceIupac: bool(args["--replace-iupac"]),
    lowercase: bool(args["--to-lowercase"]),
    uppercase: bool(args["--to-uppercase"]),
    outputFile: $args["--output"],
    verbose: bool(args["--verbose"])
  )

  # Check conflicting options
  if opt.lowercase and opt.uppercase:
    stderr.writeLine("WARNING: Both --to-lowercase and --to-uppercase specified; using uppercase")

  # Build character mapping table
  buildMap(opt)

  # Determine output
  var output: File
  if opt.outputFile != "nil" and opt.outputFile != "":
    try:
      output = open(opt.outputFile, fmWrite)
    except:
      stderr.writeLine("ERROR: Cannot open output file: ", opt.outputFile)
      quit(1)
  else:
    output = stdout

  # Process all files
  var totalSeqs = 0
  var seenIds = initHashSet[string]()

  for filename in args["<inputfile>"]:
    totalSeqs += processFile($filename, opt, output, seenIds)

  # Close output if it's a file
  if opt.outputFile != "nil" and opt.outputFile != "":
    output.close()

  if opt.verbose:
    stderr.writeLine("Done. Total sequences: ", totalSeqs)

  return 0
