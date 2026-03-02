import klib
import malebolgia
import tableview

import tables, strutils, algorithm
import std/atomics
from os import fileExists
import docopt
import ./seqfu_utils




type
  Stats = object
    filename: string
    sample: string
    reads: int
    strand: string
    errorMsg: string
    completionOrder: int

type
  SeqfuCount = object
    key: string
    forward, reverse: Stats
    hasForward, hasReverse: bool

type
  CountJob = object
    niceFilename: string
    sample: string
    filename: string
    strand: string
    inputOrder: int
    completionOrder: int
    completionCounter: ptr Atomic[int]
    result: Stats

type
  SortMode = enum
    sortInput,
    sortName,
    sortCounts,
    sortNone

type
  UnpairedRow = object
    stats: Stats
    key: string

type
  PairSortRow = object
    key: string
    primaryName: string
    primaryCount: int
    completionOrder: int

proc newStats(): Stats =
  Stats(filename: "", sample: "", strand: "", reads: 0, errorMsg: "", completionOrder: -1)

proc `$`(s: Stats): string =
  "Stats: " & s.strand & "\t" & s.filename & "\tsample=" & s.sample & "\t" & $s.reads

proc newSeqfuCount(key = ""): SeqfuCount =
  SeqfuCount(
    key: key,
    forward: newStats(),
    reverse: newStats(),
    hasForward: false,
    hasReverse: false
  )

proc countReads(niceFilename, sample, filename, strand: string): Stats {.gcsafe.} =
  
  try:
    var c = 0
    var f = xopen[GzFile](filename)
    defer:
      f.close()
    var r: FastxRecord
    while f.readFastx(r):
      c += 1
    result = Stats(
      filename: niceFilename,
      sample: sample,
      strand: strand,
      reads: c,
      errorMsg: "",
      completionOrder: -1
    )
  except Exception as e:
    result = Stats(
      filename: niceFilename,
      sample: sample,
      reads: -1,
      strand: strand,
      errorMsg: e.msg,
      completionOrder: -1
    )

proc processCountJob(job: ptr CountJob) {.gcsafe.} =
  job[].result = countReads(job[].niceFilename, job[].sample, job[].filename, job[].strand)
  if job[].completionCounter != nil:
    job[].completionOrder = fetchAdd(job[].completionCounter[], 1, moRelaxed)
  else:
    job[].completionOrder = job[].inputOrder

proc parseSortMode(raw: string, mode: var SortMode): bool =
  case toLowerAscii(raw)
  of "input":
    mode = sortInput
  of "name":
    mode = sortName
  of "counts":
    mode = sortCounts
  of "none":
    mode = sortNone
  else:
    return false
  return true

proc renderStatsKey(s: Stats, abspath, basename: bool): string =
  if abspath:
    result = absolutePath(s.filename)
  elif basename:
    result = extractFilename(s.filename)
  else:
    result = s.filename

proc pairPrimaryName(s: SeqfuCount, basename: bool): string =
  if s.hasForward and s.forward.filename.len > 0:
    result = s.forward.filename
  elif s.hasReverse and s.reverse.filename.len > 0:
    result = s.reverse.filename
  else:
    result = s.key
  if basename and result.len > 0:
    result = extractFilename(result)

proc pairPrimaryCount(s: SeqfuCount): int =
  if s.hasForward:
    result = s.forward.reads
  elif s.hasReverse:
    result = s.reverse.reads
  else:
    result = -1

proc toTableData(rows: seq[seq[string]]): TableData =
  let headers = @["File", "Reads", "Type"]
  var widths = @[headers[0].len, headers[1].len, headers[2].len]
  for row in rows:
    for i in 0 ..< min(row.len, widths.len):
      if row[i].len > widths[i]:
        widths[i] = row[i].len
  TableData(
    headers: headers,
    rows: rows,
    columnWidths: widths,
    columnTypes: @[ctString, ctInt, ctString],
    hiddenColumns: @[false, false, false]
  )

