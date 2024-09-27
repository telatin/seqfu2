
import tables, strutils
import terminaltables
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
  -t, --thousands        Add thousands separator (only tabbed/nice output)
  --csv                  Separate output by commas instead of tabs
  --gc                   Also print %GC
  --index                Also print contig index (L50, L90)
  --multiqc FILE         Saves a MultiQC report to FILE (suggested: name_mqc.txt)
  --precision INT        Number of decimal places to round to [default: 2]
  --noheader             Do not print header
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

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
    quit(1)

  var
    sfuPrecision = 2
    files : seq[string]
    sep = "\t"
    multiQCreport : string = multiQCheader
    statsList : seq[FastxStats]
  try:
    sfuPrecision = parseInt($args["--precision"])
  except:
    stderr.writeLine("ERROR: Precision must be an integer: ", $args["--precision"])
    quit(1)

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
    

  if args["<inputfile>"].len() == 0:
    if getEnv("SEQFU_QUIET") == "":
      stderr.writeLine("[seqfu stats] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
    files.add("-")
  else:
    for file in args["<inputfile>"]:
      files.add(file)


  
  #elif not printJson:
  # echo headerFields.join(sep)

  for filename in files:
    if filename != "-"  and not fileExists(filename):
      stderr.writeLine("Error: file <", filename, "> not found or not a file. Skipping.")
      continue

    var
      stats = getFastxStats(filename, opt)

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
    sortKey = ($args["--sort-by"]).toLower()
    validKeys = @["none", "n50", "n75", "n90", "min", "max", "sum", "count", "avg", "filename", "counts", "tot", "mean"]

  if sortKey notin validKeys:
    stderr.writeLine("ERROR: Invalid sort key: ", sortKey)
    

  if  sortKey == "n50":
    if reverse:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.n50 < b.n50: return -1
        else: return 1
      )
    else:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.n50 > b.n50: return -1
        else: return 1
      )
  elif  sortKey == "n75":
    if reverse:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.n75 < b.n75: return -1
        else: return 1
      )
    else:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.n75 > b.n75: return -1
        else: return 1
      )
  elif  sortKey == "n90":
    if reverse:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.n90 < b.n90: return -1
        else: return 1
      )
    else:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.n90 > b.n90: return -1
        else: return 1
      )
  elif sortKey == "count" or sortKey == "counts":
    if reverse:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.count < b.count: return -1
        else: return 1
      )
    else:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.count > b.count: return -1
        else: return 1
      )
  elif sortKey == "sum" or sortKey == "tot":
    if reverse:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.sum < b.sum: return -1
        else: return 1
      )
    else:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.sum > b.sum: return -1
        else: return 1
      )
  elif sortKey == "min" or sortKey == "minimum":
    if reverse:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.min < b.min: return -1
        else: return 1
      )
    else:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.min > b.min: return -1
        else: return 1
      )
  elif sortKey == "max" or sortKey == "maximum":
    if reverse:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.max < b.max: return -1
        else: return 1
      )
    else:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.max > b.max: return -1
        else: return 1
      )
  elif sortKey == "average" or sortKey == "avg" or sortKey == "mean":
    if reverse:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.avg < b.avg: return -1
        else: return 1
      )
    else:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.avg > b.avg: return -1
        else: return 1
      )
  elif sortKey == "filename":
    if reverse:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.filename > b.filename: return -1
        else: return 1
      )
    else:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.filename < b.filename: return -1
        else: return 1
      )
  elif  sortKey == "aun":
    if reverse:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.aun < b.aun: return -1
        else: return 1
      )
    else:
      sort(statsList, proc(a, b: FastxStats): int =
        if a.aun > b.aun: return -1
        else: return 1
      )
  elif sortKey == "none":
    if reverse:
      # Reverse the list
      statsList.reverse()
  else:
    stderr.writeLine("WARNING: sort key <", sortKey, "> not recognized. Not sorting.")


  if printJson:
    var
      jsonList: seq[Table[string,string]]
    for i in statsList:
      jsonList.add(i.toTable())
    let jsonString = $jsonList
    echo jsonString[1 .. ^1]
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