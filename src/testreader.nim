import docopt
import readfq
import os
import std/strutils
 

when defined(windows):
  const libz = "zlib1.dll"
elif defined(macosx):
  const libz = "libz.dylib"
else:
  const libz = "libz.so.1"

type
  gzFile = pointer

type
  fileHandler = ref object
    bufferSize: int = 4096
    gz: bool
    gzFile: gzFile
    regFile: File
    buffer: array[4096, char]
    bufferLen: int = 0


proc gzopen(path: cstring, mode: cstring): gzFile{.cdecl, dynlib: libz,
    importc: "gzopen".}
proc gzclose(thefile: gzFile): int32{.cdecl, dynlib: libz, importc: "gzclose".}
proc gzwrite(thefile: gzFile, buf: pointer, length: int): int32{.cdecl,
    dynlib: libz, importc: "gzwrite".}

  

proc printGzipped(outFile: var fileHandler, text: string) =

  var data = text.cstring
  var dataLen = data.len

  if not outFile.gz:
    if outFile.regFile == nil:
      echo text
      return
    else:
      outFile.regFile.write(data)
      return
  
  

  while dataLen > 0:
    let bytesToCopy = min(dataLen, outFile.bufferSize - outFile.bufferLen)
    copyMem(addr outFile.buffer[outFile.bufferLen], data, bytesToCopy)
    outFile.bufferLen += bytesToCopy
    data = cast[cstring](cast[ByteAddress](data) + bytesToCopy)
    dataLen -= bytesToCopy

    if outFile.bufferLen == outFile.bufferSize:
      let bytesWritten = gzwrite(outFile.gzFile, addr outFile.buffer[0], outFile.bufferSize)
      if bytesWritten != outFile.bufferSize:
        echo "Error writing to gzip stream"
        discard gzclose(outFile.gzFile)
        outFile.gzFile = nil
        return
      outFile.bufferLen = 0

  if text.len == 0 and outFile.bufferLen > 0:
    let bytesWritten = gzwrite(outFile.gzFile, addr outFile.buffer[0], outFile.bufferLen)
    if bytesWritten != outFile.bufferLen:
      echo "Error writing to gzip stream"
      discard gzclose(outFile.gzFile)
      outFile.gzFile = nil
      return
    outFile.bufferLen = 0
    discard gzclose(outFile.gzFile)
    outFile.gzFile = nil


proc main(): int =
  let args = docopt("""
  Usage: reader [options] <fasta>

  Files:
    <fasta>                    FASTA file to filter

  Options:
    -z, --gzip                 Output to gzip
    -o, --output <output>      Output file [default: /dev/stdout]
    """, version="1.0", argv=commandLineParams())

  let
    gzBool = bool(args["--gzip"])

  var
    writeOut = if $args["--output"] == "/dev/stdout" and not gzBool:
        open($args["--output"], fmWrite)
      else:
        nil
    outFile = fileHandler(gz: gzBool, file: writeOut, gzFile: nil)


  for record in readfq($args["<fasta>"]):
    outFile.printGzipped($record & "\n")

    
  if gzBool:
    outFile.printGzipped("")

when isMainModule:
  discard main()