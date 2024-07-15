#!/usr/bin/env python
"""
A Python 3.6+ compatible script to generate FASTA or FASTQ files, randomly or using a template.
"""

import argparse
import random
import string
import sys

def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument('output', help='Output file')
    args.add_argument('count', type=int, help='Number of sequences to generate')
    args.add_argument('--template', help='Template file')
    

if __name__ == '__main__':
    exit(main())