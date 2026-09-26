#!/usr/bin/env python3
"""
extract_docopt.py - Parse Nim source files, extract docopt option strings,
and emit a JSON mapping of flags to their tool and description.

Usage:
    python extract_docopt.py -o output.json [FILES...]

Each entry in the JSON array has:
  - tool:        name of the .nim file (stem)
  - short:       short flag, e.g. "-a"  (null if none)
  - long:        long flag, e.g. "--abs-path"  (null if none)
  - argument:    argument name shown in option string (null if boolean flag)
  - description: description text
  - default:     default value extracted from "[default: ...]" (null if none)
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Docopt string extraction
# ---------------------------------------------------------------------------

# Matches the raw docopt string literal passed to docopt("""...""")
# Nim allows both """ and potentially other patterns; we capture everything
# between the opening triple-quote and the closing triple-quote.
_DOCOPT_RE = re.compile(
    r'\bdocopt\s*\(\s*(?:doc\s*,|""")',
    re.DOTALL,
)

def extract_docopt_strings(source: str) -> list[str]:
    """Return all docopt string bodies found in a Nim source file."""
    results = []
    pos = 0
    while True:
        m = _DOCOPT_RE.search(source, pos)
        if not m:
            break
        # Check whether the match already consumed the opening """ or just
        # found `doc,` (a variable reference).
        if m.group(0).endswith('"""'):
            # The triple-quote is the opening delimiter — find the closing one.
            start = m.end()
            end = source.find('"""', start)
            if end == -1:
                break
            results.append(source[start:end])
            pos = end + 3
        else:
            # Variable form: docopt(doc, …) — look backwards for `let doc = """`
            # or `var doc = """`
            head = source[:m.start()]
            var_m = re.search(
                r'\b(?:let|var)\s+doc\s*=\s*"""(.*?)"""',
                head,
                re.DOTALL,
            )
            if var_m:
                results.append(var_m.group(1))
            pos = m.end()
    return results


# ---------------------------------------------------------------------------
# Flag-line parsing
# ---------------------------------------------------------------------------

# Matches option lines inside a docopt Options section, e.g.:
#   -a, --abs-path         Print absolute paths
#   -f, --for-tag R1       Forward string [default: auto]
#   --verbose              Verbose output
#   -h --help              Show this help
#   -5 --cut-front         Enable 5' sliding window trimming
#
# Captures:
#   short  : optional short flag (one or two chars after a single dash)
#   long   : optional long flag (--word-chars)
#   arg    : optional argument token that follows the long flag
#   desc   : description text

_FLAG_RE = re.compile(
    r"""
    ^[ \t]+                        # leading indent (required — avoids Usage: lines)
    (?:
        (?P<short>-\S)             # short flag: - followed by one non-space char
        (?:[ \t]*,?[ \t]*|\s+)     # separator: ", " or space(s)
    )?
    (?P<long>--[\w][\w-]*)         # long flag: --word
    (?:[ \t]+(?P<arg>[A-Z_/]+))?   # optional UPPERCASE argument token
    [ \t]{2,}                      # at least 2 spaces before description
    (?P<desc>.+)                   # description text
    """,
    re.VERBOSE,
)

# Also catch short-only flags (no long), e.g.:  -v   Verbose output
_SHORT_ONLY_RE = re.compile(
    r"""
    ^[ \t]+                        # leading indent
    (?P<short>-\S)                 # short flag
    (?:[ \t]+(?P<arg>[A-Z_/]+))?   # optional UPPERCASE argument token
    [ \t]{2,}                      # at least 2 spaces before description
    (?P<desc>.+)                   # description text
    """,
    re.VERBOSE,
)

_DEFAULT_RE = re.compile(r'\[default:\s*([^\]]+)\]', re.IGNORECASE)


def parse_flags(docopt_body: str) -> list[dict]:
    """Extract flag records from a docopt string body."""
    flags = []
    # Track multiline descriptions: continuation lines are indented more
    # but we keep it simple — just grab the first description line.
    for line in docopt_body.splitlines():
        m = _FLAG_RE.match(line)
        if m:
            desc_raw = m.group('desc').strip()
            default_m = _DEFAULT_RE.search(desc_raw)
            # Strip the [default: ...] part from description
            desc_clean = _DEFAULT_RE.sub('', desc_raw).strip().rstrip('.')
            record = {
                'short': m.group('short'),      # may be None
                'long': m.group('long'),
                'argument': m.group('arg'),     # may be None
                'description': desc_clean,
                'default': default_m.group(1).strip() if default_m else None,
            }
            flags.append(record)
            continue

        # Try short-only (no long flag on this line)
        sm = _SHORT_ONLY_RE.match(line)
        if sm:
            short_flag = sm.group('short')
            desc_raw = sm.group('desc').strip()
            default_m = _DEFAULT_RE.search(desc_raw)
            desc_clean = _DEFAULT_RE.sub('', desc_raw).strip().rstrip('.')
            record = {
                'short': short_flag,
                'long': None,
                'argument': sm.group('arg'),
                'description': desc_clean,
                'default': default_m.group(1).strip() if default_m else None,
            }
            flags.append(record)

    return flags


# ---------------------------------------------------------------------------
# Deduplication helper
# ---------------------------------------------------------------------------

def dedup_flags(flags: list[dict]) -> list[dict]:
    """Remove exact duplicates (same short+long+description) keeping order."""
    seen = set()
    out = []
    for f in flags:
        key = (f['short'], f['long'], f['description'])
        if key not in seen:
            seen.add(key)
            out.append(f)
    return out


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def process_file(path: Path) -> list[dict]:
    source = path.read_text(encoding='utf-8', errors='replace')
    docopt_bodies = extract_docopt_strings(source)
    tool_name = path.stem
    all_flags = []
    for body in docopt_bodies:
        for flag in parse_flags(body):
            flag['tool'] = tool_name
            all_flags.append(flag)
    return dedup_flags(all_flags)


def main():
    parser = argparse.ArgumentParser(
        description='Extract docopt flags from Nim source files into JSON.',
    )
    parser.add_argument(
        '-o', '--output',
        metavar='JSON',
        required=True,
        help='Output JSON file path',
    )
    parser.add_argument(
        'files',
        nargs='*',
        metavar='FILE',
        help='Nim source files to parse (default: all *.nim in current dir)',
    )
    args = parser.parse_args()

    if args.files:
        paths = [Path(f) for f in args.files]
    else:
        paths = sorted(Path('.').glob('**/*.nim'))

    if not paths:
        print('No .nim files found.', file=sys.stderr)
        sys.exit(1)

    results = []
    for p in paths:
        if not p.exists():
            print(f'WARNING: {p} not found, skipping.', file=sys.stderr)
            continue
        try:
            flags = process_file(p)
            results.extend(flags)
        except Exception as exc:
            print(f'WARNING: failed to process {p}: {exc}', file=sys.stderr)

    # Final field order: tool first so the JSON is easy to scan
    ordered = []
    for f in results:
        ordered.append({
            'tool': f['tool'],
            'short': f.get('short'),
            'long': f.get('long'),
            'argument': f.get('argument'),
            'description': f.get('description'),
            'default': f.get('default'),
        })

    out_path = Path(args.output)
    out_path.write_text(
        json.dumps(ordered, indent=2, ensure_ascii=False),
        encoding='utf-8',
    )
    print(f'Wrote {len(ordered)} flag entries to {out_path}', file=sys.stderr)


if __name__ == '__main__':
    main()