proc emitPairedRow(
  key: string,
  j: SeqfuCount,
  basename: bool,
  interactiveTable: bool,
  tableRows: var seq[seq[string]]
): int =
  var
    printForward = j.forward.filename
    printReverse = j.reverse.filename
  if basename:
    if printForward.len > 0:
      printForward = extractFilename(printForward)
    if printReverse.len > 0:
      printReverse = extractFilename(printReverse)

  let forwardFailed = j.hasForward and j.forward.reads < 0
  let reverseFailed = j.hasReverse and j.reverse.reads < 0

  if forwardFailed or reverseFailed:
    if forwardFailed:
      let msg = if j.forward.errorMsg.len > 0: j.forward.errorMsg else: "unknown error"
      stderr.writeLine("ERROR: Unable to count reads in ", printForward, ": ", msg)
    if reverseFailed:
      let msg = if j.reverse.errorMsg.len > 0: j.reverse.errorMsg else: "unknown error"
      stderr.writeLine("ERROR: Unable to count reads in ", printReverse, ": ", msg)
    result = 1
    if j.hasForward:
      let fType = if forwardFailed: "<Error:R1 read failure>" else: "<Error:R1>"
      if interactiveTable:
        tableRows.add(@[printForward, $j.forward.reads, fType])
      else:
        echo printForward, "\t", j.forward.reads, "\t", fType
    if j.hasReverse:
      let rType = if reverseFailed: "<Error:R2 read failure>" else: "<Error:R2>"
      if interactiveTable:
        tableRows.add(@[printReverse, $j.reverse.reads, rType])
      else:
        echo printReverse, "\t", j.reverse.reads, "\t", rType
  elif j.hasForward and j.hasReverse:
    if j.forward.reads == j.reverse.reads:
      if interactiveTable:
        tableRows.add(@[printForward, $j.forward.reads, "Paired"])
      else:
        echo printForward, "\t", j.forward.reads, "\tPaired"
    else:
      stderr.writeLine("ERROR: Counts in R1 and R2 files do not match for sample ", key, ".")
      stderr.writeLine("  R1: ", printForward, " -> ", j.forward.reads)
      stderr.writeLine("  R2: ", printReverse, " -> ", j.reverse.reads)
      result = 1
      if interactiveTable:
        tableRows.add(@[printForward, $j.forward.reads, "<Error:R1>"])
        tableRows.add(@[printReverse, $j.reverse.reads, "<Error:R2>"])
      else:
        echo printForward, "\t", j.forward.reads, "\t<Error:R1>"
        echo printReverse, "\t", j.reverse.reads, "\t<Error:R2>"
  elif j.hasForward and not j.hasReverse:
    if interactiveTable:
      tableRows.add(@[printForward, $j.forward.reads, "SE"])
    else:
      echo printForward, "\t", j.forward.reads, "\tSE"
  elif j.hasReverse and not j.hasForward:
    stderr.writeLine("ERROR: Reverse file without matching forward file for sample ", key, ".")
    stderr.writeLine("  R2: ", printReverse, " -> ", j.reverse.reads)
    result = 1
    if interactiveTable:
      tableRows.add(@[printReverse, $j.reverse.reads, "<Error:R2 without R1>"])
    else:
      echo printReverse, "\t", j.reverse.reads, "\t<Error:R2 without R1>"
  else:
    stderr.writeLine("ERROR: No readable records found for sample ", key, ".")
    result = 1
  
   
  
    
