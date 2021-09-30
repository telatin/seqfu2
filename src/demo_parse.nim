import os, parseutils, strutils, threadpool


type
  Charcounts = ref object
    greaterthan: int
    newlines: int

proc newCharcounts(): Charcounts =
  Charcounts(greaterthan: 0, newlines: 0)
 


proc `$`(stats: Charcounts): string =
  "(>: " & $(stats.greaterthan) & " \\n: " & $(stats.newlines ) & " $#)"   
 

proc parse(line: string, domainCode, pageTitle: var string, countViews, totalSize: var int) =
  var i = 0
  domainCode.setLen(0)
  i.inc parseUntil(line, domainCode, {' '}, i) 
  i.inc
  pageTitle.setLen(0)
  i.inc parseUntil(line, pageTitle, {' '}, i) 
  i.inc
  countViews = 0
  i.inc parseInt(line, countViews, i)
  i.inc
  totalSize = 0
  i.inc parseInt(line, totalSize, i)


proc parseChunk(chunk: string): Charcounts = 
  result = newCharcounts()
  for c in chunk:
    if c == '>':
      result.greaterthan.inc
    elif c == '\n':
      result.newlines.inc
   

#the readPageCounts procedure now includes a chunkSize parameter with 
#a default value of 1_000_000. The underscores help readability and are ignored by Nim.
proc readPageCounts(filename: string, chunkSize = 1_000_000) = 
  #var file = open(filename)
  var file: File
  if filename == "-":
    file = open(0, "r")
  else:
    file = open(filename, "r")
  
  # Defines a new responses sequence to hold the FlowVar 
  # objects that will be returned by spawn
  var responses = newSeq[FlowVar[Charcounts]]()
  # Defines a new buffer string of length equal to chunkSize. 
  # Fragments will be stored here
  var buffer = newString(chunkSize)
  # Defines a variable to store the length of the last buffer that wasn’t parsed
  var oldBufferLen = 0 
 
  while not endOfFile(file):
    # Calculates the number of characters that need to be read
    let reqSize = chunksize - oldBufferLen
    let readSize = file.readChars(buffer, oldBufferLen, reqSize) + oldBufferLen 
    var chunkLen = readSize
    while chunkLen >= 0 and buffer[chunkLen - 1] notin NewLines: 
      chunkLen.dec
    #Creates a new thread to execute the parseChunk procedure and passes a slice of the buffer that contains a fragment that can be parsed. 
    # Adds the FlowVar[string] returned by spawn to the list of responses.
    responses.add(spawn parseChunk(buffer[0 .. chunkLen-1])) 
    oldBufferLen = readSize - chunkLen 
    #Assigns the part of the fragment that wasn’t parsed to the beginning of buffer
    buffer[0 .. oldBufferLen-1] = buffer[readSize - oldBufferLen .. ^1]
  var
    countFa = 0
    countFq = 0
  for resp in responses: # Iterates through each response
    #Blocks the main thread until the response can be read and then saves the response value in the statistics variable
    let statistic = ^resp
    
    #Checks if the most popular page in a particular fragment is more popular than the one saved in the mostPopular variable. If it is, overwrites the mostPopular variable with it
    countFa += statistic.greaterthan
    countFq += statistic.newlines


  let fqRecords = countFq / 4
  echo("> ", $countFa, "\n@", $fqRecords) 
  discard gzclose(file)


proc main()  =
  var args = commandLineParams()

  if len(args) < 1:
    echo "Missing first parameter (Wikipedia counts file)"
    quit(1)

  if len(args) >= 2:
    echo "Threads: ", args[1]
    setMaxPoolSize(parseInt(args[1]))
  echo "Will try parsing: <", args[0], ">"
  readPageCounts(args[0])
 
when isMainModule:
  main()