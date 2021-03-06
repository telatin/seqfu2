import os
import sequtils
import strutils
import tables
import algorithm
import docopt

 

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
include ./fastx_grep
include ./fastq_merge_lanes
include ./fastx_rc
include ./fastx_qual
include ./fastq_merge
include ./fastx_cat
include ./fastx_metadata
include ./fastx_tabulate

# Experimental
include ./fastx_stats2
include ./fastx_count_threads

var progs = {
       "cat": fastx_cat,
       "ilv": fastq_interleave,       
         "interleave": fastq_interleave,
       "dei": fastq_deinterleave,     
         "deinterleave": fastq_deinterleave,  
       "der": fastx_derep,            
         "derep": fastx_derep, 
         "dereplicate": fastx_derep, 
         "uniques": fastx_derep, 
       "cnt": fastx_count_threads,      # Experimental     
         "count": fastx_count_threads,  # Experimental
       "st" : fastx_stats,            
         "stats": fastx_stats,
         "stat": fastx_stats,
       "stats2": fastx_stats_v2,        # Experimental
       "count-legacy": fastx_count, 
       "rc" : fastx_rc,
       "srt": fastx_sort,             
       "sort" : fastx_sort,
       "ill" : fastq_merge_lanes,
         "lanes" : fastq_merge_lanes,
       "mrg" : fastq_merge,
         "merge" : fastq_merge,
       "qual": fastx_qual,
       "view": fastx_view,
       "grep": fastx_grep,
       "head": fastx_head,
       "tail": fastx_tail,
       "tabulate": fastx_tabulate,
            "tab": fastx_tabulate,
       "metadata": fastx_metadata,
        "met": fastx_metadata   
}.toTable

proc main(args: var seq[string]): int =
  
  var 
    helps = {  "interleave [ilv]"  :  "interleave FASTQ pair ends",
               "deinterleave [dei]": "deinterleave FASTQ",
               "derep [der]"       : "feature-rich dereplication of FASTA/FASTQ files",
#              "merge [mrg]"       : "join Paired End reads",
               "count [cnt]"       : "count FASTA/FASTQ reads, pair-end aware",
               "lanes [mrl]"       : "merge Illumina lanes",
               "stats [st]"        : "statistics on sequence lengths",
               "sort [srt]"        : "sort sequences by size (uniques)",
               "metadata [met]"    : "print a table of FASTQ reads (mapping files)",
               }.toTable

    helps_last = {"cat"            : "concatenate FASTA/FASTQ files",
                  "head"           : "print first sequences",
                  "tail"           : "view last sequences",
                  "grep"           : "select sequences with patterns",
                  "rc"             : "reverse complement strings or files",
                  "tab"            : "tabulate reads to TSV (and viceversa)",
                  "view"           : "view sequences with colored quality and oligo matches",
               }.toTable

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
    echo format("SeqFu - Sequence Fastx Utilities\nversion: $#\n", version())

    for k in hkeys1:
      echo "  ", format("· $1: $2", k & repeat(" ", 20 - len(k)), helps[k])
    echo ""
    for k in hkeys2:
      echo "  ", format("· $1: $2", k & repeat(" ", 20 - len(k)), helps_last[k])
      
    echo "\nAdd --help after each command to print usage"
    0
  else:
    var p = args[0]
    var pargs = args[1 .. ^1]
    progs[args[0]](pargs)

when isMainModule:
  try:
    main_helper(main)
  except IOError:
    stderr.writeLine("Quitting...")
    quit(0)
  