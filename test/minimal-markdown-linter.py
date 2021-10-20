#!/usr/bin/env python
"""
Read a Markdown file and save it back out, but with some
minimal changes to make it pass the Markdown linter.
"""

import sys
import os

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def remove_trailing_whitespace(lines):
    """
    Remove trailing space from a line.
    """
    
    lines = [line.rstrip() for line in lines]
    return lines
    
def fenced_code_blocks(lines):
    """
    Fenced code blocks should be surrounded by blank lines
    """
    opened = False
    for i in range(len(lines)):
        if lines[i].startswith('```'):
            if i == 0 or lines[i-1] != '':
                if not opened:
                    lines.insert(i, '')
                    opened = True
                    continue
            elif i == len(lines)-1 or lines[i+1] != '':
                if opened:
                    lines.insert(i+1, '')
                    opened = False
                    continue


    
    return lines

def headerlines_withspace(lines):
    """
    Markdown headers have a variable number of '#'
    and after a space must be present
    """
    
    for index in range(len(lines)):
        line = lines[index]
        if line.startswith('#'):
            for pos, char in enumerate(line):
                if char != '#' and line[pos+1] != ' ':
                    lines[index] = line[:pos] + ' ' + line[pos:]
                    break
    return lines

def headerlines_surrounded(lines):
    """
    Headers should be surrounded by blank lines
    """
    
    for i in range(len(lines)):
        if lines[i].startswith('##'):
            if i == 0 or lines[i-1] != '':
                lines.insert(i, '')
            if i == len(lines)-1 or lines[i+1] != '':
                lines.insert(i+1, '')
    
    return lines

def long_lines(lines):
    """
    Split long lines to be no longer than 60 characters
    """
    
    for L in range(len(lines)):
        if len(lines[L]) > 60:
            for i, char in enumerate(lines[L]):
                if char == ' ' or char == '\t':
                    lastwhite = i
                if i > 60:
                    # replace character lastwhite with a newline
                    lines[L] = lines[L][:lastwhite] 
                    lines.insert(L+1, lines[L][lastwhite+1:])
                    break
    return lines
    

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('infile', nargs='+', type=argparse.FileType('r'))
    parser.add_argument('-d', '--dry', action='store_true', default=False, help='dry run')
    parser.add_argument('-v', '--verbose', action='store_true', default=False, help='verbose')
    args = parser.parse_args()

    for file in args.infile:
        eprint('Processing {}'.format(file.name))
        lines = file.readlines()
        file.close()
        
        lines = remove_trailing_whitespace(lines)
        lines = fenced_code_blocks(lines)
        lines = headerlines_withspace(lines)
        lines = headerlines_surrounded(lines)
        #lines = long_lines(lines)

        if args.dry:
            eprint('Dry run: not writing file:\n-------------------------')
            print('\n'.join(lines))
        else:
            # Make backup
            eprint('Writing {}'.format(file.name))
            os.rename(file.name, file.name + '.bak')
            with open(file.name, 'w') as f:
                f.writelines('\n'.join(lines))
