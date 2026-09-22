import std/[os, strutils]
import readfx

type
  FilterOutputPlan* = object
    first*: string
    second*: string
    splitPairs*: bool

proc filterPtrString*(p: ptr char, length: int): string {.inline.} =
  if p != nil and length > 0:
    result = newString(length)
    copyMem(addr result[0], p, length)

proc copyFilterRecord*(record: FQRecordPtr): FQRecord {.inline.} =
  result.name = filterPtrString(record.name, record.nameLen)
  result.comment = filterPtrString(record.comment, record.commentLen)
  result.sequence = filterPtrString(record.sequence, record.sequenceLen)
  result.quality = filterPtrString(record.quality, record.qualityLen)

proc writeFilterRecord*(writer: var FastxWriter, record: FQRecordPtr) =
  writer.format = if record.qualityLen > 0: fxfFastq else: fxfFasta
  writer.writeRecord(record)

proc writeFilterRecord*(writer: var FastxWriter, record: FQRecord) =
  writer.format = if record.quality.len > 0: fxfFastq else: fxfFasta
  writer.writeRecord(record)

proc inferFilterMate*(path: string): string =
  let r1 = path.rfind("_R1")
  if r1 >= 0:
    return path[0 ..< r1] & "_R2" & path[r1 + 3 .. ^1]
  let one = path.rfind("_1.")
  if one >= 0:
    return path[0 ..< one] & "_2." & path[one + 3 .. ^1]

proc filterOutputPlan*(paired: bool, first, second: string,
                       forceInterleaved: bool): FilterOutputPlan =
  result.first = first
  if second.len > 0:
    if not paired or first.len == 0 or forceInterleaved:
      raise newException(ValueError, "-O requires paired input and -o, without --interleaved-output")
    result.second = second
    result.splitPairs = true
  elif paired and first.len > 0 and not forceInterleaved:
    result.second = inferFilterMate(first)
    result.splitPairs = result.second.len > 0

  if result.splitPairs and result.first == result.second:
    raise newException(ValueError, "R1 and R2 output paths must differ")

proc validateFilterOutputs*(plan: FilterOutputPlan, inputs: seq[string]) =
  for output in [plan.first, plan.second]:
    if output.len == 0 or output == "-":
      continue
    let target = absolutePath(output)
    for input in inputs:
      if input.len > 0 and input != "-" and
          (target == absolutePath(input) or
           (fileExists(output) and fileExists(input) and sameFile(output, input))):
        raise newException(ValueError, "Output would overwrite input: " & output)

proc openFilterWriter*(path: string, format: FastxFormat,
                       gzipLevel: int): FastxWriter =
  let destination = if path.len == 0 or path == "-": stdoutDestination()
                    else: fileDestination(path)
  fastxWriter(format, compression = path.toLowerAscii().endsWith(".gz"),
              destination = destination, compressionLevel = gzipLevel)
