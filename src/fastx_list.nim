import readfq
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils
import strformat


type
  ListOptions = object
    withComments : bool
    partialMatch : bool
    minLength    : int

proc getListFromFile(filename: string, opts: ListOptions): Table[string, int] =

  if not fileExists(filename):
    stderr.writeLine("ERROR: List file not found: ", filename)
    quit(1)

  for line in lines filename: 
    var
      name = line
      stripped = ""

    # remove first char if it is ">" or "@"
    if line[0] == '>' or line[0] == '@':
      name = line[1 .. ^1]
    
    # remove trailing spaces or tabs
    var 
      stripLen = 0
      pos = len(name) - 1
    while name[pos] == ' ' or name[pos] == '\t':
      stripLen += 1
      pos -= 1
    
    if stripLen > 0:
      name = name[0 ..< len(name) - stripLen]
   
    if opts.withComments == false:
      # Split line at the first white space or tab
      # and take the first part as the name
      name = ( name.split(' ')[0] ).split('\t')[0]
    else:
      var
        initialPart = ""
      for i, c in name:
        if len(initialPart) > 0  and (c == ' ' or c == '\t'):
          # Parsing we lose the first space char, that will be replaced with a space
          name = initialPart & " " & name[i+1 .. ^1]
          break
        initialPart &= c
 
    if len(name) < opts.minLength:
      continue
    result[name] = 0
     


proc fastx_list(argv: var seq[string]): int =
    let args = docopt("""
Usage: list [options] <LIST> <FASTQ>...

Print sequences that are present in a list file, which
can contains leading ">" or "@" characters.
Duplicated entries in the list will be ignored.

Other options:
  -c, --with-comments    Include comments in the list file
  -p, --partial-match    Allow partial matches (UNSUPPORTED)
  -m, --min-len INT      Skip entries smaller than INT [default: 1]

  -v, --verbose          Verbose output
  -r, --report           Print report of found sequences
  --help                 Show this help

  """, version=version(), argv=argv)

    verbose       = args["--verbose"] 

    let opts = ListOptions(
      withComments : args["--with-comments"],
      partialMatch : args["--partial-match"],
      minLength    : parseInt($args["--min-len"])
    )
    var sequenceList = getListFromFile($args["<LIST>"], opts)
    
    if len(  @(args["<FASTQ>"]) ) == 0:
      stderr.writeLine("No files specified. Use '-' to read STDIN, --help for help.")

    for file in @(args["<FASTQ>"]):
      if not fileExists(file) and file != "-":
        stderr.writeLine("ERROR: File not found: ", file)
        continue
         
      for record in readfq(file):
        let sequence_name = if opts.withComments and len(record.comment) > 0: record.name & " " & record.comment
                            else: record.name

        if sequence_name in sequenceList:
          sequenceList[sequence_name] += 1
          echo record

      if args["--report"]:
        var found = 0
        stderr.writeLine("# SEQUENCES REPORT")
        for name, counts in sequenceList:
          stderr.writeLine("# Sequence '", name, "' found ", counts, " times")
          if counts > 0:
            found += 1
        stderr.writeLine("Total sequences found: ", found, "/", len(sequenceList))