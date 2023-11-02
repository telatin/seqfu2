import strformat
import tables, strutils
from os import fileExists, commandLineParams
import readfq
import illwill
import docopt
import ./seqfu_utils

type
  SeqStack = object
    filename:  string
    size:      int
    head_size: int
    tail_size: int
    head:      seq[FQRecord]
    tail:      seq[FQRecord]

proc newSeqStack(filename: string, head_size, tail_size: int): SeqStack =
  return SeqStack(filename: filename, size: 0, head_size: head_size, tail_size: tail_size,
                  head: @[], tail: @[])

proc load(s: var SeqStack) =
  if not fileExists(s.filename):
    return
  
  for record in readfq.readfq(s.filename):
    s.size += 1
    if s.size <= s.head_size:
      s.head.add(record)
    elif s.size > s.size - s.tail_size:
      s.tail.add(record)
      if s.tail.len > s.tail_size:
        s.tail.del(0)


proc load_seq(f: string, head_size=1000000, tail_size=1000): SeqStack =
  var
    stack = newSeqStack(f, head_size, tail_size)
    c = 0
  
  stack.load()
  print(stack.size)


proc main() =
  let args = docopt("""
  Usage:
    full [options] <FILE_R1> [<FILE_R2>]

  Options:
    --stack-size INT    Size of the stack [default: 1000000]
    --tail-size INT     Size of the tail [default: 10000]
    --verbose           Add verbose output
  """,version="1.0", argv=commandLineParams())

  let
    stack_size = parseInt($args["--stack-size"])
    tail_size  = parseInt($args["--tail-size"])
    verbose    = bool(args["--verbose"])
  
  var
    r1 = load_seq($args["<FILE_R1>"], head_size=stack_size, tail_size=tail_size)
    
    
main()
