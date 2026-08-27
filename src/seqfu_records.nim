import strutils

import readfx
import ./seqfu_legacy_fastx

proc seqfuQualToChar*(q: int): char =
  ## Return the FASTQ quality character for SeqFu's default Phred+33 handling.
  (q + 33).char

proc toFQRecord*(record: FastxRecord): FQRecord =
  ## Transition adapter for old FastxRecord-shaped code.
  result.name = record.name
  result.comment = record.comment
  result.sequence = record.seq
  result.quality = record.qual
  result.status = record.status
  result.lastChar = record.lastChar

proc formatSeqfuRecord*(record: FQRecord,
                        forceFasta = false,
                        forceFastq = false,
                        stripComments = false,
                        defaultQual = 33,
                        rename = "",
                        keepEmptyCommentSpace = true): string =
  ## Format a ReadFX record using SeqFu's current output switches.
  var name = if rename.len > 0: rename else: record.name

  if not stripComments:
    if record.comment.len > 0:
      name.add(" " & record.comment)
    elif keepEmptyCommentSpace:
      name.add(" ")

  if record.quality.len > 0 and record.sequence.len != record.quality.len:
    raise newException(ValueError,
      "Sequence <" & record.name & ">: quality and sequence length mismatch.")

  if record.quality.len > 0 and not forceFasta:
    result = "@" & name & "\n" & record.sequence & "\n+\n" & record.quality
  elif forceFastq:
    result = "@" & name & "\n" & record.sequence & "\n+\n" &
      repeat(seqfuQualToChar(defaultQual), record.sequence.len)
  else:
    result = ">" & name & "\n" & record.sequence

proc formatSeqfuRecord*(record: FastxRecord,
                        forceFasta = false,
                        forceFastq = false,
                        stripComments = false,
                        defaultQual = 33): string =
  ## Format a legacy FastxRecord-shaped record through ReadFX's record type.
  formatSeqfuRecord(record.toFQRecord(),
                    forceFasta = forceFasta,
                    forceFastq = forceFastq,
                    stripComments = stripComments,
                    defaultQual = defaultQual,
                    keepEmptyCommentSpace = false)
