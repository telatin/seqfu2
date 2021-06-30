import klib
import re
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils





proc fastx_count(argv: var seq[string]): int =
    let multiQCheader = """# plot_type: 'table'
# section_name: 'SeqFu counts'
# description: 'Number of reads per sample'
# pconfig:
#     namespace: 'Cust Data'
# headers:
#     col1:
#         title: '#Seqs'
#         description: 'Number of sequences'
#         format: '{:,.0f}'
#     col2:
#         title: 'Type'
#         description: 'Paired End (PE) or Single End (SE) dataset'
Sample	col1	col2
"""

    let args = docopt("""
Usage: count-legacy [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -u, --unpair           Print separate records for paired end files
  -f, --for-tag R1       Forward string, like _R1 [default: auto]
  -r, --rev-tag R2       Reverse string, like _R2 [default: auto]
  -m, --multiqc FILE     Save report in MultiQC format
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

    verbose = args["--verbose"]

    var 
      files    : seq[string]
      abspath  = args["--abs-path"]
      basename = args["--basename"]
      unpaired = args["--unpair"]
      pattern1 = $args["--for-tag"]
      pattern2 = $args["--rev-tag"]
      mqc_report : string = multiQCheader
   
 
    
    if args["<inputfile>"].len() == 0:
      stderr.writeLine("Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<inputfile>"]:
        files.add(file)

    # pre scan files
    var 
      fileTable = initTable[string, initTable[string, string]() ]() 
      errors    = 0

    # Scan all filenames
    for filename in sorted(files):
      var
        printedFilename = filename

      if filename != "-" and not fileExists(filename):
        if dirExists(filename):
          stderr.writeLine("WARNING: Directories as not supported. Skipping ", filename)
        else:
          stderr.writeLine("WARNING: File ", filename, " not found.")
        continue
      
      let
        (dir, filenameNoExt, extension) = splitFile(filename)
        (sampleId, direction) = extractTag(filenameNoExt, pattern1, pattern2)
        
   
      if abspath:
        printedFilename = absolutePath(filename)
      elif basename:
        printedFilename = filenameNoExt & extension

      # Count sequences file by file
      var f = xopen[GzFile](filename)
      defer: f.close()
      var 
        r: FastxRecord
        c = 0
      while f.readFastx(r):
        c+=1
      echoVerbose(filename & " (" & direction & "): " & $c, verbose)
      
      # Populate counts table table[SampleID][R1/R2/Se] = counts
      if not ( sampleId in fileTable ):
        fileTable[sampleId] = initTable[string, string]()

      fileTable[sampleId][direction] = $c
      fileTable[sampleId]["filename_" & direction] = printedFilename
    
    
    for id, counts in fileTable:
      if "SE" in counts:
        echo counts["filename_SE"], "\t", counts["SE"], "\tSE"
        mqc_report &= counts["filename_SE"] & "\t" & counts["SE"] & "\tSE\n"
      else:
        if "R2" in counts:
          if counts["R1"] == counts["R2"]:
            echo counts["filename_R1"], "\t", counts["R1"], "\tPaired"
            mqc_report &= counts["filename_R1"] & "\t" & counts["R1"] & "\tPE\n"
            if (unpaired):
              echo counts["filename_R2"], "\t", counts["R2"], "\tPaired:R2"
              mqc_report &= counts["filename_R2"] & "\t" & counts["R2"] & "\tPE (Reverse)\n"
          else:
            errors += 1
            stderr.writeLine("ERROR: Different counts in ", counts["filename_R1"], " and ", counts["filename_R2"] )
            stderr.writeLine("# ", counts["filename_R1"], ": ", counts["R1"] )
            stderr.writeLine("# ", counts["filename_R2"], ": ", counts["R2"] )
            mqc_report &= counts["filename_R1"] & "\t" & counts["R1"] & "/" & counts["R2"]  & "\tError\n"
        else:
          echo counts["filename_R1"], "\t", counts["R1"], "\tSE"
          mqc_report &= counts["filename_R1"] & "\t" & counts["R1"] & "\tSE\n"
        
    


      
    if $args["--multiqc"] != "nil":
      if args["--verbose"]:
        stderr.writeLine("Saving MultiQC report to ", $args["--multiqc"])
      try:
        var f = open($args["--multiqc"], fmWrite)
        defer: f.close()
        f.write(mqc_report)
      except Exception:
        stderr.writeLine("Unable to write MultiQC report to ", $args["--multiqc"],": printing to STDOUT instead.")
        echo mqc_report

    if errors > 0:
      stderr.writeLine(errors, " errors found.")
      quit(1)
 