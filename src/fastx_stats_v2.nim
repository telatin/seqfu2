
import tables, strutils
import terminaltables
import malebolgia
import json
from os import fileExists
import docopt
import ./seqfu_utils
import ./stats_utils 
import algorithm


proc toSequence(s: FastxStats, o: statsOptions): seq[string] =
  var
    fields : seq[string]
    fmt = if o.thousands and o.delim != ",": "t"
          else: ""
  fields.add(s.filename)
  fields.add(fmtFloat(float(s.count), 0, fmt))
  fields.add(fmtFloat(float(s.sum), 0, fmt))
  fields.add(fmtFloat(float(s.avg), o.precision, fmt))
  fields.add(fmtFloat(float(s.n50), 0, fmt))
  fields.add(fmtFloat(float(s.n75), 0, fmt))
  fields.add(fmtFloat(float(s.n90), 0, fmt))
  fields.add(fmtFloat(float(s.auN), o.precision, fmt))
  fields.add(fmtFloat(float(s.min), 0, fmt))
  fields.add(fmtFloat(float(s.max), 0, fmt))
  if o.gc:
    fields.add(fmtFloat(float(s.gc), o.precision, fmt))
  if o.index:
    fields.add(fmtFloat(float(s.l50), 0, fmt))
    fields.add(fmtFloat(float(s.l75), 0, fmt))
    fields.add(fmtFloat(float(s.l90), 0, fmt))
  return fields

proc toDelimitedString(s: seq[string], o: statsOptions): string =
  return join(s, o.delim)

proc toDelimitedString(s: FastxStats, o: statsOptions): string =
  return join(s.toSequence(o), o.delim)

proc display_nice(statsList: seq[FastxStats], opt: statsOptions) =
  var
    header = @["File", "#Seq", "Total bp", "Avg", "N50", "N75", "N90", "auN", "Min", "Max"]

  if opt.gc:
    header.add("%GC")
  if opt.index:
    header.add(@["L50", "L75","L90"])
  
  let
    outputTable = newUnicodeTable()
   
  outputTable.separateRows = false
  if opt.header:
    outputTable.setHeaders(header)

  for stats in statsList:
      let
        #statsSeq = @[$stats.filename, $stats.count, $stats.sum, stats.avg.formatFloat(ffDecimal, opt.precision), $stats.n50, $stats.n75, $stats.n90, $stats.auN.formatFloat(ffDecimal, opt.precision), $stats.min, $stats.max]
        statsSeq = stats.toSequence(opt)
      outputTable.addRow(statsSeq)
      
    
  outputTable.printTable()
   
proc display_delimited(statsList: seq[FastxStats], opt: statsOptions): string =
  var
    header = @["File", "#Seq", "Total bp", "Avg", "N50", "N75", "N90", "auN", "Min", "Max"]

  if opt.gc:
    header.add("%GC")
  if opt.index:
    header.add(@["L50", "L75","L90"])

  if opt.header:
    result &= join(header, opt.delim) & "\n"

  for stat in statsList:
    if stat.count > 0:
      result &= stat.toDelimitedString(opt)  & "\n"
  
    

type
  StatsSortKey = enum
    skNone,
    skFilename,
    skCount,
    skSum,
    skAvg,
    skMin,
    skMax,
    skN50,
    skN75,
    skN90,
    skAuN

type
  StatsJob = object
    filename: string
    stats: FastxStats

proc parseStatsSortKey(raw: string, outKey: var StatsSortKey): bool =
  case raw.toLowerAscii()
  of "none":
    outKey = skNone
  of "filename":
    outKey = skFilename
  of "count", "counts":
    outKey = skCount
  of "sum", "tot":
    outKey = skSum
  of "avg", "average", "mean":
    outKey = skAvg
  of "min", "minimum":
    outKey = skMin
  of "max", "maximum":
    outKey = skMax
  of "n50":
    outKey = skN50
  of "n75":
    outKey = skN75
  of "n90":
    outKey = skN90
  of "aun":
    outKey = skAuN
  else:
    return false
  true

proc compareStatsByKey(a, b: FastxStats, key: StatsSortKey): int =
  ## Strict comparator: returns 0 for equal values.
  case key
  of skNone:
    0
  of skFilename:
    cmp(a.filename, b.filename)
  of skCount:
    cmp(a.count, b.count)
  of skSum:
    cmp(a.sum, b.sum)
  of skAvg:
    cmp(a.avg, b.avg)
  of skMin:
    cmp(a.min, b.min)
  of skMax:
    cmp(a.max, b.max)
  of skN50:
    cmp(a.n50, b.n50)
  of skN75:
    cmp(a.n75, b.n75)
  of skN90:
    cmp(a.n90, b.n90)
  of skAuN:
    cmp(a.auN, b.auN)

