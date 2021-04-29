import readfq
import docopt
import os
#import posix
import strutils
import ./seqfu_utils

let version = "1.0"

proc seq_to_string(name, comment, sequence, quality, separator: string): string =
  let
    printed_comment = if len(comment) > 0: separator & comment
                      else: ""
  if len(quality) == len(sequence):
    return "@" & name & printed_comment & "\n" & sequence & "\n+\n" & quality
  else:
    return ">" & name & printed_comment & "\n" & sequence

proc main(argv: var seq[string]): int =
  let args = docopt("""
  SeqFu MultiRelabel

  A program to rename sequences from multiple files (adding the filename,
  and or numerical postfix). Will fail if multiple sequence receive the same name.

  Usage: 
  fu-multirelabel [options] FILE...

  Options:
    -b, --basename             Prepend file basename to sequence
    -r, --rename NAME          Replace original name with NAME
    -n, --numeric-postfix      Add progressive number (reset at each new basename)
    -t, --total-postfix        Add progressive number (without resetting at each new input file)
    -d, --split-basename CHAR  Remove the final part of basename after CHAR [default: .]
    -s, --separator STRING     Separator between prefix, name, suffix [default: _]
    --no-comments              Strip out comments
    --comment-separator CHAR   Separate comment from name with CHAR [default: TAB]
  
  """, version=version, argv=argv)

  
  # Retrieve the arguments from the docopt (we will replace "TAB" with "\t")
  let
    comment_separator  = if $args["--comment-separator"] == "TAB": "\t"
                 else: $args["--comment-separator"]

  # Check input file existence
  var tot_counter = 0
  var seq_names = newSeq[string]()
  for input_file in args["FILE"]:

    if not fileExists(input_file):
      stderr.writeLine("ERROR: Input file not found: ", input_file)
      quit(1)
      
    var
      counter = 0
    let
      file_split    =  if args["--basename"]: lastPathPart(input_file).split($args["--split-basename"])[0] & $args["--separator"]
                       else: ""


    try:
      for seqObject in readfq(input_file):
        tot_counter += 1
        counter     += 1

        let
          comments = if args["--no-comments"]: ""
                     else: seqObject.comment
          seq_name      = if $args["--rename"] == "nil": seqObject.name
                      else: $args["--rename"]

          seq_counter   = if args["--total-postfix"]:  $args["--separator"] & $tot_counter
                      elif args["--numeric-postfix"]:  $args["--separator"] & $counter
                      else: ""
        
          name =  file_split & seq_name & seq_counter
          
        if name in seq_names:
          stderr.writeLine("ERROR: Sequence name <", name, "> was found twice. Stopping parsing ", input_file)
          quit(1)
        else:
          seq_names.add(name)

        echo(seq_to_string(name, comments, seqObject.sequence, seqObject.quality, comment_separator))

    except Exception as e:
      stderr.writeLine("ERROR: Unable to parse FASTX file: ", input_file, "\n", e.msg)
      return 1
 
  
when isMainModule:
  main_helper(main)