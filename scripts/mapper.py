#!/usr/bin/env python3
"""
Map sequencing files to sample metadata based on multiple filename patterns.

This script analyzes files in a directory and maps them to samples defined in a metadata 
TSV file using a hierarchical pattern matching strategy:

Matching Strategy:
1. Direct match with Raw_forward/Raw_reverse paths
2. Pattern match using IRIDA_ID + S-number (safe_id)
3. Reports conflicting or missing file assignments

Usage:
    map_files.py [-h] --metadata METADATA --directory DIRECTORY 
                 [--extension EXTENSION] [--fortag FORTAG] [--revtag REVTAG]

Arguments:
    --metadata: Path to metadata TSV file containing sample information
    --directory: Directory containing sequencing files
    --extension: File extension to filter (default: .fastq.gz)
    --fortag: Forward read identifier (default: _R1)
    --revtag: Reverse read identifier (default: _R2)
"""

import argparse
import os
import re
import sys
from collections import defaultdict
from typing import Dict, List, Set, Tuple

class FileMapper:
    def __init__(self, metadata_file: str, directory: str, 
                 extension: str = '.fastq.gz',
                 fortag: str = '_R1', 
                 revtag: str = '_R2'):
        self.metadata_file = metadata_file
        self.directory = directory
        self.extension = extension
        self.fortag = fortag
        self.revtag = revtag
        
        # Storage for sample metadata and file mappings
        self.samples = []  # List of sample dictionaries
        self.file_mappings = defaultdict(lambda: {'R1': set(), 'R2': set()})
        
    def parse_metadata(self) -> None:
        """Parse the metadata TSV file into a list of sample dictionaries."""
        with open(self.metadata_file, 'r') as f:
            header = f.readline().strip().split('\t')
            for line in f:
                fields = line.strip().split('\t')
                sample = dict(zip(header, fields))
                self.samples.append(sample)

    def get_files_in_directory(self) -> List[str]:
        """Get list of files with specified extension in directory."""
        return [f for f in os.listdir(self.directory) 
                if f.endswith(self.extension)]

    def extract_s_number(self, filename: str) -> str:
        """Extract S-number from filename using regex."""
        match = re.search(r'S\d+', filename)
        return match.group() if match else None

    def determine_read_type(self, filename: str) -> str:
        """Determine if file is R1 or R2 based on tags."""
        if self.fortag in filename:
            return 'R1'
        elif self.revtag in filename:
            return 'R2'
        return None

    def map_files_to_samples(self) -> None:
        """
        Map files to samples using hierarchical matching strategy.
        """
        files = self.get_files_in_directory()
        
        for filename in files:
            matched = False
            read_type = self.determine_read_type(filename)
            if not read_type:
                continue

            # Strategy 1: Direct match with Raw_forward/Raw_reverse
            for sample in self.samples:
                raw_file = sample.get(f'Raw_{"forward" if read_type == "R1" else "reverse"}', '')
                if os.path.basename(raw_file) == filename:
                    self.file_mappings[sample['Sample_Name']][read_type].add(filename)
                    matched = True
                    break

            # Strategy 2: Match using IRIDA_ID and S-number independently
            if not matched:
                s_number = self.extract_s_number(filename)
                if s_number:
                    # Extract IRIDA_ID from start of filename if present
                    irida_match = re.match(r'^(\d+)_', filename)
                    if irida_match:
                        file_irida = irida_match.group(1)
                        
                        for sample in self.samples:
                            # Check if both IRIDA_ID and S-number match
                            if (sample['IRIDA_ID'] == file_irida and 
                                s_number == self.extract_s_number(sample.get('Raw_forward', ''))):
                                self.file_mappings[sample['Sample_Name']][read_type].add(filename)
                                matched = True
                                break

    def validate_mappings(self) -> Tuple[Dict, Dict]:
        """
        Validate file mappings and return problematic cases.
        
        Returns:
            Tuple containing:
            - Dict of samples with multiple files for same read
            - Dict of samples with missing files
        """
        conflicts = {}
        missing = {}
        
        for sample in self.samples:
            sample_name = sample['Sample_Name']
            mapping = self.file_mappings[sample_name]
            
            # Check for multiple files
            if len(mapping['R1']) > 1:
                conflicts.setdefault(sample_name, {})['R1'] = mapping['R1']
            if len(mapping['R2']) > 1:
                conflicts.setdefault(sample_name, {})['R2'] = mapping['R2']
                
            # Check for missing files
            if not mapping['R1']:
                missing.setdefault(sample_name, set()).add('R1')
            if not mapping['R2']:
                missing.setdefault(sample_name, set()).add('R2')
                
        return conflicts, missing

    def run(self) -> None:
        """Execute the file mapping workflow and output results."""
        # Parse metadata and map files
        self.parse_metadata()
        self.map_files_to_samples()
        
        # Validate and report results
        conflicts, missing = self.validate_mappings()
        
        # Output results
 
        for sample_name, mapping in self.file_mappings.items():
            if sample_name not in conflicts and sample_name not in missing:
                print(f"{sample_name}\t{next(iter(mapping['R1']))}\t{next(iter(mapping['R2']))}")
 
        
        if conflicts:
            print("\nWARNING: Samples with multiple files:")
            for sample_name, reads in conflicts.items():
                print(f"\nSample: {sample_name}", file=sys.stderr)
                for read_type, files in reads.items():
                    print(f"{read_type}: {', '.join(files)}", file=sys.stderr)
        
        if missing:
            print("\nWARNING: Samples with missing files:")
            for sample_name, missing_reads in missing.items():
                print(f"{sample_name}\t\t")
 ")

def main():
    parser = argparse.ArgumentParser(description='Map sequencing files to sample metadata.')
    parser.add_argument('--metadata', required=True, help='Path to metadata TSV file')
    parser.add_argument('--directory', required=True, help='Directory containing sequence files')
    parser.add_argument('--extension', default='.fastq.gz', help='File extension to filter')
    parser.add_argument('--fortag', default='_R1', help='Forward read identifier')
    parser.add_argument('--revtag', default='_R2', help='Reverse read identifier')
    
    args = parser.parse_args()
    
    # Validate inputs
    if not os.path.isfile(args.metadata):
        sys.exit(f"Error: Metadata file '{args.metadata}' not found")
    if not os.path.isdir(args.directory):
        sys.exit(f"Error: Directory '{args.directory}' not found")
        
    # Execute file mapping
    mapper = FileMapper(
        args.metadata,
        args.directory,
        args.extension,
        args.fortag,
        args.revtag
    )
    mapper.run()

if __name__ == "__main__":
    main()