proc fastx_count_threads_v3(argv: var seq[string]): int =
  let doc = """
Usage: count [options] [<inputfile> ...]

Count sequences in paired-end aware format

  Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -u, --unpair           Print separate records for paired end files
  -f, --for-tag R1       Forward tag [default: auto]
  -r, --rev-tag R2       Reverse tag [default: auto]
  -s, --sort MODE        Sort output: input|name|counts|none [default: input]
      --reverse-sort     Reverse selected sort order
  -T, --interactive-table  Open interactive table view (TUI)
  -t, --threads INT      Working threads [default: $1]
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """

  let args = docopt(
    doc.multiReplace(("$1", $ThreadPoolSize)),
    version=version(),
    argv=argv
  )

  verbose = args["--verbose"]

  var
    files: seq[string]

  var threads = 1
  try:
    threads = parseInt($args["--threads"])
  except ValueError:
    stderr.writeLine("ERROR: --threads must be an integer >= 1.")
    return 1
  if threads < 1:
    stderr.writeLine("ERROR: --threads must be >= 1.")
    return 1

  var sortMode = sortInput
  if not parseSortMode($args["--sort"], sortMode):
    stderr.writeLine("ERROR: --sort must be one of: input, name, counts, none.")
    return 1

  let
    reverseSort = args["--reverse-sort"]
    interactiveTable = args["--interactive-table"]
    abspath = args["--abs-path"]
    basename = args["--basename"]
    unpaired = args["--unpair"]
    pattern1 = $args["--for-tag"]
    pattern2 = $args["--rev-tag"]
    legacy = {"for": "Paired", "rev": "Paired:R2", "unknown": "SE"}.toTable

  if args["<inputfile>"].len() == 0:
    if getEnv("SEQFU_QUIET") == "":
      stderr.writeLine("[seqfu count] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
    files.add("-")
  else:
    for file in args["<inputfile>"]:
      if fileExists(file) or file == "-":
        if abspath:
          files.add(absolutePath(file))
        else:
          files.add(file)
      else:
        stderr.writeLine("WARNING: File not found, skipping: ", file)

  var
    test = initTable[string, SeqfuCount](max(32, files.len * 2))
    orderedKeys = newSeqOfCap[string](files.len)
    completionByKey = initTable[string, int](max(32, files.len * 2))
    jobs = newSeqOfCap[CountJob](files.len)
    completionCounter: Atomic[int]
    completionCounterPtr: ptr Atomic[int] = nil

  let needCompletionOrder = sortMode == sortNone
  let canParallel = threads > 1 and files.len > 1 and ("-" notin files)
  if canParallel and sortMode == sortNone:
    completionCounter.store(0, moRelaxed)
    completionCounterPtr = addr completionCounter

  for idx, file in files:
    let filename = getStrandFromFilename(file, forPattern=pattern1, revPattern=pattern2)
    if verbose:
      stderr.writeLine("Processing: ", file, " as ", filename.strand)
    jobs.add(
      CountJob(
        niceFilename: file,
        sample: filename.splittedFile,
        filename: file,
        strand: filename.strand,
        inputOrder: idx,
        completionOrder: idx,
        completionCounter: completionCounterPtr,
        result: newStats()
      )
    )

  if canParallel:
    let parallelChunk = min(threads, ThreadPoolSize)
    var m = createMaster()
    if parallelChunk >= ThreadPoolSize:
      m.awaitAll:
        for i in 0 ..< jobs.len:
          m.spawn processCountJob(addr jobs[i])
    else:
      var start = 0
      while start < jobs.len:
        let stopAt = min(start + parallelChunk, jobs.len)
        m.awaitAll:
          for i in start ..< stopAt:
            m.spawn processCountJob(addr jobs[i])
        start = stopAt
  else:
    if threads > 1 and ("-" in files) and verbose:
      stderr.writeLine("INFO: Disabling parallel count because input includes STDIN ('-').")
    for i in 0 ..< jobs.len:
      processCountJob(addr jobs[i])

  var unpairedRows = newSeqOfCap[UnpairedRow](jobs.len)
  for i in 0 ..< jobs.len:
    var stats = jobs[i].result
    stats.completionOrder = jobs[i].completionOrder
    if verbose:
      stderr.writeLine("Got counts for ", stats.filename, ": ", stats.reads)
    if unpaired:
      unpairedRows.add(UnpairedRow(stats: stats, key: renderStatsKey(stats, abspath, basename)))
    else:
      let key = if len(stats.sample) > 0: stats.sample else: stats.filename
      if key == "":
        continue

      let isNew = key notin test
      discard test.mgetOrPut(key, newSeqfuCount(key))
      if isNew:
        orderedKeys.add(key)
        if needCompletionOrder:
          completionByKey[key] = stats.completionOrder
      elif needCompletionOrder and stats.completionOrder < completionByKey[key]:
        completionByKey[key] = stats.completionOrder

      if stats.strand == "rev":
        test[key].reverse = stats
        test[key].hasReverse = true
      else:
        test[key].forward = stats
        test[key].hasForward = true

  if unpaired:
    case sortMode
    of sortName:
      sort(unpairedRows, proc(a, b: UnpairedRow): int =
        if a.key < b.key: -1
        elif a.key > b.key: 1
        elif a.stats.reads > b.stats.reads: -1
        elif a.stats.reads < b.stats.reads: 1
        else: 0
      )
    of sortCounts:
      sort(unpairedRows, proc(a, b: UnpairedRow): int =
        if a.stats.reads > b.stats.reads: -1
        elif a.stats.reads < b.stats.reads: 1
        else:
          if a.key < b.key: -1
          elif a.key > b.key: 1
          else: 0
      )
    of sortNone:
      sort(unpairedRows, proc(a, b: UnpairedRow): int =
        if a.stats.completionOrder < b.stats.completionOrder: -1
        elif a.stats.completionOrder > b.stats.completionOrder: 1
        else: 0
      )
    of sortInput:
      discard

    if reverseSort:
      reverse(unpairedRows)

    var
      e = 0
      tableRows = newSeqOfCap[seq[string]](unpairedRows.len)
    for row in unpairedRows:
      if row.stats.reads < 0:
        let msg = if row.stats.errorMsg.len > 0: row.stats.errorMsg else: "unknown error"
        stderr.writeLine("ERROR: Unable to count reads in ", row.stats.filename, ": ", msg)
        if interactiveTable:
          tableRows.add(@[row.key, $row.stats.reads, "<Error>"])
        else:
          echo row.key, "\t", row.stats.reads, "\t<Error>"
        e += 1
      else:
        let strandLabel = if row.stats.strand in legacy: legacy[row.stats.strand] else: "SE"
        if interactiveTable:
          tableRows.add(@[row.key, $row.stats.reads, strandLabel])
        else:
          echo row.key, "\t", row.stats.reads, "\t", strandLabel
    if interactiveTable:
      viewTable(toTableData(tableRows), filename = "seqfu count", hasHeader = true)
    if e > 0:
      return 1
    return 0

  var tableRows = newSeqOfCap[seq[string]](orderedKeys.len * 2)
  if sortMode == sortInput:
    var e = 0
    if reverseSort:
      for i in countdown(orderedKeys.high, 0):
        let key = orderedKeys[i]
        e += emitPairedRow(key, test[key], basename, interactiveTable, tableRows)
    else:
      for key in orderedKeys:
        e += emitPairedRow(key, test[key], basename, interactiveTable, tableRows)
    if interactiveTable:
      viewTable(toTableData(tableRows), filename = "seqfu count", hasHeader = true)
    if e > 0:
      return 1
    return 0

  var pairsToPrint = newSeqOfCap[PairSortRow](orderedKeys.len)
  for key in orderedKeys:
    let pair = test[key]
    pairsToPrint.add(
      PairSortRow(
        key: key,
        primaryName: pairPrimaryName(pair, basename),
        primaryCount: pairPrimaryCount(pair),
        completionOrder: completionByKey.getOrDefault(key, 0)
      )
    )

  case sortMode
  of sortName:
    sort(pairsToPrint, proc(a, b: PairSortRow): int =
      if a.primaryName < b.primaryName: -1
      elif a.primaryName > b.primaryName: 1
      elif a.primaryCount > b.primaryCount: -1
      elif a.primaryCount < b.primaryCount: 1
      else: 0
    )
  of sortCounts:
    sort(pairsToPrint, proc(a, b: PairSortRow): int =
      if a.primaryCount > b.primaryCount: -1
      elif a.primaryCount < b.primaryCount: 1
      else:
        if a.primaryName < b.primaryName: -1
        elif a.primaryName > b.primaryName: 1
        else: 0
    )
  of sortNone:
    sort(pairsToPrint, proc(a, b: PairSortRow): int =
      if a.completionOrder < b.completionOrder: -1
      elif a.completionOrder > b.completionOrder: 1
      else: 0
    )
  of sortInput:
    discard

  if reverseSort:
    reverse(pairsToPrint)

  var e = 0
  for row in pairsToPrint:
    e += emitPairedRow(row.key, test[row.key], basename, interactiveTable, tableRows)
  if interactiveTable:
    viewTable(toTableData(tableRows), filename = "seqfu count", hasHeader = true)

  if e > 0:
    return 1
  return 0
