
import nimlevenshtein
import readfq
import strutils

let
  a = "ACAGCAACGTACGTAGCTAGCT"
  b = "AAGCAACGTAGGTAGCTAGCTA"

var
  ar = newSeq[string]()
   
for read in readfq("test.fa"):
  let
    usize = read.name.split("=")
  if parseInt(usize[1]) < 10:
    continue
  for target in readfq("test.fa"):
    let
      jsize = target.name.split("=")
    let
      d = distance(read.sequence, target.sequence)
      
    echo "1) ", read.sequence
    echo "2) ", target.sequence
    echo "len1=", len(read.sequence), ",len2=", len(target.sequence), "\tsize1=",usize[1], "\tsize2=", jsize[1], "\tDistance=", d