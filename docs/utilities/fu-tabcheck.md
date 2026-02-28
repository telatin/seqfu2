---
layout: default
title: fu-tabcheck
parent: Utilities
---

# fu-tabcheck

`fu-tabcheck` is a compatibility wrapper for `seqfu tabcheck`.

Preferred command:

```bash
seqfu tabcheck [options] <FILE>...
```

Legacy equivalent:

```bash
fu-tabcheck [options] <FILE>...
```

Both commands share the same behavior and options:

```text
Options:
  -s, --separator CHAR   Character separating the values, 'tab' for tab and 'auto'
                         to try tab or commas [default: auto]
  -c, --comment CHAR     Comment/Header char [default: #]
  -i, --inspect          Gather more informations on column content [if valid column]
  --header               Print a header to the report
  --verbose              Enable verbose mode
```

## See also

For full documentation and examples, see **[seqfu tabcheck]({{site.baseurl}}/tools/tabcheck.html)**.
