import docopt
import os
import std/random
import strutils
import ./seqfu_utils
#[
  The provided Nim program, named "fu-make," is designed to generate a FASTA or FASTQ file containing random 
  sequences based on provided instructions. 
  The program reads user instructions for generating sequences and outputs the sequences in the specified format. 
  The program uses the docopt library to handle command-line arguments and help messages.

The program consists of the following components:

Imports: 
  The program imports the necessary modules such as docopt, os, std/random, strutils, and a custom module seqfu_utils.

Constants and Variables: 
  The program defines constants like NimblePkgVersion and programName. 
  It also initializes variables like seq_count and base_count.

randomSeq Procedure: 
  This procedure generates a random DNA sequence of the specified length by randomly selecting characters from the "ACGT" DNA bases.

main Procedure: 
  The main part of the program reads command-line arguments using docopt. 
  It processes the provided instructions, where each instruction is in the format NUM_SEQ:LEN or NUM_SEQ:MIN_LEN-MAX_LEN. For each instruction, the program generates the specified number of sequences and outputs them in the requested format (FASTA or FASTQ). The generated sequence names include sequence count and length information.

Output Generation: 
  Depending on the chosen format, the program prints sequence headers, sequences, quality lines (for FASTQ format), 
  and repeats of the quality character. Sequence names are constructed based on the sequence count and length.

Main Module Check: 
  The program includes a conditional block that executes the main procedure when the program is run as the main module.

]#
const NimblePkgVersion {.strdefine.} = "pre-release"

let
  programName = "fu-make"
 

proc randomSeq(length: int): string =
  const bases = "ACGT"
  result = ""
  for _ in 0 ..< length:
    let base = rand(bases.high)
    result.add(bases[base])

 

proc main(args: var seq[string]): int =
  let args = docopt("""
  fu-make

  Make a FASTA or FASTQ file with random sequences.

  Usage: 
  fu-cov [options] INSTRUCTIONS...

  Instructions:
    NUM_SEQ:LEN or NUM_SEQ:MIN_LEN-MAX_LEN 

  Options:
    --norand               Print oligos instead of random sequences
    -q, --qual-char=CHAR   Quality character for FASTQ format [default: I]
    --fastq                Print in FASTQ format (default: FASTA)
    --verbose              Print verbose log
    --help                 Show help
  """, version=NimblePkgVersion, argv=commandLineParams())
 
  let
    qualChar = $args["--qual-char"]

  var
    seq_count = 0
    base_count = 0

  for cmd in args["INSTRUCTIONS"]:
    var
      num, min, max: int
      size: string

    try:
      let data = cmd.split(':')
      num = parseInt(data[0])
      size = data[1]
    except Exception as e:
      stderr.writeLine("Error: invalid instruction (NUM not valid): " & cmd)
      quit(1)

    if '-' in size:
      try:
        let data = size.split('-')
        min = parseInt(data[0])
        max = parseInt(data[1])
      except Exception as e:
        stderr.writeLine("Error: invalid instruction (range): " & cmd)
        quit(1)
    else:
      try:
        min = parseInt(size)
        max = min
      except Exception as e:
        stderr.writeLine("Error: invalid instruction (second part not int): " & cmd)
        quit(1)

    if min > max:
      stderr.writeLine("Error: invalid instruction (min > max): " & cmd)
      quit(1)
    seq_count += 1

    for i in 1 .. num:
      let size = if min == max: min
                 else: rand(max-min+1) + min
      let sequence =  if bool(args["--norand"]): repeat("A", size)
                      else: randomSeq(size)
      
      let name = "seq_" & $seq_count & "_" & $i & " len=" & $size
      if bool(args["--fastq"]):
        echo "@" & name
        echo sequence
        echo "+"
        let quality = repeat(qualChar, size)
        echo quality[0 .. size-1]
      else:
        echo ">" & name
        echo sequence
      
      

when isMainModule:
  main_helper(main)
