#!/usr/bin/env python
import os
import sys
import gzip
import random
from pathlib import Path
from typing import Tuple, Iterator, TextIO, Union

def readfa(fasta_filename: Union[str, Path]) -> Iterator[Tuple[str, str, str]]:
    """
    Generator function to parse FASTA format files (gzipped or plain text).
    
    Args:
        fasta_filename (Union[str, Path]): Path to the FASTA file
            Supports both .gz and regular files
    
    Yields:
        Tuple[str, str, str]: Contains (sequence_id, comment, sequence)
            sequence_id: The identifier after '>' without spaces
            comment: Additional text after the id (may be empty)
            sequence: The complete sequence with whitespace removed
    
    Example:
        For FASTA entry:
        >seq1 sample sequence
        ACGT
        TCGA
        
        Yields: ("seq1", "sample sequence", "ACGTTCGA")
    """
    # Initialize variables
    current_id = ""
    current_comment = ""
    current_sequence = []
    
    # Determine if file is gzipped based on extension
    fasta_path = Path(fasta_filename)
    is_gzipped = fasta_path.suffix.lower() == '.gz'
    
    # Open file with appropriate method
    open_func = gzip.open if is_gzipped else open
    mode = 'rt' if is_gzipped else 'r'
    
    with open_func(fasta_path, mode) as fasta_file:
        for line in fasta_file:
            line = line.strip()
            
            # Skip empty lines
            if not line:
                continue
                
            # Handle header lines
            if line.startswith('>'):
                # Yield previous sequence if it exists
                if current_id:
                    yield (current_id, 
                          current_comment, 
                          ''.join(current_sequence))
                
                # Parse new header
                header = line[1:].strip()
                # Split into ID and comment (if any)
                parts = header.split(maxsplit=1)
                current_id = parts[0]
                current_comment = parts[1] if len(parts) > 1 else ""
                current_sequence = []
                
            # Handle sequence lines
            else:
                current_sequence.append(line)
        
        # Yield the last sequence if it exists
        if current_id:
            yield (current_id, 
                  current_comment, 
                  ''.join(current_sequence))

def check_comp(dna_string):
    """
    Check if DNA only contains ACGT acgt or N n
    """
    return all(x in "ACGTacgtNn" for x in dna_string)

def revcompl(dna_string):
    """
    Reverse-complement a DNA sequence.
    """
    # Create a translation table for reverse-complementing
    base_complement = str.maketrans("ACGTacgt", "TGCAtgca")

    # Reverse the sequence and apply the complement
    return dna_string[::-1].translate(base_complement)


def calculate_overlap(read_length: int, fragment_length: int) -> int:
    """
    Calculate the overlap between paired-end reads.
    
    Parameters:
        read_length (int): Length of each read
        fragment_length (int): Total length of the DNA fragment
    
    Returns:
        int: Number of overlapping bases
    
    Example:
        read_length = 300, fragment_length = 422
        overlap = (2 * 300) - 422 = 178
    """
    combined_length = 2 * read_length
    overlap = combined_length - fragment_length
    return max(0, overlap)


