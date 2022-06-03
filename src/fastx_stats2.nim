import readfq
import tables, strutils, sequtils
import terminaltables
from os import fileExists
import docopt
import ./seqfu_utils
import ./stats_utils 
import algorithm



proc fastx_stats_v2(argv: var seq[string]): int =
  let args = docopt("""
Usage: stats [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -n, --nice             Print nice terminal table
  -j, --json             Print json (experimental)
  --csv                  Separate output by commas instead of tabs
  --multiqc FILE         Saves a MultiQC report to FILE (suggested: name_mqc.txt)
  --precision INT        Number of decimal places to round to [default: 2]
  --sort KEY             Sort by KEY from: filename, counts, n50, tot, avg, min, max
                         descending for values, ascending for filenames [default: filename]
  -r, --reverse          Reverse sort order
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

  verbose = args["--verbose"]


  let
    reverse = bool(args["--reverse"])
    printBasename = args["--basename"]
    printAbs = bool(args["--abs-path"])
    nice     = bool(  args["--nice"] )
    printJson = bool(args["--json"])
    multiQCheader = """# plot_type: 'table'
# section_name: 'SeqFu statistics'
# description: 'Statistics on sequence lengths of a set of samples'
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
Sample	col1	col2	col3	col4	col5	col6	col7  col8  col9
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

  
    

  if args["<inputfile>"].len() == 0:
    if getEnv("SEQFU_QUIET") == "":
      stderr.writeLine("[seqfu stats] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
    files.add("-")
  else:
    for file in args["<inputfile>"]:
      files.add(file)


  let
    outputTable = newUnicodeTable()
    headerFields = @["File", "#Seq", "Total bp","Avg", "N50", "N75", "N90", "auN", "Min", "Max"]
  
  
  if nice:
    outputTable.separateRows = false
    outputTable.setHeaders(headerFields)
  elif not printJson:
    echo headerFields.join(sep)

  for filename in files:
    if filename != "-"  and not fileExists(filename):
      stderr.writeLine("Error: file <", filename, "> not found or not a file. Skipping.")
      continue

    var
      stats = getFastxStats(filename)

    if printBasename:
      stats.filename = getBasename(stats.filename)
    elif printAbs:
      stats.filename =  absolutePath(stats.filename)

    statsList.add(stats)
    #[
    let
      statsSeq = @[$rendername, $stats.count, $stats.sum, stats.avg.formatFloat(ffDecimal, sfuPrecision), $stats.n50, $stats.n75, $stats.n90, $stats.auN.formatFloat(ffDecimal, sfuPrecision), $stats.min, $stats.max]

    if nice:            
      outputTable.addRow(statsSeq)
    else:
      echo statsSeq.join(sep)
    multiQCreport &= statsSeq.join("\t") & "\n"
    ]#
  
  # Sort
  let sortKey = ($args["--sort"]).toLower();
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
  else:
    stderr.writeLine("WARNING: sort key <", sortKey, "> not recognized. Not sorting.")

  
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
  

  # Save also MultiQC table
  if $args["--multiqc"] != "nil":
    try:
      var f = open($args["--multiqc"], fmWrite)
      defer: f.close()
      f.write(multiQCreport)
    except Exception:
      stderr.writeLine("Unable to write MultiQC report to ", $args["--multiqc"],": printing to STDOUT instead.")
      echo multiQCreport