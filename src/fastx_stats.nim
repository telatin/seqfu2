import readfq
import tables, strutils, sequtils
import terminaltables
from os import fileExists
import docopt
import ./seqfu_utils
 

type
  FastxStats*   = tuple[count, sum, min, max, n25, n50, n75, n90: int, auN, avg: float]


proc getFastxStats*(filename: string): FastxStats {.discardable.} =
  var
    totalBases = 0
    nseq  = 0
    ctgSizes = initOrderedTable[int, int]()

    accum = 0
    auN    : float
    i      = 0

  try:
    for r in readfq(filename):
      var ctgLen = len(r.sequence)
      if not (ctgLen in ctgSizes):
        ctgSizes[ctgLen] = 1
      else:
        ctgSizes[ctgLen]+=1
      totalBases += ctgLen
      nseq  += 1
  except Exception as e:
    stderr.writeLine("Warning: ignoring file ", filename)
    return

  if totalBases == 0:
    stderr.writeLine("Warning: file <", filename, "> is empty or malformed.")
    return 
  result.sum = totalBases

  var
    ctgSizesKeys  = toSeq(keys(ctgSizes))

  sort(ctgSizesKeys, proc(a, b: int): int =
      if a < b: return -1
      else: return 1
  )
  result.max = ctgSizesKeys[^1]
  result.min = ctgSizesKeys[0]
  result.auN = 0.0
  # calculate thresholds
  #for index in nIndexes:
  #  let quote = float(total) * float((100 - index) / 100)

  for ctgLen in ctgSizesKeys:

    let
      count = ctgSizes[ctgLen]
      ctgLengths = (ctgLen * count)

    i += 1
    accum += ctgLengths
    auN += float( ctgLen * ctgLen / totalBases);

    if (result.n25 == 0)  and (float(accum) >=  float( totalBases)  * float((100 - 25) / 100) )  :
      result.n25 = ctgLen
    if (result.n50 == 0)  and (float(accum) >=  float( totalBases)  * float((100 - 50) / 100) )  :
      result.n50 = ctgLen
    if (result.n75 == 0)  and (float(accum) >=  float( totalBases)  * float((100 - 75) / 100) )  :
      result.n75 = ctgLen
    if (result.n90 == 0)  and (float(accum) >=  float( totalBases)  * float((100 - 90) / 100) )  :
      result.n90 = ctgLen
  #[
    for index in nIndexes:
      if index in nArray:
        # was already calculated... skip
        continue
      let
        quote = float(totalBases) * float((100 - index) / 100)
      if float(accum) >= quote:
        nArray[index] = ctgLen
        iArray[index] = i
  ]#

  result.auN = auN
  result.count = nseq

  result.avg   =float( totalBases / nseq )




proc fastx_stats(argv: var seq[string]): int =
  let args = docopt("""
Usage: stats [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -n, --nice             Print nice terminal table
  --csv                  Separate with commas (default: tabs)
  --multiqc FILE         Saves a MultiQC report to FILE (suggested: name_mqc.txt)
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

  verbose = args["--verbose"]


  let
    printBasename = args["--basename"]
    nice     = args["--nice"]
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

  var
    files : seq[string]
    sep = "\t"
    multiQCreport : string = multiQCheader

  if args["--csv"]:
    sep = ","

  
    

  if args["<inputfile>"].len() == 0:
    stderr.writeLine("Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
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
  else:
    echo headerFields.join(sep)

  for filename in files:
    if filename != "-"  and not fileExists(filename):
      stderr.writeLine("Error: file <", filename, "> not found or not a file. Skipping.")
      continue

    var
      stats = getFastxStats(filename)

    var rendername = if printBasename: $getBasename(filename)
      else: filename


    let
      statsSeq = @[$rendername, $stats.count, $stats.sum, stats.avg.formatFloat(ffDecimal, 1), $stats.n50, $stats.n75, $stats.n90, $stats.auN.formatFloat(ffDecimal, 3), $stats.min, $stats.max]

    if nice:            
      outputTable.addRow(statsSeq)
    else:
      #echo $rendername, sep, $stats.count, sep, $stats.sum, sep, stats.avg.formatFloat(ffDecimal, 1), sep, $stats.n50, sep, $stats.n75, sep, $stats.n90, sep, $stats.min, sep, $stats.max
      echo statsSeq.join(sep)
    multiQCreport &= statsSeq.join("\t") & "\n"
  
  if nice:
    outputTable.printTable()

  if $args["--multiqc"] != "nil":
    try:
      var f = open($args["--multiqc"], fmWrite)
      defer: f.close()
      f.write(multiQCreport)
    except Exception:
      stderr.writeLine("Unable to write MultiQC report to ", $args["--multiqc"],": printing to STDOUT instead.")
      echo multiQCreport