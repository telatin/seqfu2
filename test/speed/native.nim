import readfx
import readfx/nimklib as fxio
import os

let
  file = paramStr(1)

var
  count, sum: int

echo "Reading: ", file

proc main() =
  var
    R1: FQRecord
    fq = fxio.xopen[fxio.GzFile](file)
  defer: discard fq.close()

  while fxio.readFastx(fq, R1):
    count += 1
    sum   += len(R1.sequence)

  echo "Total: ", count, "; SumSize: ", sum


main()
