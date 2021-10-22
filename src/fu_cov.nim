import klib
 
import docopt
import strutils
import stats
import strformat
import os
import algorithm
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "pre-release"

let
  programName = "fu-cov"
#[
   extract contigs by coverage

  0.4   Transition to docopt
  0.3.1 Bug fixes, improved statistics
  0.3   Added in memory sorting
  0.2   Added statistics
]#


# Chars in numbers (floating)
let nums = @['0','1','2','3','4','5','6','7','8','9','0','.']
# Coverage strings in assembly outputs (spades, unicycler, megahit, shovill, skesa)
let prefixes = @["cov=", "multi=", "cov_", "depth="]

# Contig data
type
    ContigInfo = tuple[name: string, comment: string, cov: float, length: int, sequence: string]
var
  covStats: RunningStat
  lenStats: RunningStat
  ctgData = newSeq[ContigInfo]()


proc rev[T](xs: openarray[T]): seq[T] =
  result = newSeq[T](xs.len)
  for i, x in xs:
    #result[^i-1] = x # or:
    result[xs.high-i] = x

 
 
proc getNumberAfterPos(s: string, pos: int): float =
  var ans = ""
  for i in pos .. s.high:
    if s[i] notin nums:
      break
    ans.add(s[i])
  return parseFloat(ans)

proc getCovFromString(s: string): float =
  for i in 0 .. s.high:
    for prefix in prefixes:
      if i + len(prefix) >= s.high:
        break
      if s[i ..< i + len(prefix)] == prefix:
        return getNumberAfterPos(s, i + len(prefix))
  return -1



proc main(args: var seq[string]): int =
  let args = docopt("""
  fu-cov

  Extract contigs using coverage data from the assembler

  Usage: 
  fu-cov [options] [<assembly-file>...]

  Options:
    -c, --min-cov FLOAT    Minimum coverage [default: 0.0]
    -x, --max-cov FLOAT    Maximum coverage [default: 0.0]
    -l, --min-len INT      Minimum contig length [default: 0]
    -y, --max-len INT      Maximum contig length [default: 0]
    -t, --top INT          Print the first TOP sequences when using --sort [default: 0] 
    -s, --sort             Store contigs in memory and sort them by descending coverage
    --verbose              Print verbose log
    --help                 Show help
  """, version=NimblePkgVersion, argv=commandLineParams())

  var
    skip_hi_cov = 0
    skip_lo_cov = 0
    skip_short  = 0
    skip_long   = 0
    bases_printed = 0
    total_bases = 0
    covTable    = newSeq[ContigInfo]()

    optmincov: float
    optmaxcov: float
    optminlen: int
    optmaxlen: int
    printtop: int

  try:
    optmincov = parseFloat($args["--min-cov"])
    optmaxcov = parseFloat($args["--max-cov"])
  except:
    stderr.writeLine("Error: invalid arguments. Minimum and maximum coverage must be float: ", $args["--min-cov"], ",", $args["--max-cov"])
    return 1

  try:
    optminlen = parseInt($args["--min-len"])
    optmaxlen = parseInt($args["--max-len"])
    printtop    = parseInt($args["--top"])
  except:
    stderr.writeLine("Error: invalid arguments. Minimum and maximum len must be int: ", $args["--min-len"], ",", $args["--max-len"])
    return 1

  try:
    discard len(@(args["<assembly-file>"]))
  except Exception as e:
    stderr.writeLine("Error: parsing files. ", e.msg)
    return 1
    

  try:



    if len(@(args["<assembly-file>"])) == 0:
      echo "Missing argument: input file (type -h for more info)"
      #if not $args["help == true:
      #  echo "Type --help for more info."
      quit(0)

  
    var
      c  = 0      # total count of sequences
      pf = 0      # passing filters
      ff = 0      # parsed files
    for filename in args["<assembly-file>"]:
      if not fileExists(filename):
        echo "FATAL ERROR: File ", filename, " not found."
        quit(1)

      var f = xopen[GzFile](filename)
      defer: f.close()
      var r: FastxRecord
      if args["--verbose"]:
        stderr.writeLine "Reading ", filename

      ff += 1
      # Prse FASTX
      #var match: array[1, string]


      while f.readFastx(r):
        c+=1
        total_bases += len(r.seq)
        lenStats.push(len(r.seq))
        var cov = getCovFromString(r.name & " " & r.comment)

        # Coverage check
        if cov >= 0:
          covStats.push(cov)
          if optmincov != 0.0 and cov < optmincov:
            skip_lo_cov += 1
            continue
          if optmaxcov != 0.0 and cov > optmaxcov:
            skip_hi_cov += 1
            continue

        # Contig length filter
        if optminlen > 0 and len(r.seq) < optminlen:
          skip_short += 1
          continue
        if optmaxlen > 0 and len(r.seq) > optmaxlen:
          skip_long += 1
          continue


        pf += 1
        bases_printed += len(r.seq)
        if args["--sort"] == false:
          echo ">", r.name, " ", r.comment, "\n", r.seq;
        else:
          covTable.add((name: r.name, comment: r.comment, cov: cov, length: len(r.seq), sequence: r.seq))
    let
      ratio = 100.0 * float(bases_printed) / float(total_bases)

    stderr.writeLine(pf, "/", lenStats.n, " sequences printed (", covStats.n ," with coverage info) from ", ff , " files.")
    stderr.writeLine(fmt"Skipped:          {skip_short} too short, {skip_long} too long, then {skip_lo_cov} low coverage, {skip_hi_cov} high coverage, .")
    stderr.writeLine(fmt"Total size:       {bases_printed}/{total_bases} bp printed ({ratio:.1f}%)")
    stderr.writeLine(fmt"Average length:   {lenStats.mean():.2f} bp, [{lenStats.min} - {lenStats.max}]")
    if covStats.n > 0:
      stderr.writeLine(fmt"Average coverage: {covStats.mean():.2f}X, [{covStats.min:.1f}-{covStats.max:.1f}]")

    if args["--sort"] == true:
      var
        top = 0
      for i in rev(covTable.sortedByIt(it.cov)):
        top += 1

        if printtop != 0 and top > printtop:
          break

        echo ">", i.name, " ", i.comment, "\n", i.sequence
 
  except:
    
    stderr.writeLine("Try fu-cov --help.\nError: wrong parameters: ", getCurrentExceptionMsg())
    quit(0)


when isMainModule:
  main_helper(main)
