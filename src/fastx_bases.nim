
import readfx
import strformat
import terminaltables
import tables, strutils
import os
import docopt
import ./seqfu_utils
import math
import malebolgia

type FileComposition = ref object
  name: string
  seqs: int
  bases: int
  num_a: int
  num_c: int
  num_g: int
  num_t: int
  num_n: int
  num_other: int
  num_lower: int


type BaseCompOpts = ref object
  basename: bool
  abspath: bool
  raw_counts: bool
  thousands: bool
  nice: bool
  show_uppercase: bool
  digits: int

proc numberToString[T](s: T, opts: BaseCompOpts): string =
  let

    number = if '.' in $s: ($s).split(".")[0]
          else: $s
    
    decim_all = if '.' in $s: "." & ($s).split(".")[1]
            else: ""

    decimals = if len(decim_all) > opts.digits: decim_all[0 .. opts.digits]
            else: decim_all

  if opts.thousands:
    return number.insertSep(',') & decimals
  else:
    return number

proc toComposition(dict: CountTableRef, filename: string, total: int, opts: BaseCompOpts): FileComposition =
  let
    val_A = dict['A']
    val_C = dict['C']
    val_G = dict['G']
    val_T = dict['T']
    val_N = dict['N']
    val_L = dict['L']
  result = FileComposition(
    name: filename,
    bases: total,
    num_a: val_A,
    num_c: val_C,
    num_g: val_G,
    num_t: val_T,
    num_n: val_N,
    num_other: total - val_A - val_C - val_G - val_T - val_N,
    num_lower: val_L
  )

proc fmtFloat*(value      : float,
               opts       : BaseCompOpts,
               thousandSep: string = ",",
               decimalSep : string = "."): string =
    if value != value:
        return "NaN"
    elif value == Inf:
        return "Inf"
    elif value == NegInf:
        return "-Inf"
    
    let
        decimals   = opts.digits
        forceSign  = false #format.find('s') >= 0
        thousands  = opts.thousands
        removeZero = false # format.find('z') >= 0
    
    var valueStr = ""
    
    if decimals >= 0:
        valueStr.formatValue(round(value, decimals), "." & $decimals & "f")
    else:
        valueStr = $value
    
    if valueStr[0] == '-':
        valueStr = valueStr[1 .. ^1]
    
    let
        period  = valueStr.find('.')
        negZero = 1.0 / value == NegInf
        sign    = if value < 0.0 or negZero: "-" elif forceSign: "+" else: ""
    
    var
        integer    = ""
        integerTmp = valueStr[0 .. period - 1]
        decimal    = decimalSep & valueStr[period + 1 .. ^1]
    
    if thousands:
        while true:
            if integerTmp.len > 3:
                integer = thousandSep & integerTmp[^3 .. ^1] & integer
                integerTmp = integerTmp[0 .. ^4]
            else:
                integer = integerTmp & integer
                
                break
    else:
        integer = integerTmp
    
    while removeZero:
        if decimal[^1] == '0':
            decimal = decimal[0 .. ^2]
        else:
            break
    
    if decimal == decimalSep:
        decimal = ""
    
    return sign & integer & decimal

proc pctOf(part, total: int): float =
  # Percentage of `total` that `part` represents; 0.0 for an empty (0-base) file
  # rather than a NaN from 0/0.
  if total == 0: 0.0
  else: float(100 * part) / float(total)

proc toRow(c: FileComposition, opts: BaseCompOpts): seq[string] =
  # 1. Filename
  # 2. Total Bases
  # 3. A
  # 4. C
  # 5. G
  # 6. T
  # 7. N
  # 8. Other
  # 9. GC
  # 10. Uppercase

  result = if opts.abspath: @[absolutePath(c.name)]
           elif opts.basename: @[extractFilename(c.name)]
           else: @[c.name]
  result.add((c.bases).numberToString(opts))
  if opts.raw_counts:
    result.add((c.num_a).numberToString(opts))
    result.add((c.num_c).numberToString(opts))
    result.add((c.num_g).numberToString(opts))
    result.add((c.num_t).numberToString(opts))
    result.add((c.num_n).numberToString(opts))
    result.add((c.num_other).numberToString(opts))
  else:
    result.add(fmtFloat(pctOf(c.num_a, c.bases), opts))
    result.add(fmtFloat(pctOf(c.num_c, c.bases), opts))
    result.add(fmtFloat(pctOf(c.num_g, c.bases), opts))
    result.add(fmtFloat(pctOf(c.num_t, c.bases), opts))
    result.add(fmtFloat(pctOf(c.num_n, c.bases), opts))
    result.add(fmtFloat(pctOf(c.num_other, c.bases), opts))

  result.add(fmtFloat(pctOf(c.num_c + c.num_g, c.bases), opts))

  result.add(fmtFloat(pctOf(c.bases - c.num_lower, c.bases), opts))



proc newDNAtable(): CountTableRef[char] =
  result = newCountTable[char]()

type
  BaseJob = object
    filename: string
    opts: BaseCompOpts
    result: FileComposition