if __name__ == "__main__":
    # Example usage
    import argparse
    args = argparse.ArgumentParser()
    args.add_argument('fasta_file', help='Input FASTA file')
    args.add_argument('-l', '--len', type=int, default=150, help="Read lenght (default: %(default)s)")
    args.add_argument('-m', '--min', type=int, default=180, help="Minimum fragment size (default: %(default)s)")
    args.add_argument('-x', '--max', type=int, default=400, help="Maximum fragment size (default: %(default)s)")
    args.add_argument('-v', '--min-ov', type=int, default=20, help="Minimum overlap length (default: %(default)s)")
    args.add_argument('-0', '--overlapping-ratio', type=float, default=0.5, help="Ratio of overlapping reads (default: %(default)s)")
    args.add_argument('-n', '--num', type=int, default=100, help="Number of fragments to generate (default: %(default)s)")
    args.add_argument('-o', '--outprefix', default='pe_sim/reads', help="Output directory (default: %(default)s)")
    args = args.parse_args()

    gap = "N" * (2 * args.max)
    large_dna = ""

    outdir = os.path.dirname(args.outprefix)
    outprefix = os.path.basename(args.outprefix)
    # make dir if not exist
    os.makedirs(outdir, exist_ok=True)
    print("Output directory:\t", outdir, file=sys.stderr)

    file_1 = f"{outdir}/{outprefix}_1.fastq"
    file_2 = f"{outdir}/{outprefix}_2.fastq"
    file_x = f"{outdir}/{outprefix}_fragment.fastq"
    file_dist = f"{outdir}/{outprefix}_dist.tsv"

    qual = "I" * args.len
    print("Output files:\n\t", file_1, "\n\t", file_2, file=sys.stderr)
    # Create file handles for the two output files (create if they don't exist)
    fh1 = open(file_1, 'w')
    fh2 = open(file_2, 'w')
    fhx = open(file_x, 'w')
    fh_dist = open(file_dist, 'w')

    # Read the FASTA file

    for seq_id, comment, seq in readfa(args.fasta_file):
        if len(large_dna) > 0:
            large_dna += gap
        large_dna += seq 
    
    print("Total seq length:\t", len(large_dna), file=sys.stderr)

    requested_overlapping_reads = int(args.num * args.overlapping_ratio)
    requested_non_overlapping_reads = args.num - requested_overlapping_reads

    overlap_distrib = {}
    generated_reads = 0
 
    # Generate overlapping reads
    for i in range(requested_non_overlapping_reads):
 
        start = random.randint(0, len(large_dna) - args.max)
        
        # Overlapping reads with min-ov overlap, fraglen is between 2*read_len-min_ov  and read_len
        max_fraglen = 2 * args.len - args.min_ov
        min_fraglen = args.len + 1
        fraglen = random.randint(min_fraglen, max_fraglen)
        
        end = start + fraglen
        fragment = large_dna[start:end]
        overlap_len =  calculate_overlap(args.len, fraglen)

        if not check_comp(fragment):
            print(f"WARNING: Skipping fragment {i} with invalid characters", file=sys.stderr)
            continue

        # increment overlap_distrib
        if overlap_len in overlap_distrib:
            overlap_distrib[overlap_len] += 1
        else:
            overlap_distrib[overlap_len] = 1
        # Generate two reads from the fragment
        read1 = fragment[:args.len]
        # Read 2 is the last args.len bases of the fragment, reverse-complemented
        read2 = revcompl(fragment[-args.len:])

        read_id = f"{i+1} overlap={overlap_len} fragment={fraglen} start={start} end={end}"

        # Write the reads to the output files
        print(f"@read_{read_id}\n{read1}\n+\n{qual}", file=fh1)
        print(f"@read_{read_id}\n{read2}\n+\n{qual}", file=fh2)
        print(f"@fragment_{read_id}\n{fragment}\n+\n{'I' * fraglen}", file=fhx)
        generated_reads += 1
        if generated_reads == requested_overlapping_reads:
            break

    # Generate non-overlapping reads
    for i in range(requested_non_overlapping_reads):
 
        start = random.randint(0, len(large_dna) - args.max)

        # Fragment length must be above 2*read_len+1
        fraglen = random.randint(2 * args.len + 1, args.max)
        end = start + fraglen
        fragment = large_dna[start:end]

        if not check_comp(fragment):
            print(f"WARNING: Skipping fragment {i} with invalid characters", file=sys.stderr)
            continue

        # Generate two reads from the fragment
        read1 = fragment[:args.len]
        # Read 2 is the last args.len bases of the fragment, reverse-complemented
        read2 = revcompl(fragment[-args.len:])
        read_id = f"{i+1} overlap=0 fragment={fraglen} start={start} end={end}"

        # Write the reads to the output files
        print(f"@read_{read_id}\n{read1}\n+\n{qual}", file=fh1)
        print(f"@read_{read_id}\n{read2}\n+\n{qual}", file=fh2)
 
    # Close
    fh1.close()
    fh2.close()
    fhx.close()
    # print overlap distribution, two columns: all integers between 0 and max overlap, and their counts
    max_overlap = max(overlap_distrib.keys())
    max_barlen  = 80
    max_count   = max(overlap_distrib.values())
    print("Overlap\tCount", file=fh_dist)
    for i in range(max_overlap+1):
        print(i, overlap_distrib.get(i, 0), sep="\t", file=fh_dist)
        bar_len = int(overlap_distrib.get(i, 0) * max_barlen / max_count)
        print(f"{i}\t{overlap_distrib.get(i, 0)}\t{'*' * bar_len}", file=sys.stderr)

    # Print % overlapping reads
    perc_overlapping_reads = sum([v for k, v in overlap_distrib.items() if k > 0]) / args.num * 100
    print(f"Percentage of overlapping reads: {perc_overlapping_reads:.2f}%", file=sys.stderr)

    fh_dist.close()