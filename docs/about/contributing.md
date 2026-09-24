---
title: Contributing to the docs
summary: How the site is organised, and the front matter every tool and recipe page uses.
---

The site is a plain [Jekyll](https://jekyllrb.com) site built by GitHub Pages. There is no
theme gem and no custom plugin: layouts, listings and the search index are all generated
with Liquid from the **front matter** of each page, so adding a page is usually all it takes.

## Where things live

| Path | What goes there |
|---|---|
| `tools/<command>.md` | One page per `seqfu <command>` (core tools) |
| `utilities/<program>.md` | One page per standalone program (`fu-*`, helper scripts, wrappers) |
| `recipes/<name>.md` | Tutorials combining several commands |
| `getting-started/`, `about/` | Long-form guides |
| `_data/categories.yml` | Task families (the groups in the Tools catalogue) |
| `_data/inputs.yml` | Input types offered as filters |
| `_data/navigation.yml` | Top navigation and section side menus |
| `_data/install.yml` | Install commands shown on the home page |
| `_layouts/`, `_includes/` | HTML templates |
| `assets/css/main.scss`, `assets/js/site.js` | Styles (tokens at the top) and small enhancements |

The folder decides the kind of page: files in `tools/` get `kind: core`, files in
`utilities/` get `kind: utility`, both with the `tool` layout (see `defaults` in `_config.yml`).

## Tool and utility pages

```yaml
---
title: seqfu stats                 # the command as typed; also used to cross-link pages
summary: "One sentence, shown on cards, in search and under the title."
category: qc                       # an id from _data/categories.yml
input: [FASTA, FASTQ]              # FASTA, FASTQ, TSV-CSV, Directory, Alignment, ...
output: "TSV table"                # free text
aliases: [st, stat]                # optional: short subcommand names
wrapper: false                     # true for compatibility wrappers...
wraps: seqfu orf                   # ...and the title of the command they wrap
deprecated: false                  # shows a warning, hidden from the catalogue by default
experimental: false                # interface may still change
paired: false                      # supports paired-end input
interactive: false                 # full-screen terminal interface
language: python                   # optional, default nim
since: "1.11"                      # optional: first version with this command
related: ["seqfu count", "seqfu qual"]   # optional: titles of related pages
keywords: "n50 assembly metrics"   # optional: extra words for search and filtering
---
```

The page body is plain Markdown: start with a short description, then the usage block,
then sections (`##`) for options, examples and notes. The title, summary, badges, the facts
strip, the wrapper and deprecation notices, the related links and the table of contents are
added by the layout, so do not repeat them in the body.

A `` ```note `` fenced block renders as a highlighted callout.

## Recipes

```yaml
---
title: Merge lanes per sample
summary: "One sentence describing the goal."
order: 3                           # position in the recipes list
level: beginner                    # beginner, intermediate or advanced
input: [Directory, FASTQ]
tools: [seqfu lanes, seqfu count]  # titles of the tool pages used
---
```

## Building locally

```bash
cd docs
bundle install
bundle exec jekyll serve
```

Then open <http://localhost:4000/seqfu2/>.
