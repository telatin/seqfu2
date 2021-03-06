import klib
 
import docopt
import strutils
import stats
import strformat
import os
import algorithm
import ./seqfu_utils

const NimblePkgVersion {.strdefine.} = "undef"
const programVersion = if NimblePkgVersion == "undef": "X.9"
                       else: NimblePkgVersion
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

proc verbose(msg: string, print: bool) =
  if print:
    stderr.writeLine(" - ", msg)


proc format_dna(seq: string, format_width: int): string =
  if format_width == 0:
    return seq
  for i in countup(0,seq.len - 1,format_width):
    #let endPos = if (seq.len - i < format_width): seq.len - 1
    #            else: i + format_width - 1
    if (seq.len - i <= format_width):
      result &= seq[i..seq.len - 1]
    else:
      result &= seq[i..i + format_width - 1] & "\n"


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
  fu-cov [options] [inputfile ...]

  Options:
    -c, --min-cov FLOAT    Minimum coverage [default: 0.0]
    -x, --max-cov FLOAT    Maximum coverage [default: 0.0]
    -l, --min-len INT      Minimum contig length [default: 0]
    -y, --max-len INT      Maximum contig length [default: 0]
    -t, --top INT          Print the first TOP sequences when using --sort [default: 0] 
    -s, --sort             Store contigs in memory and sort them by descending coverage
    --verbose              Print verbose log
    --help                 Show help
  """, version=programVersion, argv=commandLineParams())
  try:
    var
      skip_hi_cov = 0
      skip_lo_cov = 0
      skip_short  = 0
      skip_long   = 0
      covTable    = newSeq[ContigInfo]()



    if len(args["inputfile"]) == 0:
      echo "Missing argument: input file (type -h for more info)"
      #if not $args["help == true:
      #  echo "Type --help for more info."
      quit(0)

    var
      c  = 0      # total count of sequences
      pf = 0      # passing filters
      ff = 0      # parsed files
    for filename in args["inputfile"]:
      if not fileExists(filename):
        echo "FATAL ERROR: File ", filename, " not found."
        quit(1)

      var f = xopen[GzFile](filename)
      defer: f.close()
      var r: FastxRecord
      verbose("Reading " & filename, args["verbose"])
      ff += 1
      # Prse FASTX
      var match: array[1, string]


      while f.readFastx(r):
        c+=1
        lenStats.push(len(r.seq))
        var cov = getCovFromString(r.name & " " & r.comment)

        # Coverage check
        if cov >= 0:
          covStats.push(cov)
          if $args["min_cov"] != "0.0" and cov < parseFloat($args["min_cov"]):
            skip_lo_cov += 1
            continue
          if $args["max_cov"] != "0.0" and cov > parseFloat($args["max_cov"]):
            skip_hi_cov += 1
            continue

        # Contig length filter
        if $args["min_len"] != "0" and len(r.seq) < parseInt($args["min_len"]):
          skip_short += 1
          continue
        if $args["max_len"] != "0" and len(r.seq) > parseInt($args["max_len"]):
          skip_long += 1
          continue


        pf += 1

        if args["sort"] == false:
          echo ">", r.name, " ", r.comment, "\n", r.seq;
        else:
          covTable.add((name: r.name, comment: r.comment, cov: cov, length: len(r.seq), sequence: r.seq))

    stderr.writeLine(pf, "/", lenStats.n, " sequences printed (", covStats.n ," with coverage info) from ", ff , " files.")
    stderr.writeLine(fmt"Skipped:          {skip_short} too short, {skip_long} too long, then {skip_lo_cov} low coverage, {skip_hi_cov} high coverage, .")
    stderr.writeLine(fmt"Average length:   {lenStats.mean():.2f} bp, [{lenStats.min} - {lenStats.max}]")
    if covStats.n > 0:
      stderr.writeLine(fmt"Average coverage: {covStats.mean():.2f}X, [{covStats.min:.1f}-{covStats.max:.1f}]")

    if args["sort"] == true:
      var
        top = 0
      for i in rev(covTable.sortedByIt(it.cov)):
        top += 1

        if $args["top"] != "0" and top > parseInt($args["top"]):
          break

        echo ">", i.name, " ", i.comment, "\n", i.sequence
 
  except:
    
    stderr.writeLine("Try fu-cov --help.\nError: wrong parameters: ", getCurrentExceptionMsg())
    quit(0)


when isMainModule:
  main_helper(main)
