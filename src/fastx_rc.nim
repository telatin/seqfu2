import readfq
import tables
from os import fileExists
import docopt
import ./seqfu_utils



proc fastx_rc(argv: var seq[string]): int =
    let args = docopt("""
Usage: rc [options] [<strings-or-files>...] 

Print the reverse complementary of sequences in files or sequences
given as parameters. Can read FASTA/FASTQ also from STDIN, but not
naked strings.

Options:
  -s, --seq-name NAME    Sequence name if coming as string [default: dna]
  -r, --only-rev         Reverse, do not complement
  --strip-comments       Remove sequence comments
  -v, --verbose          Verbose output
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = args["--verbose"] 
    var
      files        : seq[string]
 
    
    let
      seqDefaultName = $args["--seq-name"] 

    if args["<strings-or-files>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu rc] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<strings-or-files>"]:
        files.add(file)
    
    
    var
      stringCount = 0
    for filename in files:
      if not fileExists(filename) and filename != "-":
        # Process as string
        stringCount += 1
        if len(files) == 1:
          echo if args["--only-rev"]: reverse(filename)
            else: revcompl(filename)
          continue
        else:
          echo ">", seqDefaultName, "_" , $stringCount, "\n", if args["--only-rev"]: reverse(filename)
              else: revcompl(filename)
          continue
      else:
        echoVerbose(filename, verbose)

      for record in readfq(filename):
        var
          r = record
        let comment = if len(r.comment) > 0 and not args["--strip-comments"]: " " & r.comment
                      else: ""
        if args["--only-rev"]:
          r.sequence = reverse(r.sequence)
        else:
          r.sequence = revcompl(r.sequence)

        if len(r.quality) > 0:
          r.quality = reverse(r.quality)
          echo '@', r.name, comment, "\n", r.sequence, "\n+\n", r.quality
        else:
          echo '>', r.name, comment, "\n", r.sequence

 
#[
proc fastx_rc_v2(argv: var seq[string]): int =
    let args = docopt("""
Usage: rc [options] [<strings-or-files>...] 

Print the reverse complementary of sequences in files or sequences
given as parameters. Can read FASTA/FASTQ also from STDIN, but not
naked strings.

Options:
  -s, --seq-name NAME    Sequence name if coming as string [default: dna]
  -r, --only-rev         Reverse, do not complement
  --strip-comments       Remove sequence comments
  -v, --verbose          Verbose output
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = args["--verbose"] 
    var
      files        : seq[string]
 
    
    let
      seqDefaultName = $args["--seq-name"] 

    if args["<strings-or-files>"].len() == 0:
      if getEnv("SEQFU_QUIET") == "":
        stderr.writeLine("[seqfu rc] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
      files.add("-")
    else:
      for file in args["<strings-or-files>"]:
        files.add(file)
    
    
    var
      stringCount = 0
    for filename in files:
      if not fileExists(filename) and filename != "-":
        # Process as string
        stringCount += 1
        if len(files) == 1:
          echo if args["--only-rev"]: reverse(filename)
            else: revcompl(filename)
          continue
        else:
          echo ">", seqDefaultName, "_" , $stringCount, "\n", if args["--only-rev"]: reverse(filename)
              else: revcompl(filename)
          continue
      else:
        echoVerbose(filename, verbose)
      
      for r in readfq(filename):
        var
          outRecord = r
        let comment = if len(r.comment) > 0 and not args["--strip-comments"]: " " & r.comment
                      else: ""
        if args["--only-rev"]:
          outRecord.sequence = reverse(r.sequenceuence)
        else:
          outRecord.sequence = revcompl(r.sequenceuence)

        if len(r.qualityity) > 0:
          outRecord.quality = reverse(r.qualityity)
          echo '@', outRecord.name, comment, "\n", outRecord.sequence, "\n+\n", outRecord.quality
        else:
          echo '>', outRecord.name, comment, "\n", outRecord.sequence

]#
  