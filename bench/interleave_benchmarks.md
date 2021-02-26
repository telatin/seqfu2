| Command | Mean [s] | Min [s] | Max [s] | Relative |
|:---|---:|---:|---:|---:|
| `seqfu interleave -1 R1.fq -2 R2.fq` | 4.706 ± 0.139 | 4.507 | 4.939 | 1.00 |
| `taskset 1 ./bash_interleave.sh R1.fq R2.fq` | 11.440 ± 0.068 | 11.349 | 11.595 | 2.43 ± 0.07 |
