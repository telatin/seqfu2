import docopt
import strutils
import sequtils
import klib
import readfq
import "./seqfu_utils"

proc getAvgQual(qual: string, offset: int = 33): float =
  var total = 0
  for c in qual:
    total += c.ord - offset
  return total / qual.len

proc slidingWindowQual(qual: string, window_size: int = 5, offset: int = 33): seq[float] =
  result = newSeq[float]()
  for i in 0 .. qual.len - window_size:
    let window = qual[i ..< i + window_size]
    result.add(getAvgQual(window, offset))

proc fastx_trim*(args: var seq[string]): int =
  let doc = """
Usage: trim [options] [<inputfile> ...]

Options:
  -w, --window-size INT    Window size for quality calculation [default: 5]
  -q, --min-avg-qual INT   Minimum average quality within window [default: 20]
  --offset INT             Quality offset (33 for Illumina) [default: 33]
  -o, --output FILE        Output filename [default: -]
  -v, --verbose            Verbose output
  -h, --help               Show this help

Description:
  Trim FASTQ sequences from 3' end when quality drops below threshold
  in a sliding window.
  """
  
  let args = docopt(doc, argv=args, version="SeqFu " & version())
  
  let 
    window_size = parseInt($args["--window-size"])
    min_avg_qual = parseInt($args["--min-avg-qual"])
    offset = parseInt($args["--offset"])
    output_file = $args["--output"]
    verbose = args["--verbose"]
    files = if args["<inputfile>"].len > 0: @(args["<inputfile>"])
            else: @["-"]
  
  var outfile: File
  if output_file == "-":
    outfile = stdout
  else:
    try:
      outfile = open(output_file, fmWrite)
    except:
      stderr.writeLine("Error: Unable to open output file: ", output_file)
      return 1
  
  for filename in files:
    try:
      for record in readfq(filename):
        var trimmed_record = record
        
        if record.quality.len > 0:
          # Get sliding window quality scores
          let window_quals = slidingWindowQual(record.quality, window_size, offset)
          
          # Find position where quality drops below threshold
          var trim_pos = record.quality.len
          for i, avg_qual in window_quals:
            if avg_qual < float(min_avg_qual):
              trim_pos = i
              break
          
          # Only trim if we found a position
          if trim_pos < record.quality.len:
            trimmed_record.sequence = record.sequence[0 ..< trim_pos]
            trimmed_record.quality = record.quality[0 ..< trim_pos]
            
            if verbose:
              stderr.writeLine("Trimmed '", record.name, "' from ", record.sequence.len, 
                             " to ", trimmed_record.sequence.len, " bases")
        
        # Print trimmed record
        print_seq(trimmed_record, outfile)
        
    except:
      stderr.writeLine("Error processing file: ", filename)
      return 1
  
  if output_file != "-":
    outfile.close()
  
  return 0