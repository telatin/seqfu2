---
title: fu-msa
summary: "Legacy launcher for seqfu msa (prints a migration notice first)."
category: inspect
input: [Alignment, FASTA]
output: "Terminal (TUI)"
wrapper: true
wraps: seqfu msa
deprecated: true
experimental: false
paired: false
interactive: false
---

`fu-msa` has moved to [`seqfu msa`]({{ '/tools/msa.html' | relative_url }}).

The `fu-msa` binary is still shipped for compatibility with existing workflows. It prints a migration notice, waits three seconds, and then runs `seqfu msa` with the same arguments.

```bash
fu-msa {input_file} --setting-string Seq:0:6:20
```

New commands and documentation should use:

```bash
seqfu msa {input_file} --setting-string Seq:0:6:20
```
