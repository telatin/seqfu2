import klib
import sequtils
import tables
import os
import docopt
import ./seqfu_utils
 
type
  illuminaSample = tuple
    id: string
    R1_L001, R1_L002, R1_L003, R1_L004, R1_L005, R1_L006, R1_L007, R1_L008: string
    R2_L001, R2_L002, R2_L003, R2_L004, R2_L005, R2_L006, R2_L007, R2_L008: string
 

proc fastq_merge_lanes(argv: var seq[string]): int =
    let args = docopt("""
Usage: lanes [options] -o <outdir> <input_directory>

NOTE: This tool supports up to 8 lanes of Illumina-formatted output files.
Merged lane output files will be in an uncompressed format.

Options:
  -o, --outdir DIR           Output directory
  -e, --extension STR        File extension [default: .fastq]
  -s, --file-separator STR   Field separator in filenames [default: _]
  --comment-separator STR    String separating sequence name and its comment [default: TAB]
  -v, --verbose              Verbose output 
  -h, --help                 Show this help

  """, version=version(), argv=argv)

    verbose = args["--verbose"]
    
    let fqSeparator = if  $args["--comment-separator"] == "TAB": "\t"
                      else: $args["--comment-separator"]
    if not dirExists($args["<input_directory>"]):
      stderr.writeLine("ERROR: Input directory not found: ", $args["<input_directory>"])
      quit(1)
    
    if not dirExists($args["--outdir"]):
      stderr.writeLine("ERROR: Output directory not found: ", $args["--outdir"])
      quit(1) 
    
    var
      samples = initTable[string, illuminaSample]()
      paired_end = false

    let
      filesInPath = toSeq(walkDir($args["<input_directory>"], relative=true))
      lanes = @["L001", "L002", "L003", "L004", "L005", "L006", "L007", "L008"]
      strands = @["R1", "R2"]

    for file in filesInPath:
      if file.kind != pcFile:
        continue

      let sid = (file.path).split("_")
      
      if sid[0] notin samples:
        var s : illuminaSample = (id: sid[0], R1_L001: "", R1_L002: "", R1_L003: "", R1_L004: "", R1_L005: "", R1_L006: "", R1_L007: "", R1_L008: "", R2_L001: "", R2_L002: "", R2_L003: "", R2_L004: "", R2_L005: "", R2_L006: "", R2_L007: "", R2_L008: "")
        samples[sid[0]] = s
      
      if sid[2] notin lanes or sid[3] notin strands:
        stderr.writeLine("ERROR: File name is not in the Illumina standard form: lane expected but <", sid[2], "> found OR strand expected but <", sid[3], "> found.")
        quit(1)

      if sid[3] == "R1":
        if sid[2] == "L001":
          (samples[sid[0]]).R1_L001 = file.path
        elif sid[2] == "L002":
          (samples[sid[0]]).R1_L002 = file.path
        elif sid[2] == "L003":
          (samples[sid[0]]).R1_L003 = file.path
        elif sid[2] == "L004":
          (samples[sid[0]]).R1_L004 = file.path
        elif sid[2] == "L005":
          (samples[sid[0]]).R1_L005 = file.path
        elif sid[2] == "L006":
          (samples[sid[0]]).R1_L006 = file.path
        elif sid[2] == "L007":
          (samples[sid[0]]).R1_L007 = file.path
        elif sid[2] == "L008":
          (samples[sid[0]]).R1_L008 = file.path
      else:
        paired_end = true
        if sid[2] == "L001":
          (samples[sid[0]]).R2_L001 = file.path
        elif sid[2] == "L002":
          (samples[sid[0]]).R2_L002 = file.path
        elif sid[2] == "L003":
          (samples[sid[0]]).R2_L003 = file.path
        elif sid[2] == "L004":
          (samples[sid[0]]).R2_L004 = file.path
        elif sid[2] == "L005":
          (samples[sid[0]]).R2_L005 = file.path
        elif sid[2] == "L006":
          (samples[sid[0]]).R2_L006 = file.path
        elif sid[2] == "L007":
          (samples[sid[0]]).R2_L007 = file.path
        elif sid[2] == "L008":
          (samples[sid[0]]).R2_L008 = file.path
    
    for id, sample in samples.pairs:
   
      let 
        fileR1 = id & $args["--file-separator"] & "R1" & $args["--extension"]
        fileR2 = id & $args["--file-separator"] & "R2" & $args["--extension"]
        outR1 = joinPath($args["--outdir"], fileR1)
        outR2 = joinPath($args["--outdir"], fileR2)
        fOut = open(outR1, fmWrite)
      
        rOut = open(outR2, fmWrite)
      defer: rOut.close()
      defer: fOut.close()
      
      
      if args["--verbose"]:
        stderr.writeLine("# Processing: ", id)
      for file in @[sample.R1_L001, sample.R1_L002,  sample.R1_L003,  sample.R1_L004, sample.R1_L005, sample.R1_L006, sample.R1_L007, sample.R1_L008]:
        let inputFile = joinPath($args["<input_directory>"], file)
        if fileExists(inputFile):
          var 
            fq = xopen[GzFile](inputFile)
            r  : FastxRecord
          defer: fq.close()
          while fq.readFastx(r):
            if len(r.comment) > 0:
              r.comment = fqSeparator & r.comment
            fOut.writeLine('@', r.name,  r.comment, "\n", r.seq, "\n+\n", r.qual)
          
          if args["--verbose"]:
            stderr.writeLine(file)
      if not paired_end:
        continue

      for file in @[sample.R2_L001, sample.R2_L002,  sample.R2_L003,  sample.R2_L004, sample.R2_L005, sample.R2_L006, sample.R2_L007, sample.R2_L008]:
        let inputFile = joinPath($args["<input_directory>"], file)
        if fileExists(inputFile):
          var 
            fq = xopen[GzFile](inputFile)
            r  : FastxRecord
          defer: fq.close()
          while fq.readFastx(r):
            if len(r.comment) > 0:
              r.comment = fqSeparator & r.comment
            rOut.writeLine('@', r.name, r.comment, "\n", r.seq, "\n+\n", r.qual)
          if args["--verbose"]:
            stderr.writeLine(file)