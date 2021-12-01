---
sort: 13
---


# fu-msa

```note
Preliminary version
```

Interactive multiple sequence alignment viewer.


```text
Usage:
    full [options] <MSAFILE>

  Options:
    -m, --mouse             Enable mouse
    -n, --norefresh         Disable autorefresh
    -w, --label-width INT   Sequence label width [default: 20]

  Keys:
    Scroll Horizontally     Left and Right arrow
      By 10 bases           L, K
      By 100 bases          ShiftL, ShiftK
      To the beginning      1
      To middle parts       2..9
      To the end            0

    Scroll Vertically       A, Up Arrow/ Z, Down Arrow
      Jump to top           ShiftA, PageUp
      Jump to bottom        ShiftZ, PageDown

    Rotate color scheme     Tab
    Refresh screen          F5
    Resize seq labels       -,+
```