proc processBaseJob(job: ptr BaseJob) {.gcsafe.} =
  {.cast(gcsafe).}:
    var
      total_bases = 0
      counts      = newDNAtable()
    for record in readFQ(job[].filename):
      total_bases += len(record.sequence)
      for base in record.sequence:
        let upperBase = base.toUpperAscii()
        counts.inc(upperBase)
        if base != upperBase:
            counts.inc('L')

    if total_bases == 0:
      stderr.writeLine("Warning: ", job[].filename, " has 0 bases")

    job[].result = counts.toComposition(job[].filename, total_bases, job[].opts)

proc fastx_bases(argv: var seq[string]): int =
    let args = docopt("""
Usage: bases [options] [<inputfile> ...]

Print the DNA bases, and %GC content, in the input files

Options:
  -c, --raw-counts       Print counts and not ratios
  -t, --thousands        Print thousands separator
  -a, --abspath          Print absolute path 
  -b, --basename         Print the basename of the file
  -n, --nice             Print terminal table
  -d, --digits INT       Number of digits to print [default: 2]
  -H, --header           Print header (implied when using --nice)
  --threads INT          Number of worker threads, one per file [default: 1]
  -v, --verbose          Verbose output
  --debug                Debug output
  --help                 Show this help
  """, version=version(), argv=argv)

    verbose       = bool(args["--verbose"])
    var
      files       : seq[string]
      digits      : int
      threads     : int

    try:
      digits = parseInt($args["--digits"])
    except ValueError:
      stderr.writeLine("Error: --digits must be an integer (got '" & $args["--digits"] & "')")
      quit(1)

    try:
      threads = parseInt($args["--threads"])
    except ValueError:
      stderr.writeLine("Error: --threads must be an integer (got '" & $args["--threads"] & "')")
      quit(1)
    if threads < 1:
      stderr.writeLine("Error: --threads must be >= 1 (got ", threads, ")")
      quit(1)

    let
      showHeader    = bool(args["--header"])
      outputTable   = newUnicodeTable()
      headerFields  = @["File", "Bases", "A","C", "G", "T", "N", "Other", "%GC", "Uppercase"]
      raw_counts    = bool(args["--raw-counts"])
      thousands     = bool(args["--thousands"])
      basename      = bool(args["--basename"])
      abspath       = bool(args["--abspath"])
      uppercaseRatio= true
      nice          = bool(args["--nice"])

    if bool(args["--debug"]):
      stderr.writeLine args

    # Sanity check: arguments
    if abspath and basename:
      echo "Error: --abspath and --basename are mutually exclusive"
      quit(1)

    let opts = BaseCompOpts(
      basename: basename,
      abspath: abspath,
      raw_counts: raw_counts,
      thousands: thousands,
      nice: nice,
      show_uppercase: uppercaseRatio,
      digits: digits
    )


    # Check if we have files, otherwise add "-" for STDIN
    if args["<inputfile>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu bases] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      # Check if files exists, if so add to array
      for file in args["<inputfile>"]:
        if (not fileExists(file) or  dirExists(file))and file != "-":
          stderr.writeLine("Skipping ", file, ": not found or not a file")
          continue
        else:
          files.add(file)
    
    
    if showHeader and not nice:
  
      echo fmt"#Filename{'\t'}Total{'\t'}A{'\t'}C{'\t'}G{'\t'}T{'\t'}N{'\t'}Other{'\t'}%GC{'\t'}Uppercase"


    
    if verbose:
      stderr.writeLine("Startup: ", files.len(), " files")

    var jobs = newSeq[BaseJob](files.len)
    for i, filename in files:
      jobs[i] = BaseJob(filename: filename, opts: opts, result: nil)

    # Parallelize per-file: each file is independent, so this is safe as long as
    # there's more than one file and STDIN (readable only once) isn't among them.
    let canParallel = threads > 1 and jobs.len > 1 and ("-" notin files)

    if canParallel:
      if verbose:
        stderr.writeLine("Processing ", jobs.len, " files using up to ", min(threads, ThreadPoolSize), " threads")
      let parallelChunk = min(threads, ThreadPoolSize)
      var m = createMaster()
      var start = 0
      while start < jobs.len:
        let stopAt = min(start + parallelChunk, jobs.len)
        m.awaitAll:
          for i in start ..< stopAt:
            m.spawn processBaseJob(addr jobs[i])
        start = stopAt
    else:
      if threads > 1 and ("-" in files) and verbose:
        stderr.writeLine("INFO: Disabling parallel processing because input includes STDIN ('-').")
      for i in 0 ..< jobs.len:
        if verbose:
          stderr.writeLine("Parsing: ", jobs[i].filename)
        processBaseJob(addr jobs[i])

    var
      compositions = newSeq[FileComposition](jobs.len)
    for i in 0 ..< jobs.len:
      compositions[i] = jobs[i].result

    # HEADER

    if nice:
      # Init table
      outputTable.separateRows = false
      outputTable.setHeaders(headerFields)
      # Populate table
      for comp in compositions:
        outputTable.addRow(comp.toRow(opts))
      # Print table
      outputTable.printTable()
    else:
      for comp in compositions:
        echo (comp.toRow(opts)).join("\t")
      
