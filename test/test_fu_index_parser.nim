import unittest

import ../src/fu_index

suite "fu-index parser":
  test "CASAVA comment fields are parsed from the comment":
    let info = getReadInfo(
      "A00709:43:HYG25DSXX:1:1101:3640:1000",
      "1:Y:0:TACGCTGC+CTATTAAG"
    )

    check info.instrument == "A00709"
    check info.run == 43
    check info.flowcell == "HYG25DSXX"
    check info.lane == 1
    check info.tile == 1101
    check info.x == 3640
    check info.y == 1000
    check info.read == 1
    check info.filtered
    check info.control == 0
    check info.index == "TACGCTGC+CTATTAAG"
