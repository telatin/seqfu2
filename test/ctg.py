#!/usr/bin/env python3

import argparse
import os
import random
import statistics
import sys
from collections import Counter
from math import erf, sqrt

def parse_arguments():
    parser = argparse.ArgumentParser(description="Estimate standard statistics from FASTA contig files")
    parser.add_argument("contig_files", nargs="+", help="Input contig files")
    parser.add_argument("-m", "--min_length", type=int, default=1, help="Minimum contig length")
    parser.add_argument("-g", "--genome_size", type=int, default=0, help="Expected genome size")
    parser.add_argument("-r", "--residue_content", action="store_true", help="Residue content statistics for each contig")
    parser.add_argument("-t", "--tab_output", action="store_true", help="Tab-delimited output")
    return parser.parse_args()

def read_fasta(file_path, min_length):
    sequences = []
    current_seq = []
    current_header = ""
    
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('>'):
                if current_seq:
                    seq = ''.join(current_seq).upper()
                    if len(seq) >= min_length:
                        sequences.append((current_header, seq))
                current_header = line[1:]
                current_seq = []
            else:
                current_seq.append(line)
        
        if current_seq:
            seq = ''.join(current_seq).upper()
            if len(seq) >= min_length:
                sequences.append((current_header, seq))
    
    return sequences

def calculate_residue_stats(sequence):
    counts = Counter(sequence)
    total = sum(counts.values())
    stats = {
        'A': counts['A'],
        'C': counts['C'],
        'G': counts['G'],
        'T': counts['T'],
        'N': counts['N'],
        'total': total,
        '%A': counts['A'] / total * 100,
        '%C': counts['C'] / total * 100,
        '%G': counts['G'] / total * 100,
        '%T': counts['T'] / total * 100,
        '%N': counts['N'] / total * 100,
        '%AT': (counts['A'] + counts['T']) / (total - counts['N']) * 100,
        '%GC': (counts['C'] + counts['G']) / (total - counts['N']) * 100
    }
    return stats

