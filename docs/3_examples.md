---
sort: 3
permalink: /examples
---
# Usage examples

## Find artifact by UUID

If you know that an artifact has a specific UUID and you want to locate its
file:

```
UUID="bb1b2e93-...-2afa2110b5fb"
find /path -name "*.qz?" | qax list -u  | grep $UUID
```
