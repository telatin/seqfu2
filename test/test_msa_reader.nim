import os, unittest

import ../src/lib/msa_reader

suite "MSA input parsing":
  test "parses interleaved Clustal alignments":
    let records = parseClustal(@[
      "CLUSTAL W multiple sequence alignment",
      "",
      "seq1  ACG-  4",
      "seq2  ACGA  4",
      "      *** ",
      "",
      "seq1  TT",
      "seq2  T-"
    ])

    check records.len == 2
    check records[0].name == "seq1"
    check records[0].sequence == "ACG-TT"
    check records[1].sequence == "ACGAT-"
    validateAlignment(records)

  test "parses interleaved Stockholm alignments":
    let records = parseStockholm(@[
      "# STOCKHOLM 1.0",
      "seq1 AC.G",
      "seq2 A-TG",
      "#=GC RF xxxx",
      "",
      "seq1 TT",
      "seq2 T-",
      "//"
    ])

    check records.len == 2
    check records[0].sequence == "AC-GTT"
    check records[1].sequence == "A-TGT-"
    validateAlignment(records)

  test "rejects an alignment without sequences":
    let records: seq[AlignmentRecord] = @[]
    expect ValueError:
      validateAlignment(records)

  test "rejects zero-length sequences":
    let records = @[
      AlignmentRecord(name: "empty", sequence: ""),
      AlignmentRecord(name: "other", sequence: "")
    ]
    expect ValueError:
      validateAlignment(records)

  test "rejects uneven sequence lengths":
    let records = @[
      AlignmentRecord(name: "first", sequence: "ACGT"),
      AlignmentRecord(name: "short", sequence: "ACG")
    ]
    expect ValueError:
      validateAlignment(records)

  test "rejects invalid sequence characters":
    let records = @[
      AlignmentRecord(name: "first", sequence: "ACGT"),
      AlignmentRecord(name: "bad", sequence: "AC1T")
    ]
    expect ValueError:
      validateAlignment(records)

  test "detects empty and unknown files":
    let
      prefix = getTempDir() / ("seqfu_msa_reader_" & $getCurrentProcessId())
      emptyPath = prefix & ".empty"
      unknownPath = prefix & ".unknown"
    defer:
      if fileExists(emptyPath): removeFile(emptyPath)
      if fileExists(unknownPath): removeFile(unknownPath)

    writeFile(emptyPath, "")
    writeFile(unknownPath, "not an alignment\n")
    expect ValueError:
      discard readAlignment(emptyPath)
    expect ValueError:
      discard readAlignment(unknownPath)

  test "validates FASTA records after parsing":
    let
      prefix = getTempDir() / ("seqfu_msa_fasta_" & $getCurrentProcessId())
      validPath = prefix & ".valid.fa"
      unevenPath = prefix & ".uneven.fa"
      zeroPath = prefix & ".zero.fa"
    defer:
      if fileExists(validPath): removeFile(validPath)
      if fileExists(unevenPath): removeFile(unevenPath)
      if fileExists(zeroPath): removeFile(zeroPath)

    writeFile(validPath, ">one\nAC-G\n>two\nACTG\n")
    writeFile(unevenPath, ">one\nACGT\n>two\nACG\n")
    writeFile(zeroPath, ">empty\n")

    let records = readAlignment(validPath)
    check records.len == 2
    check records[0].sequence == "AC-G"
    expect ValueError:
      discard readAlignment(unevenPath)
    expect ValueError:
      discard readAlignment(zeroPath)

  test "validates FASTQ quality lengths":
    let
      prefix = getTempDir() / ("seqfu_msa_fastq_" & $getCurrentProcessId())
      validPath = prefix & ".valid.fq"
      malformedPath = prefix & ".malformed.fq"
    defer:
      if fileExists(validPath): removeFile(validPath)
      if fileExists(malformedPath): removeFile(malformedPath)

    writeFile(validPath, "@one\nACGT\n+\nIIII\n@two\nAC-T\n+\nIIII\n")
    writeFile(malformedPath, "@one\nACGT\n+\nIII\n")

    check readAlignment(validPath).len == 2
    expect ValueError:
      discard readAlignment(malformedPath)
