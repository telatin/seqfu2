import os
import strutils
import tables

import ./types

proc stripFastqExt(name: string): string =
  result = name
  if result.endsWith(".gz"):
    result = result[0 ..< result.len - 3]
  for ext in [".fastq", ".fq", ".fasta", ".fa"]:
    if result.endsWith(ext):
      result = result[0 ..< result.len - ext.len]
      break

proc replaceAt(source: string, pos: int, oldLen: int, replacement: string): string =
  result = ""
  if pos > 0:
    result.add(source[0 ..< pos])
  result.add(replacement)
  let tailStart = pos + oldLen
  if tailStart < source.len:
    result.add(source[tailStart .. ^1])

proc sampleIdFromFile(filename, tag: string): string =
  let name = extractFilename(filename)
  let pos = if tag.len > 0: name.find(tag) else: -1
  if pos >= 0:
    result = name[0 ..< pos]
  else:
    result = stripFastqExt(name)

proc sampleIdFromPair*(r1, r2, fwdTag, revTag: string): string =
  let fromR1 = sampleIdFromFile(r1, fwdTag)
  let fromR2 = sampleIdFromFile(r2, revTag)
  if fromR1.len > 0:
    fromR1
  elif fromR2.len > 0:
    fromR2
  else:
    stripFastqExt(extractFilename(r1))

proc discoverPairs*(files: seq[string], fwdTag, revTag: string,
                    warnings: var seq[string]): seq[PairInput] =
  if files.len == 2:
    return @[PairInput(
      sampleId: sampleIdFromPair(files[0], files[1], fwdTag, revTag),
      r1: files[0],
      r2: files[1]
    )]

  var present = initTable[string, bool]()
  var used = initTable[string, bool]()
  for file in files:
    present[file] = true

  for file in files:
    let pos = file.find(fwdTag)
    if pos < 0:
      continue

    let expectedR2 = replaceAt(file, pos, fwdTag.len, revTag)
    if present.hasKey(expectedR2):
      result.add(PairInput(
        sampleId: sampleIdFromPair(file, expectedR2, fwdTag, revTag),
        r1: file,
        r2: expectedR2
      ))
      used[file] = true
      used[expectedR2] = true
    else:
      warnings.add("WARNING: unmatched forward file excluded: " & file)

  for file in files:
    if used.hasKey(file):
      continue
    if file.find(revTag) >= 0:
      warnings.add("WARNING: unmatched reverse file excluded: " & file)
    elif file.find(fwdTag) < 0:
      warnings.add("WARNING: unrecognized file excluded: " & file)