def calculate_length_stats(lengths, genome_size):
    sorted_lengths = sorted(lengths, reverse=True)
    total_length = sum(sorted_lengths)
    cumulative_length = 0
    n50, n75, n90 = 0, 0, 0
    l50, l75, l90 = 0, 0, 0
    
    for i, length in enumerate(sorted_lengths, 1):
        cumulative_length += length
        if not n50 and cumulative_length >= total_length * 0.5:
            n50, l50 = length, i
        if not n75 and cumulative_length >= total_length * 0.75:
            n75, l75 = length, i
        if not n90 and cumulative_length >= total_length * 0.9:
            n90, l90 = length, i
    
    stats = {
        'min': min(lengths),
        'q25': sorted_lengths[len(sorted_lengths) // 4],
        'median': statistics.median(lengths),
        'q75': sorted_lengths[3 * len(sorted_lengths) // 4],
        'max': max(lengths),
        'avg': sum(lengths) / len(lengths),
        'auN': sum(l * l for l in lengths) / (genome_size or total_length),
        'N50': n50,
        'N75': n75,
        'N90': n90,
        'L50': l50,
        'L75': l75,
        'L90': l90
    }
    return stats

def mann_whitney_u_test(sample1, sample2):
    combined = [(val, 0) for val in sample1] + [(val, 1) for val in sample2]
    combined.sort()
    ranks = {}
    for i, (val, _) in enumerate(combined):
        if val not in ranks:
            ranks[val] = i + 1
    
    u1 = sum(ranks[val] for val in sample1)
    n1, n2 = len(sample1), len(sample2)
    u = u1 - n1 * (n1 + 1) / 2
    
    mean = n1 * n2 / 2
    std_dev = sqrt(n1 * n2 * (n1 + n2 + 1) / 12)
    z = abs(u - mean) / std_dev
    p_value = 2 * (1 - 0.5 * (1 + erf(z / sqrt(2))))
    
    return p_value

def process_file(file_path, args):
    sequences = read_fasta(file_path, args.min_length)
    
    if args.residue_content:
        for header, seq in sequences:
            stats = calculate_residue_stats(seq)
            gc_content = [sum(1 for base in seq[i:i+200] if base in 'GC') / 200 for i in range(0, len(seq) - 199, 200)]
            all_gc_content = [random.random() for _ in range(5000)]  # Placeholder for all contigs GC content
            p_value = mann_whitney_u_test(gc_content, all_gc_content)
            
            if args.tab_output:
                print(f"{os.path.basename(file_path)}\t{header}\t{stats['total']}\t{stats['A']}\t{stats['C']}\t{stats['G']}\t{stats['T']}\t{stats['N']}\t{stats['%A']:.2f}%\t{stats['%C']:.2f}%\t{stats['%G']:.2f}%\t{stats['%T']:.2f}%\t{stats['%N']:.2f}%\t{stats['%AT']:.2f}%\t{stats['%GC']:.2f}%\t{p_value:.4f}")
            else:
                print(f"\nFile: {os.path.basename(file_path)}")
                print(f"\nSequence: {header}")
                print("\nResidue counts:")
                print(f"  Number of A's: {stats['A']}  {stats['%A']:.2f}%")
                print(f"  Number of C's: {stats['C']}  {stats['%C']:.2f}%")
                print(f"  Number of G's: {stats['G']}  {stats['%G']:.2f}%")
                print(f"  Number of T's: {stats['T']}  {stats['%T']:.2f}%")
                print(f"  Number of N's: {stats['N']}  {stats['%N']:.2f}%")
                print(f"  Total: {stats['total']}")
                print(f"\n  %AT: {stats['%AT']:.2f}%")
                print(f"  %GC: {stats['%GC']:.2f}%")
                print(f"\nComposition test p-value: {p_value:.4f}")
    else:
        all_stats = calculate_residue_stats(''.join(seq for _, seq in sequences))
        length_stats = calculate_length_stats([len(seq) for _, seq in sequences], args.genome_size)
        
        if args.tab_output:
            print(f"{os.path.basename(file_path)}\t{len(sequences)}\t{all_stats['total']}\t{all_stats['A']}\t{all_stats['C']}\t{all_stats['G']}\t{all_stats['T']}\t{all_stats['N']}\t{all_stats['%A']:.2f}%\t{all_stats['%C']:.2f}%\t{all_stats['%G']:.2f}%\t{all_stats['%T']:.2f}%\t{all_stats['%N']:.2f}%\t{all_stats['%AT']:.2f}%\t{all_stats['%GC']:.2f}%\t{length_stats['min']}\t{length_stats['q25']}\t{length_stats['median']}\t{length_stats['q75']}\t{length_stats['max']}\t{length_stats['avg']:.2f}\t{length_stats['auN']:.2f}\t{length_stats['N50']}\t{length_stats['N75']}\t{length_stats['N90']}\t{length_stats['L50']}\t{length_stats['L75']}\t{length_stats['L90']}")
        else:
            print(f"\nFile: {os.path.basename(file_path)}")
            print(f"\nNumber of sequences: {len(sequences)}")
            print("\nResidue counts:")
            #print(f"  Number of A's: {all_stats['A']}  {all_stats['%A']:.2f}%")
            #print(f"  Number of C's: {all_stats['C']}  {all_stats['%C']:.2f}%")
            #print(f"  Number of G's: {all_stats['G']}  {all_stats['%G']:.2f}%")
            #print(f"  Number of T's: {all_stats['T']}  {all_stats['%T']:.2f}%")
            #print(f"  Number of N's: {all_stats['N']}  {all_stats['%N']:.2f}%")
            print(f"  Total: {all_stats['total']}")
            #print(f"\n  %AT: {all_stats['%AT']:.2f}%")
            print(f"  %GC: {all_stats['%GC']:.2f}%")
            print("\nSequence lengths:")
            print(f"  Minimum: {length_stats['min']}")
            print(f"  Quartile 25%: {length_stats['q25']}")
            print(f"  Median: {length_stats['median']}")
            print(f"  Quartile 75%: {length_stats['q75']}")
            print(f"  Maximum: {length_stats['max']}")
            print(f"  Average: {length_stats['avg']:.2f}")
            print("\nContiguity statistics:")
            print(f"  auN: {length_stats['auN']:.2f}")
            print(f"  N50: {length_stats['N50']}")
            print(f"  N75: {length_stats['N75']}")
            print(f"  N90: {length_stats['N90']}")
            print(f"  L50: {length_stats['L50']}")
            print(f"  L75: {length_stats['L75']}")
            print(f"  L90: {length_stats['L90']}")
            if args.genome_size:
                print(f"  Expected genome size: {args.genome_size}")

def main():
    args = parse_arguments()
    
    if args.tab_output:
        if args.residue_content:
            print("#File\tSeq\tNres\tA\tC\tG\tT\tN\t%A\t%C\t%G\t%T\t%N\t%AT\t%GC\tPval")
        else:
            header = "#File\tNseq\tNres\tA\tC\tG\tT\tN\t%A\t%C\t%G\t%T\t%N\t%AT\t%GC\tMin\tQ25\tMed\tQ75\tMax\tAvg\tauN\tN50\tN75\tN90\tL50\tL75\tL90"
            if args.genome_size:
                header += "\tExpSize"
            print(header)
    
    for file_path in args.contig_files:
        if os.path.isfile(file_path) and os.access(file_path, os.R_OK):
            process_file(file_path, args)
        else:
            print(f"Error: Cannot read file {file_path}", file=sys.stderr)

if __name__ == "__main__":
    main()