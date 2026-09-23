
import readfx
import strformat
import terminaltables
import tables, strutils
import os
import docopt
import ./seqfu_utils
import math

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
    result.add(fmtFloat(float(100 * c.num_a / c.bases), opts))
    result.add(fmtFloat(float(100 * c.num_c / c.bases), opts))
    result.add(fmtFloat(float(100 * c.num_g / c.bases), opts))
    result.add(fmtFloat(float(100 * c.num_t / c.bases), opts))
    result.add(fmtFloat(float(100 * c.num_n / c.bases), opts))
    result.add(fmtFloat(float(100 * c.num_other / c.bases), opts))
  
  result.add(fmtFloat(float(100 * (c.num_c + c.num_g) / c.bases), opts))
  
  result.add(fmtFloat(float(100 * (c.bases - c.num_lower) / c.bases), opts))



proc newDNAtable(): CountTableRef[char] =
  result = newCountTable[char]()

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
  -H, --header           Print header
  -v, --verbose          Verbose output
  --debug                Debug output
  --help                 Show this help
  """, version=version(), argv=argv)

    verbose       = bool(args["--verbose"])
    var
      files       : seq[string]  

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
      digits        = parseInt($args["--digits"])
    
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


    
    var
      compositions = newSeq[FileComposition]()

    if verbose:
      stderr.writeLine("Startup: ", files.len(), " files")
    # ITERATE: files
    for filename in files:
      var
        total_bases  = 0
        #total_seqs   = 0
        counts       = newDNAtable()

      if verbose:
        stderr.writeLine("Parsing: ", filename)
      # ITERATE: records
      for record in readFQ(filename):
        #total_seqs += 1
        total_bases += len(record.sequence)

        for base in record.sequence:
          let upperBase = base.toUpperAscii()
          counts.inc(upperBase)
          if base != upperBase:
              counts.inc('L')

      compositions.add(counts.toComposition(filename, total_bases, opts))



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
      
