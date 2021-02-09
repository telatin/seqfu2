import klib
import os

let
  file = paramStr(1)

var
  count, sum: int

echo "Reading: ", file

proc main() =
  var
    R1: FastxRecord
    fq = xopen[GzFile](file)
  defer: fq.close()

  while fq.readFastx(R1):
    count += 1
    sum   += len(R1.seq)

  echo "Total: ", count, "; SumSize: ", sum


main()