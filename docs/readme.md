<a href="https://telatin.github.io/seqfu2" description="SeqFu documentation">
<img align="right" width="128" height="128" src="img/seqfu-512.png"></a>

# SeqFu
![Last Commit](https://img.shields.io/github/last-commit/telatin/seqfu2)
[![Build Status](https://travis-ci.com/telatin/seqfu2.svg?branch=main)](https://travis-ci.com/telatin/seqfu2)
[![Code size](https://img.shields.io/github/languages/code-size/telatin/seqfu2)](README.md)
[![Latest release](https://img.shields.io/github/v/release/telatin/seqfu2)](https://github.com/telatin/seqfu2/releases)

:package: See the **[repository](https://github.com/telatin/seqfu2)**

A general-purpose program to manipulate and parse information from FASTA/FASTQ files,
supporting gzipped input files.
Includes functions to _interleave_ and _de-interleave_ FASTQ files,
to _rename_ sequences and to _count_ and print _statistics_ on sequence lengths.
SeqFu is available for Linux and MacOS. It is possible to compile the program for Windows, but the procedure
is unsupported.

A Perl library (**FASTX::Reader**) using the same parser enging (klib) is also available:
* From [MetaCPAN](https://metacpan.org/release/FASTX-Reader), installable with `cpanm FASTX::Reader`
* From [Bioconda](https://bioconda.github.io/recipes/perl-fastx-reader/README.html?highlight=fastx#package-package%20&#x27;perl-fastx-reader&#x27;) as `perl-fastx-reader`

## Contents

{% include list.liquid all=true %}
