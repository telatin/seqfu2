# AGENTS.md - SeqFu Development Guide

This file is the canonical agent guide for this repository. It consolidates the
older `AGENTS.md` and `CLAUDE.md` guidance into one source of truth for coding
agents working on SeqFu.

## Project Overview

SeqFu is a Nim suite of command-line tools for robust and reproducible FASTA and
FASTQ manipulation. The main `seqfu` binary exposes subcommands for counting,
statistics, filtering, trimming, interleaving, deinterleaving, tabulation,
viewing, and related sequence workflows. Several specialized utilities are built
as standalone binaries.

Citation:

Telatin A, Fariselli P, Birolo G. *SeqFu: A Suite of Utilities for the Robust
and Reproducible Manipulation of Sequence Files*. Bioengineering 2021, 8, 59.
doi.org/10.3390/bioengineering8050059

## Core Commands

```bash
make                         # Build all binaries and copied scripts into bin/
make test                    # Build everything, then run test/mini.sh
make clean                   # Remove compiled build targets from bin/
nimble build                 # Build Nim namedBin targets through Nimble
bash test/mini.sh            # Run the bash integration suite
bash test/mini.sh grep       # Run a focused module test where supported
cd test && bats bats_0.bats  # Run BATS tests
```

When a restricted environment blocks Nim cache writes, use a writable cache, for
example `--nimcache:/private/tmp/seqfu2-nimcache`, and report cache issues
separately from source or dependency failures.

## Current Build Facts

- Nim requirement: `nim >= 2.2.0` from `seqfu.nimble`.
- Package version is defined in `seqfu.nimble` and passed at compile time as
  `-d:NimblePkgVersion=$(VERSION)`.
- Main Makefile flags:
  `--mm:orc -d:NimblePkgVersion=$(VERSION) -d:release --opt:speed --passC:"-Wno-error=incompatible-pointer-types"`.
- Threaded standalone tools add `--threads:on`; check the Makefile before adding
  or changing threaded binaries.
- C/C++ helper tools are built from `test/byte/` and linked with zlib where the
  Makefile says so.

## Source Layout

- `src/sfu.nim`: main `seqfu` entry point, subcommand dispatch table, help text,
  and `include` list for subcommand modules.
- `src/fastx_*.nim`: commands that operate on FASTA and/or FASTQ records.
- `src/fastq_*.nim`: FASTQ-specific commands.
- `src/fu_*.nim`: standalone or shared specialized utilities.
- `src/seqfu_utils.nim`: shared utilities, version handling, types, filename
  helpers, and common sequence helpers.
- `src/seqfu_records.nim`, `src/seqfu_legacy_fastx.nim`, `src/stats_utils.nim`,
  `src/merge_utils.nim`: shared parser/record/stat support.
- `src/msa.nim` and `src/lib/msa_reader.nim`: interactive MSA viewer support.
- `scripts/`: Python and shell utilities copied into `bin/`.
- `test/mini.sh` and `test/test-*.sh`: bash integration harness and modules.
- `data/`: small fixtures, including gzipped FASTA/FASTQ files.

## Parser And Dependency Notes

- Active FASTA/FASTQ parsing uses `readfx >= 0.8.0`; do not describe new work as
  using the old `readfq` parser unless you have verified a legacy path.
- `src/lib/klib.nim` may still exist for compatibility/history, but current
  command work should inspect live imports before making parser assumptions.
- Regex code uses the Nim `regex` package. In included `seqfu` modules, imports
  share scope, so prefer `import regex except re, match, replace, Regex` and
  qualified calls such as `regex.match`, `regex.replace`, and `regex.re2`.
- Important declared dependencies include `docopt`, `argparse`,
  `terminaltables`, `colorize`, `illwill`, `malebolgia`, `tableview`,
  `checksums`, `iterutils`, and `zip`.

## Coding Style

- Use 2-space indentation for Nim.
- Keep imports ordered as standard library, external packages, then local modules
  where practical.
- Use PascalCase for types, camelCase for variables/procs, and UPPER_CASE for
  constants.
- Use `include ./filename` for modules compiled into `src/sfu.nim`.
- Use `{.gcsafe.}` and `{.cast(gcsafe).}` deliberately for threaded code or
  included dispatch wrappers.
- Keep streaming behavior for FASTA/FASTQ commands unless a command explicitly
  requires whole-file state.
- Avoid retaining pointer-backed records from `readfx` pointer iterators; consume
  immediately or copy the needed fields.

## Adding Or Changing Commands

For a new `seqfu` subcommand:

1. Create an appropriately named module, usually `src/fastx_<name>.nim` or
   `src/fastq_<name>.nim`.
2. Add `include ./<module>` in `src/sfu.nim`.
3. Add the command and aliases to the `progs` dispatch table.
4. Add concise help text to the appropriate help table in `src/sfu.nim`.
5. Add focused tests in `test/mini.sh` or a sourced `test/test-<name>.sh`.

For a new standalone utility:

1. Create `src/fu_<name>.nim` or another source file matching the existing naming
   pattern.
2. Add it to `namedBin` in `seqfu.nimble`.
3. Add a Makefile target and include it in `TARGETS`.
4. Add `--threads:on` only if the tool actually needs threaded runtime support.
5. Add smoke and behavior tests.

## Testing Guidance

- Prefer the smallest meaningful test first, for example
  `bash test/mini.sh count` or `bash test/mini.sh grep`.
- Run `make test` when changes affect dispatch, shared utilities, parser
  behavior, output formats, build metadata, or multiple commands.
- Many `test/test-*.sh` files are meant to be sourced by `test/mini.sh`. If a new
  module can also run directly, initialize defaults for `BINDIR`, `FILES`, `OK`,
  `FAIL`, `PASS`, and `ERRORS`.
- Sourced test modules must update shared `PASS` and `ERRORS`; a module that
  prints successful checks but reports `0 passed, 0 failed` is not wired
  correctly.
- Use exact sequence and quality payload assertions for parser/output changes
  where counts alone would miss regressions.
- Before calling a branch ready, run relevant focused tests, `make test` when
  warranted, and `git diff --check`.

## Release And Documentation Notes

- Update version metadata in `seqfu.nimble`.
- The test harness may compare local version behavior with release state through
  the `RELEASE` environment variable; use `${RELEASE:-0}` style defaults in bash
  when needed.
- For Nim API documentation work, update source Nimdoc comments unless generated
  docs are explicitly requested.
- Keep planning Markdown and generated notes out of commits unless explicitly
  requested.

## Agent Workflow Rules

- Read the current source before editing; this repository changes quickly enough
  that older notes may be stale.
- Preserve unrelated worktree changes and untracked files.
- Do not use broad cleanup commands or `git add .`.
- Keep changes tightly scoped to the requested behavior.
- For dependency, parser, linkage, or migration work, verify the declared
  metadata and the active imports/call sites in the checkout before concluding.
