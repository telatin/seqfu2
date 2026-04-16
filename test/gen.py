#!/usr/bin/env python
# 
import argparse
import os
import sys

def parse_length(length_str):
    suffixes = {'K': 1000, 'M': 1000000, 'G': 1000000000}
    if length_str[-1] in suffixes:
        return int(length_str[:-1]) * suffixes[length_str[-1]]
    return int(length_str)

def generate_sequences(instructions):
    sequences = []
    for instruction in instructions:
        n_seqs, length = instruction.split('*')
        length = parse_length(length)
        sequences.extend([length] * int(n_seqs))
    return sequences

def calculate_stats(sequences):
    total_length = sum(sequences)
    avg_length = total_length / len(sequences)
    
    # Calculate N50
    sorted_lengths = sorted(sequences, reverse=True)
    cumulative_length = 0
    for length in sorted_lengths:
        cumulative_length += length
        if cumulative_length >= total_length / 2:
            n50 = length
            break
    
    return avg_length, n50, total_length

def write_fasta(file, sequences, name_prefix):
    for i, length in enumerate(sequences, 1):
        file.write(f">{name_prefix}{i}\n")
        file.write("A" * length + "\n")

def write_fastq(file, sequences, name_prefix):
    for i, length in enumerate(sequences, 1):
        file.write(f"@{name_prefix}{i}\n")
        file.write("A" * length + "\n")
        file.write("+\n")
        file.write("I" * length + "\n")

def main():
    parser = argparse.ArgumentParser(description="Generate FASTA or FASTQ sequences.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--fasta", action="store_true", help="Generate FASTA format")
    group.add_argument("--fastq", action="store_true", help="Generate FASTQ format")
    parser.add_argument("-o", "--outdir", required=True, help="Output directory")
    parser.add_argument("-n", "--name", help="Output file name prefix")
    parser.add_argument("instructions", nargs="+", help="Sequence generation instructions")

    args = parser.parse_args()

    sequences = generate_sequences(args.instructions)
    avg_length, n50, total_length = calculate_stats(sequences)

    os.makedirs(args.outdir, exist_ok=True)

    if args.name:
        filename = f"{args.name}.{'fasta' if args.fasta else 'fastq'}"
    else:
        filename = f"{total_length}_{len(sequences)}_{n50}.{'fasta' if args.fasta else 'fastq'}"

    output_path = os.path.join(args.outdir, filename)

    with open(output_path, 'w') as f:
        if args.fasta:
            write_fasta(f, sequences, "seq_")
        else:
            write_fastq(f, sequences, "seq_")

    print(f"Generated {len(sequences)} sequences")
    print(f"Average length: {avg_length:.2f}")
    print(f"N50: {n50}")
    print(f"Total length: {total_length}")
    print(f"Output file: {output_path}")

if __name__ == "__main__":
    main()