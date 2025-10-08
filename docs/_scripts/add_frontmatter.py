#!/usr/bin/env python3
"""
Add front matter to markdown files for Jekyll navigation.
This script adds proper front matter to child pages in the tools, utilities, and scripts directories.
"""

import os
import re
from pathlib import Path

# Configuration
BASE_DIR = Path(__file__).parent.parent
SECTIONS = {
    'tools': 'Core Tools',
    'utilities': 'Utilities',
    'scripts': 'Helper Utilities',
    'releases': 'Releases'
}

def has_frontmatter(content):
    """Check if file already has front matter."""
    return content.strip().startswith('---')

def extract_title_from_content(content):
    """Extract title from the first # heading in the content."""
    lines = content.split('\n')
    for line in lines:
        if line.strip().startswith('# '):
            return line.strip()[2:].strip()
    return None

def create_frontmatter(title, parent):
    """Create front matter block."""
    return f"""---
layout: default
title: {title}
parent: {parent}
---

"""

def process_file(filepath, parent_name):
    """Add front matter to a single file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Skip if already has front matter
    if has_frontmatter(content):
        print(f"Skipping {filepath} (already has front matter)")
        return False

    # Extract title from content
    title = extract_title_from_content(content)
    if not title:
        print(f"Warning: Could not find title in {filepath}")
        # Use filename as fallback
        title = filepath.stem.replace('-', ' ').replace('_', ' ').title()

    # Create new content with front matter
    frontmatter = create_frontmatter(title, parent_name)
    new_content = frontmatter + content

    # Write back to file
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"Added front matter to {filepath}")
    return True

def main():
    """Process all markdown files in the specified sections."""
    processed = 0

    for section_dir, parent_name in SECTIONS.items():
        section_path = BASE_DIR / section_dir

        if not section_path.exists():
            print(f"Warning: Directory {section_path} does not exist")
            continue

        print(f"\nProcessing {section_dir}/ (parent: {parent_name})")

        # Process all .md files except README.md
        for md_file in section_path.glob('*.md'):
            if md_file.name.upper() == 'README.MD':
                continue

            if process_file(md_file, parent_name):
                processed += 1

    print(f"\n\nTotal files processed: {processed}")

if __name__ == '__main__':
    main()
