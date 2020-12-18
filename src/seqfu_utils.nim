import klib

import  strutils, os
#[ Versions
BETA: 0.8.{{VERSION}}
- 2.0.0   Moved to 'seqfu2', to keep seqfu for perl utilities
- 0.4.0   Added 'tail'
- 0.3.0   Added 'stats'
- 0.2.1   Added 'head'
- 0.2.0   Improved 'count' with PE support
          Initial refactoring
- 0.1.2   Added 'count' stub
- 0.1.1   Added 'derep' to dereplicate
- 0.1.0   Initial release

]#

proc version*(): string =
  return "0.8.2"




proc echoVerbose*(msg: string, print: bool) =
  if print:
    stderr.writeLine(" * ", msg)



# Common variables for switches
var
   verbose*:        bool    # verbose mode
   check*:          bool    # enable basic checks
   stripComments*:  bool    # strip comments in output sequence
   forceFasta*:     bool
   forceFastq*:     bool
   defaultQual*     = 33
   lineWidth*       = 0




proc getBasename*(filename: string): string =
  let  fileParse = splitFile(filename)

  if fileParse[2] == ".gz":
    let  gunzippedParse = splitFile(fileParse[1])
    return gunzippedParse[1]
  else:
    return fileParse[1]
  #( dir, filenameNoExt, extension) = splitFile(filename)
  #(sampleId, direction) = extractTag(filenameNoExt, pattern1, pattern2)

proc extractTag*(filename: string, patternFor: string, patternRev: string): (string, string) =
    if patternFor == "auto":
      # automatic guess
      var basename = split(filename, "_R1.")
      if len(basename) > 1:
        return (basename[0], "R1")
      basename = split(filename, "_R1_")
      if len(basename) > 1:
        return (basename[0], "R1")
      basename = split(filename, "_1.")
      if len(basename) > 1:
        return (basename[0], "R1")
    else:
      var basename = split(filename, patternFor)
      if len(basename) > 1:
        return (basename[0], "R1")

    if patternFor == "auto":
      # automatic guess
      var basename = split(filename, "_R2.")
      if len(basename) > 1:
        return (basename[0], "R2")
      basename = split(filename, "_R2_")
      if len(basename) > 1:
        return (basename[0], "R2")
      basename = split(filename, "_2.")
      if len(basename) > 1:
        return (basename[0], "R2")
    else:
      var basename = split(filename, patternFor)
      if len(basename) > 1:
        return (basename[0], "R2")

    return (filename, "SE")

proc format_dna*(seq: string, format_width: int): string =
  if format_width == 0:
    return seq
  for i in countup(0,seq.len - 1,format_width):
    #let endPos = if (seq.len - i < format_width): seq.len - 1
    #            else: i + format_width - 1
    if (seq.len - i <= format_width):
      result &= seq[i..seq.len - 1]
    else:
      result &= seq[i..i + format_width - 1] & "\n"


proc qualToChar*(q: int): char =
  ## returns character for a given Illumina quality score
  (q+33).char

proc print_seq*(record: FastxRecord, outputFile: File) =
  var
    name = record.name
    seqstring : string

  if not stripComments:
    name.add(" " & record.comment)

  if len(record.qual) > 0 and (len(record.seq) != len(record.qual)):
    stderr.writeLine("Sequence <", record.name, ">: quality and sequence length mismatch.")
    return

  if len(record.qual) > 0 and forceFasta == false:
    # print FQ

    seqString = "@" & name & "\n" & record.seq & "\n+\n" & record.qual
  elif forceFastq == true:
    seqString = "@" & name & "\n" & record.seq & "\n+\n" & repeat(qualToChar(defaultQual), len(record.seq))
  else:
    # print FA
    seqString = ">" & name & "\n" & record.seq

  if outputFile == nil:
    echo seqString
  else:
    outputFile.writeLine(seqstring)
