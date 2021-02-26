| Command | Mean [s] | Min [s] | Max [s] | Relative |
|:---|---:|---:|---:|---:|
| `seqfu deinterleave -o de interleaved.fq` | 3.926 ± 0.080 | 3.831 | 4.075 | 1.00 |
| `taskset 1 ./bash_deinterleave.sh interleaved.fq de_R1.fq de_R2.fq` | 12.819 ± 0.098 | 12.659 | 12.952 | 3.26 ± 0.07 |
