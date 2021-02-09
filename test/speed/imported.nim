import readfq
import os

let
  file = paramStr(1)

var
  count, sum: int

echo "Reading: ", file

for rec in readfq(file):
  count += 1
  sum   += len(rec.sequence)

echo "Total: ", count, "; SumSize: ", sum
