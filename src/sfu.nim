import os
import sequtils
import strutils
import tables
import algorithm
import docopt
import posix
signal(SIG_PIPE, SIG_IGN)


type EKeyboardInterrupt = object of CatchableError
 
proc handler() {.noconv.} =
  raise newException(EKeyboardInterrupt, "Keyboard Interrupt")
 
setControlCHook(handler)


# Suite Version
import ./seqfu_utils

# Subprograms
include ./fastq_interleave
include ./fastq_deinterleave
include ./fastx_derep
include ./fastx_count
include ./fastx_view
include ./fastx_head
include ./fastx_tail
include ./fastx_stats
include ./fastx_sort
#include ./fastx_fast_derep
 

var progs = {
       "ilv": fastq_interleave,       
         "interleave": fastq_interleave,
       "dei": fastq_deinterleave,     
         "deinterleave": fastq_deinterleave,  
       "der": fastx_derep,            
         "derep": fastx_derep, 
       "cnt": fastx_count,            
         "count": fastx_count, 
       "st" : fastx_stats,            
         "stats": fastx_stats,
       "srt": fastx_sort,             
         "sort" : fastx_sort,
       "view": fastx_view,
       "head": fastx_head,
       "tail": fastx_tail,  
}.toTable

proc main() =
  
  var 
    helps = {  "interleave [ilv]"  :  "interleave FASTQ pair ends",
               "deinterleave [dei]": "deinterleave FASTQ",
               "derep [der]"       : "feature-rich dereplication of FASTA/FASTQ files",
#               "fast_derep [uniq]" : "fast dereplication of FASTA/FASTQ files",
               "count [cnt]"       : "count FASTA/FASTQ reads, pair-end aware",
               "merge [mrg]"       : "merge Illumina lanes",
               "stats [st]"        : "statistics on sequence lengths",
               "sort [srt]"        : "sort sequences by size (uniques)"
               }.toTable
    helps_last = {"view"           : "view sequences",
                  "head"           : "print first sequences",
                  "tail"           : "view last sequences",
                  "grep"           : "select sequences with patterns",
               }.toTable

  var args = commandLineParams()

  if len(args) < 1 or not progs.contains(args[0]):
    # no first argument: print help
    var 
      hkeys1 = toSeq(keys(helps))
      hkeys2 = toSeq(keys(helps_last))
      
    sort(hkeys1, proc(a, b: string): int =
      if a < b: return -1
      else: return 1
      )
    sort(hkeys2, proc(a, b: string): int =
      if a < b: return -1
      else: return 1
      )
    echo format("SeqFU - Sequence Fastx Utilities\nversion: $#\n", version())

    for k in hkeys1:
      echo format("	• $1: $2", k & repeat(" ", 20 - len(k)), helps[k])
    echo ""
    for k in hkeys2:
      echo format("	• $1: $2", k & repeat(" ", 20 - len(k)), helps_last[k])
      #echo format("	• \e[01;33m$1\e[00m: $2", k & repeat(" ", 20 - len(k)), helps[k])
    echo "\nAdd --help after each command to print usage"
  else:
    var p = args[0]; args.delete(0)
    try:
      let exitStatus = progs[p](args)
      quit(exitStatus)
    except EKeyboardInterrupt:
      quit(0)
    except:
      stderr.writeLine( getCurrentExceptionMsg() )
      quit(1)   

when isMainModule:
  main()
