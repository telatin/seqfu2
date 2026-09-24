# SeqFu documentation site

Jekyll site published by GitHub Pages at <https://telatin.github.io/seqfu2/>.
No theme gem and no custom plugins: everything is generated with Liquid from page front matter.

```
index.html                 home page
getting-started/*.md       quick start, installation, overview, conventions
tools/<command>.md         one page per `seqfu <command>`   (kind: core, by folder)
tools/index.html           the filterable Tools catalogue
utilities/<program>.md     one page per `fu-*` program       (kind: utility, by folder)
recipes/<name>.md          tutorials
about/                     about, changelog, contributing
_data/                     categories, input types, navigation, install commands
_layouts/ _includes/       templates
assets/css/main.scss       styles (design tokens at the top)
assets/js/site.js          search, filters, tabs, table of contents, copy buttons
assets/search.json         search index (Liquid)
```

The front-matter schema for tools and recipes is documented in
[about/contributing.md](about/contributing.md).

Build locally:

```bash
bundle install
bundle exec jekyll serve      # http://localhost:4000/seqfu2/
```
