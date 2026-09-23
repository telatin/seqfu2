import ./seqfu_legacy_fastx
import tables, strutils
from os import fileExists
import docopt
import ./seqfu_utils


type
  SortRecord = tuple[name, comment, sequence: string]

proc fastx_sort(argv: var seq[string]): int =
  let args = docopt("""
Usage: sort [options] [<inputfile> ...]

 Sort FASTA sequences by length, printing only unique sequences.

 All input files are pooled: duplicates are removed across files and
 a single sorted output is printed. When a sequence occurs more than once,
 the name of its first occurrence is kept. Sequences of equal length are
 printed in input order.

 FASTQ is not supported: FASTQ input is accepted, but quality scores are
 discarded and the output is always FASTA.

Options:
  -p, --prefix STRING    Rename sequences as STRING1, STRING2, ...
  -s, --strip-comments   Remove sequence comments
  -k, --keep-duplicates  Keep identical sequences as separate records
  --asc                  Ascending order
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

  verbose = args["--verbose"]
  stripComments = args["--strip-comments"]

  let
    ascending = args["--asc"]
    keepDuplicates = args["--keep-duplicates"]

  var
    files: seq[string]
    prefix: string
    seqIndex = initTable[string, int]()
    records: seq[SortRecord]
    totalReads = 0
    fastqWarned = false

  if args["--prefix"]:
    prefix = $args["--prefix"]

  if args["<inputfile>"].len() == 0:
    if getEnv("SEQFU_QUIET") == "":
      stderr.writeLine("[seqfu sort] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
    files.add("-")
  else:
    for file in args["<inputfile>"]:
      files.add(file)

  for filename in files:
    if filename != "-" and not fileExists(filename):
      stderr.writeLine("[seqfu sort] ERROR: File not found: ", filename)
      return 1

    var
      f = xopen[GzFile](filename)
      r: FastxRecord
    defer: f.close()

    while f.readFastx(r):
      totalReads += 1
      if r.qual.len > 0 and not fastqWarned:
        stderr.writeLine("[seqfu sort] WARNING: FASTQ input is not supported, quality scores will be discarded.")
        fastqWarned = true
      if not keepDuplicates:
        if r.seq in seqIndex:
          continue
        seqIndex[r.seq] = records.len
      records.add((name: r.name, comment: r.comment, sequence: r.seq))

  if verbose:
    stderr.writeLine("[seqfu sort] ", totalReads, " sequences read, ", records.len, " printed.")

  # Nim's sort is stable: equal-length sequences keep their input order
  if ascending:
    records.sort(proc(a, b: SortRecord): int = cmp(a.sequence.len, b.sequence.len))
  else:
    records.sort(proc(a, b: SortRecord): int = cmp(b.sequence.len, a.sequence.len))

  var c = 0
  for rec in records:
    c += 1
    var header = if prefix.len > 0: prefix & $c else: rec.name
    if not stripComments and rec.comment.len > 0:
      header &= " " & rec.comment
    stdout.write(">", header, "\n", rec.sequence, "\n")
