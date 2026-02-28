---
layout: default
title: Utilities
nav_order: 5
has_children: true
---

# Utilities

All these programs are automatically installed with SeqFu and are accessible as
independent binaries (usually with the `fu-` prefix).

Some utilities are also available as first-class `seqfu` subcommands:

* `seqfu orf` (legacy wrapper: `fu-orf`)
* `seqfu tabcheck` (legacy wrapper: `fu-tabcheck`)

:warning: The core tools have a strict API validation to ensure forward-compatibility of the commands,
that is not guaranteed in the external utilities.

### SeqFu utilities

### Other utilities

Some tools required by [Dadaist2](https://github.com/quadram-institute-bioscience/dadaist2) are
written using the SeqFu templates and routines, and being SeqFu a dependency of Dadaist2 they
are shipped with SeqFu, and they have the `dadaist2-` prefix.