proc processStatsJob(job: ptr StatsJob, workerOpt: ptr statsOptions) {.gcsafe.} =
  job[].stats = getFastxStats(job[].filename, workerOpt[])

proc toJsonNode(s: FastxStats): JsonNode =
  ## Keep numeric fields as JSON numbers (not quoted strings).
  result = newJObject()
  result["Filename"] = %s.filename
  result["Total"] = %s.sum
  result["Count"] = %s.count
  result["Min"] = %s.min
  result["Max"] = %s.max
  result["N25"] = %s.n25
  result["N50"] = %s.n50
  result["N75"] = %s.n75
  result["N90"] = %s.n90
  result["Avg"] = %s.avg
  result["AuN"] = %s.auN
  result["gc"] = %s.gc
  result["L50"] = %s.l50
  result["L75"] = %s.l75
  result["L90"] = %s.l90

proc fastx_stats_v2(argv: var seq[string]): int =
  let args = docopt("""
Usage: stats [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -n, --nice             Print nice terminal table
  -j, --json             Print json (EXPERIMENTAL)
  -s, --sort-by KEY      Sort by KEY from: filename, counts, n50, tot, avg, min, max
                         descending for values, ascending for filenames [default: none]
  -r, --reverse          Reverse sort order
  --threads INT          Worker threads [default: $1]
  -t, --thousands        Add thousands separator (only tabbed/nice output)
  --csv                  Separate output by commas instead of tabs
  --gc                   Also print %GC
  --index                Also print contig index (L50, L90)
  --multiqc FILE         Saves a MultiQC report to FILE (suggested: name_mqc.txt)
  --precision INT        Number of decimal places to round to [default: 2]
  --noheader             Do not print header
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """.multiReplace(("$1", $ThreadPoolSize)), version=version(), argv=argv)

  verbose = args["--verbose"]


  let
    reverse = bool(args["--reverse"])
    printBasename = bool(args["--basename"])
    printAbs = bool(args["--abs-path"])
    nice     = bool(  args["--nice"] )
    printJson = bool(args["--json"])
    printHeader = not bool(args["--noheader"])
    multiQCheader = """# plot_type: 'table'
# section_name: 'SeqFu stats'
# description: 'Statistics on sequence lengths of a set of FASTA/FASTQ files, generated with <a href="https://telatin.github.io/seqfu2">SeqFu """ & version() & """</a>'
# pconfig:
#     namespace: 'Cust Data'
# headers:
#     col1:
#         title: '#Seqs'
#         description: 'Number of sequences'
#         format: '{:,.0f}'
#     col2:
#         title: 'Total bp'
#         description: 'Total size of the dataset'
#     col3:
#         title: 'Avg'
#         description: 'Average sequence length'
#     col4:
#         title: 'N50'
#         description: '50% of the sequences are longer than this size'
#     col5:
#         title: 'N75'
#         description: '75% of the sequences are longer than this size'
#     col6:
#         title: 'N90'
#         description: '90% of the sequences are longer than this size'
#     col7:
#         title: 'Min'
#         description: 'Length of the shortest sequence'
#     col8:
#         title: 'Max'
#         description: 'Length of the longest sequence'
#     col9:
#         title: 'auN'
#         description: 'Area under the Nx curve'
#     col10:
#         title: 'GC'
#         description: 'Relative GC content (excluding Ns)'
Sample	col1	col2	col3	col4	col5	col6	col7	col8	col9	col10
"""
  if nice and printJson:
    stderr.writeLine("ERROR: --nice and --json are mutually exclusive")
    return 1

  var
    sfuPrecision = 2
    threads = 1
    files : seq[string]
    sep = "\t"
    multiQCreport : string = multiQCheader
    statsList : seq[FastxStats]
    hadInputErrors = false

  let writeMultiQC = $args["--multiqc"] != "nil"
  try:
    sfuPrecision = parseInt($args["--precision"])
  except:
    stderr.writeLine("ERROR: Precision must be an integer: ", $args["--precision"])
    return 1
  try:
    threads = parseInt($args["--threads"])
  except:
    stderr.writeLine("ERROR: --threads must be an integer >= 1.")
    return 1
  if threads < 1:
    stderr.writeLine("ERROR: --threads must be >= 1.")
    return 1

  if args["--csv"]:
    sep = ","




  let
    opt : statsOptions = (
      absolute: printAbs,
      basename: printBasename,
      precision: sfuPrecision,
      thousands: bool(args["--thousands"]),
      header: printHeader,
      gc: bool(args["--gc"]),
      index: bool(args["--index"]),
      scaffolds: false,
      delim: sep,
      fields: @[]
    )
  var workerOpt = opt
  # MultiQC always exports a GC column, so we force GC computation for the
  # reader even when --gc is not requested for the main table output.
  workerOpt.gc = opt.gc or writeMultiQC
    

  if args["<inputfile>"].len() == 0:
    if getEnv("SEQFU_QUIET") == "":
      stderr.writeLine("[seqfu stats] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
    files.add("-")
  else:
    for file in args["<inputfile>"]:
      files.add(file)


  
  #elif not printJson:
  # echo headerFields.join(sep)

  var
    jobs = newSeqOfCap[StatsJob](files.len)
    hasStdin = false
  for filename in files:
    if filename != "-" and not fileExists(filename):
      stderr.writeLine("Error: file <", filename, "> not found or not a file. Skipping.")
      hadInputErrors = true
      continue
    if filename == "-":
      hasStdin = true
    jobs.add(StatsJob(filename: filename))

  let canParallel = threads > 1 and jobs.len > 1 and (not hasStdin)
  if canParallel:
    let parallelChunk = min(threads, ThreadPoolSize)
    var m = createMaster()
    if parallelChunk >= ThreadPoolSize:
      m.awaitAll:
        for i in 0 ..< jobs.len:
          m.spawn processStatsJob(addr jobs[i], addr workerOpt)
    else:
      var start = 0
      while start < jobs.len:
        let stopAt = min(start + parallelChunk, jobs.len)
        m.awaitAll:
          for i in start ..< stopAt:
            m.spawn processStatsJob(addr jobs[i], addr workerOpt)
        start = stopAt
  else:
    if threads > 1 and hasStdin and verbose:
      stderr.writeLine("INFO: Disabling parallel stats because input includes STDIN ('-').")
    for i in 0 ..< jobs.len:
      processStatsJob(addr jobs[i], addr workerOpt)

  for i in 0 ..< jobs.len:
    var
      stats = jobs[i].stats

    if stats.count < 0:
      hadInputErrors = true
      continue

    if printBasename:
      stats.filename = getBasename(stats.filename)
    elif printAbs:
      stats.filename = absolutePath(stats.filename)

    statsList.add(stats)
    var 
      optqc = opt
    optqc.thousands = false
    optqc.precision = 7
    optqc.gc = true
    multiQCreport &= stats.toSequence(optqc).join("\t") & "\n"
 
  
  # Sort
  let
    sortKeyRaw = $args["--sort-by"]
  var sortKey = skNone
  if not parseStatsSortKey(sortKeyRaw, sortKey):
    stderr.writeLine("ERROR: Invalid sort key: ", sortKeyRaw)
    return 1

  if sortKey == skNone:
    if reverse:
      # Preserve input order semantics when sorting is disabled.
      statsList.reverse()
  else:
    # Keep current behavior: filename is ascending, numeric fields descending.
    let descendingByDefault = sortKey != skFilename
    sort(statsList, proc(a, b: FastxStats): int =
      var c = compareStatsByKey(a, b, sortKey)
      if c == 0:
        # Deterministic tie-break across all sort keys.
        c = cmp(a.filename, b.filename)
      if descendingByDefault:
        c = -c
      if reverse:
        c = -c
      c
    )

  if statsList.len == 0 and hadInputErrors:
    stderr.writeLine("ERROR: no valid FASTA/FASTQ input could be processed.")
    return 1

  if printJson:
    var
      jsonList = newJArray()
    for i in statsList:
      jsonList.add(i.toJsonNode())
    echo $jsonList
  elif nice:
    display_nice(statsList, opt)
  else:
    print display_delimited(statsList, opt)
  #[
  for stats in statsList:
    let
      statsSeq = @[$stats.filename, $stats.count, $stats.sum, stats.avg.formatFloat(ffDecimal, sfuPrecision), $stats.n50, $stats.n75, $stats.n90, $stats.auN.formatFloat(ffDecimal, sfuPrecision), $stats.min, $stats.max]
      
    if nice:
      outputTable.addRow(statsSeq)
    elif not printJson:
      echo statsSeq.join(sep)
    multiQCreport &= statsSeq.join("\t") & "\n"
  
  # Final printout
  if nice:
    outputTable.printTable()
  elif printJson:
    var
      jsonList: seq[Table[string,string]]
    for i in statsList:
      jsonList.add(i.toTable())
    let jsonString = $jsonList
    echo jsonString[1 .. ^1]
  
  ]#

  # Save also MultiQC table
  if $args["--multiqc"] != "nil":
    try:
      var f = open($args["--multiqc"], fmWrite)
      defer: f.close()
      f.write(multiQCreport)
    except Exception:
      stderr.writeLine("Unable to write MultiQC report to ", $args["--multiqc"],": printing to STDOUT instead.")
      echo multiQCreport
  if hadInputErrors:
    return 1
  return 0
