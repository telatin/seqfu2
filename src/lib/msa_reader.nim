import os, strutils, tables

import readfq

import ./klib

type
  AlignmentRecord* = object
    name*: string
    sequence*: string

  AlignmentFormat = enum
    afUnknown, afFasta, afFastq, afClustal, afStockholm

proc detectAlignmentFormat(line: string): AlignmentFormat =
  if line.startsWith("# STOCKHOLM"):
    return afStockholm
  if line.startsWith("CLUSTAL") or line.startsWith("MUSCLE"):
    return afClustal
  if line.startsWith('>'):
    return afFasta
  if line.startsWith('@'):
    return afFastq

proc validAlignedSequence(sequence: string, allowDot: bool): bool =
  if sequence.len == 0:
    return false
  for c in sequence:
    if c in {'A'..'Z', 'a'..'z', '-', '*', '?'}:
      continue
    if allowDot and c == '.':
      continue
    return false
  return true

proc hasNumericPosition(fields: seq[string]): bool =
  if fields.len == 2:
    return true
  if fields.len != 3 or fields[2].len == 0:
    return false
  for c in fields[2]:
    if c notin {'0'..'9'}:
      return false
  return true

proc parseClustal*(lines: openArray[string]): seq[AlignmentRecord] =
  var idMap = initTable[string, int]()

  for lineNumber, line in lines:
    let stripped = line.strip()
    if stripped.len == 0:
      continue
    if stripped.startsWith("CLUSTAL") or stripped.startsWith("MUSCLE"):
      continue
    if stripped[0] in {'*', ':', '.'}:
      continue

    let fields = stripped.splitWhitespace()
    if fields.len < 2:
      raise newException(ValueError,
        "Malformed Clustal row at line " & $(lineNumber + 1))
    if not hasNumericPosition(fields) or not validAlignedSequence(fields[1], true):
      raise newException(ValueError,
        "Malformed Clustal sequence row at line " & $(lineNumber + 1))

    let
      id = fields[0]
      sequence = fields[1].replace('.', '-')
    if id in idMap:
      result[idMap[id]].sequence.add(sequence)
    else:
      idMap[id] = result.len
      result.add(AlignmentRecord(name: id, sequence: sequence))

proc parseStockholm*(lines: openArray[string]): seq[AlignmentRecord] =
  var idMap = initTable[string, int]()

  for lineNumber, line in lines:
    let stripped = line.strip()
    if stripped.len == 0 or stripped[0] == '#':
      continue
    if stripped == "//":
      break

    let fields = stripped.splitWhitespace()
    if fields.len < 2 or not hasNumericPosition(fields) or
        not validAlignedSequence(fields[1], true):
      raise newException(ValueError,
        "Malformed Stockholm sequence row at line " & $(lineNumber + 1))

    let
      id = fields[0]
      sequence = fields[1].replace('.', '-')
    if id in idMap:
      result[idMap[id]].sequence.add(sequence)
    else:
      idMap[id] = result.len
      result.add(AlignmentRecord(name: id, sequence: sequence))

proc validateAlignment*(records: openArray[AlignmentRecord]) =
  if records.len == 0:
    raise newException(ValueError, "No sequences found in alignment")

  let expectedLength = records[0].sequence.len
  for record in records:
    if record.name.len == 0:
      raise newException(ValueError, "Alignment contains a sequence without an identifier")
    if record.sequence.len == 0:
      raise newException(ValueError,
        "Sequence '" & record.name & "' has zero length")
    if not validAlignedSequence(record.sequence, true):
      raise newException(ValueError,
        "Sequence '" & record.name & "' contains invalid alignment characters")
    if record.sequence.len != expectedLength:
      raise newException(ValueError,
        "Sequence '" & record.name & "' has length " & $record.sequence.len &
        ", expected " & $expectedLength)

proc readAlignment*(filename: string): seq[AlignmentRecord] =
  if not fileExists(filename):
    raise newException(IOError, "File not found: " & filename)

  var
    input: Bufio[GzFile]
    line: string
    firstLine = ""

  discard input.open(filename)

  while input.readLine(line):
    if line.strip().len > 0:
      firstLine = line.strip()
      break
  discard input.close()

  if firstLine.len == 0:
    raise newException(ValueError, "Alignment file is empty")

  case detectAlignmentFormat(firstLine)
  of afFasta:
    for record in readfq(filename):
      result.add(AlignmentRecord(name: record.name, sequence: record.sequence.strip()))
  of afFastq:
    for record in readfq(filename):
      let sequence = record.sequence.strip()
      if record.quality.len != sequence.len:
        raise newException(ValueError,
          "FASTQ record '" & record.name & "' has sequence length " &
          $sequence.len & " but quality length " & $record.quality.len)
      result.add(AlignmentRecord(name: record.name, sequence: sequence))
  of afClustal:
    var lines: seq[string]
    discard input.open(filename)
    while input.readLine(line):
      lines.add(line)
    discard input.close()
    result = parseClustal(lines)
  of afStockholm:
    var lines: seq[string]
    discard input.open(filename)
    while input.readLine(line):
      lines.add(line)
    discard input.close()
    result = parseStockholm(lines)
  of afUnknown:
    raise newException(ValueError,
      "Unknown alignment format; supported formats are FASTA, FASTQ, Clustal, and Stockholm")

  validateAlignment(result)
