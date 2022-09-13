
import readfq
import strformat
import terminaltables
import tables, strutils
from os import fileExists,  dirExists
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
  ratio_gc: float
  ratio_upper: float


type BaseCompOpts = ref object
  basename: bool
  abspath: bool
  raw_counts: bool
  thousands: bool
  nice: bool
  show_uppercase: bool
  digits: int
proc `$`(comp: FileComposition): string =
  return fmt"{comp.bases}{'\t'}{comp.num_a}{'\t'}{comp.num_c}{'\t'}{comp.num_g}{'\t'}{comp.num_t}{'\t'}{comp.num_n}{'\t'}{comp.num_other}{'\t'}{comp.num_lower}{'\t'}{comp.ratio_gc}{'\t'}{comp.ratio_upper}"

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
  result = FileComposition(
    name: filename,
    bases: total,
    num_a: dict['A'],
    num_c: dict['C'],
    num_g: dict['G'],
    num_t: dict['T'],
    num_n: dict['N'],
    num_other: total - dict['A'] - dict['C'] - dict['G'] - dict['T'] - dict['N'],
    num_lower: dict['L'],
    ratio_gc: float(dict['G'] + dict['C']) / float(total),
    ratio_upper: float(total - dict['L']) / float(total)
  )

proc splitToSeq(tabbedStr, filename: string): seq[string] =
  # Split a string with tabs to a sequence
  result = @[filename]
  for c in tabbedStr.split("\t"):
    result.add($c)
  if len(result) < 10:
    result.add("--")

proc toString(c: CountTableRef[char], raw: bool, t, u: bool): string =
  var
    bases = 0
    normal = 0
    bases_array = newSeq[string]()
  for k, v in c:
    bases += v

  let
    lowerRaw = if 'L' in c: c['L']
              else: 0
  
  bases -= lowerRaw

  let
    display_total_bases = if t:  ($bases).insertSep(',')
                          else: $bases

  let cg = if 'C' in c and 'G' in c: c['C'] + c['G']
           elif 'C' in c: c['C']
           elif 'G' in c: c['G']
           else: 0
    


  for base in @['A', 'C', 'G', 'T', 'N']:
      let
        count = if base in c: c[base]
                else: 0
      normal += count
      if raw:
        if t:
          bases_array.add($( ($count).insertSep(',') ))
        else:
          bases_array.add($count)
      else:
        bases_array.add(fmt"{float(100 * c[base] / bases):.2f}")
  # OTHER
  let 
    other = bases - normal
  if raw:
    if t:
      bases_array.add($( ($other).insertSep(',') ))
    else:
      bases_array.add($other)
  else:
    bases_array.add(fmt"{float(100 * other / bases):.2f}")

  # GC
  let
    gc_ratio = if cg > 0: float(100 * cg / bases)
               else: 0.0
  
  var caseRatio = ""
  if u:
    let 
      upperRatio = float(100 * (bases - lowerRaw) / bases)
    caseRatio = fmt"{'\t'}{float(upperRatio):.2f}"
  result = fmt"{display_total_bases}{'\t'}{bases_array[0]}{'\t'}{bases_array[1]}{'\t'}{bases_array[2]}{'\t'}{bases_array[3]}{'\t'}{bases_array[4]}{'\t'}{bases_array[5]}{'\t'}{gc_ratio:.2f}{caseRatio}"
    
    

  return

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
  result = @[c.name]
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
  result['A'] = 0
  result['C'] = 0
  result['G'] = 0
  result['T'] = 0
  result['N'] = 0
  result['L'] = 0
  return

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
          echoVerbose(file, verbose)
          files.add(file)
    
    
    if showHeader and not nice:
  
      echo fmt"#Filename{'\t'}Total{'\t'}A{'\t'}C{'\t'}G{'\t'}T{'\t'}N{'\t'}Other{'\t'}%GC{'\t'}Uppercase"


    
    var
      countTables = newTable[string, FileComposition]()

    # ITERATE: files
    for filename in files:

      let displayname = if not basename and not abspath: filename
                        elif basename: extractFilename(filename) 
                        else: absolutePath(filename)
      var 
        total_bases  = 0
        #total_seqs   = 0
        counts       = newDNAtable()
      
      # ITERATE: records
      for record in readfq(filename):
        #total_seqs += 1
        total_bases += len(record.sequence)
        
        for base in record.sequence:
          counts.inc(base.toUpperAscii())
          if base != base.toUpperAscii():
              counts.inc('L')
      
      let
        comp : FileComposition = counts.toComposition(filename, total_bases, opts)
      countTables[displayname] = comp

      
    
    # HEADER

    if nice:
      # Init table
      outputTable.separateRows = false
      outputTable.setHeaders(headerFields)
      # Populate table
      for filename, comp in countTables.pairs():
        outputTable.addRow(comp.toRow(opts))
      # Print table
      outputTable.printTable()
    else:
      for filename, comp in countTables.pairs():
        echo (comp.toRow(opts)).join("\t")
      