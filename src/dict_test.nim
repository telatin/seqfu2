import tables
var
  this =initTable[string, initTable[string, string]() ]() 
  elem = @["one", "two", "three"]
  r    = @["R1", "R2"]

for e in elem:
  echo "### ", e
  for dir in r:
    if e in this:
      echo "- Got:", e
      this[e][dir] = "second"
    else:
      echo "- To do"
      this[e] = initTable[string, string]()
      this[e][dir] = "hello"


echo this
