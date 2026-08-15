import iterutils
import sequtils
import readfq
import docopt
import seqfu_utils

template initClosure(id:untyped,iter:untyped) =
  let id = iterator():auto {.closure.} =
    for x in iter:
      yield x

iterator letters: auto =
  for c in 'a' .. 'z':
    yield c


proc main(argv: var seq[string]): int =
  let args =  docopt("""
  USAGE:
    fqpair FILE1 FILE2
  """, argv=argv)

  let
    file1 = $args["FILE1"]
    file2 = $args["FILE2"]

  echo "Reading file1: ", file1
  echo "Reading file2: ", file2

  initClosure(f1,readfq(file1))
  initClosure(f2,readfq(file2))

  var
    c = 0
  for (fwd, rev) in zip(f1, f2):
    var
        newseq : FQRecord
    
    newseq = fwd
    newseq.sequence &= "*"
    c = c + 1
    echo c, "\tfwd: ", fwd.name, " : ", rev.name
    echo newseq.sequence


when isMainModule:
  main_helper(main)
