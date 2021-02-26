| Command | Mean [s] | Min [s] | Max [s] | Relative |
|:---|---:|---:|---:|---:|
| `seqfu deinterleave -o deinterleaved. interleaved.fq` | 4.194 ± 0.060 | 4.086 | 4.311 | 1.00 |
| `paste - - - - - - - - < interleaved.fq \| tee >(cut -f 1-4 \| tr '\t' '\n' > R1.deinterleaved.fq) \| cut -f 5-8 \| tr '\t' '\n' > R2.deinterleaved.fq` | 5.106 ± 0.057 | 5.007 | 5.196 | 1.22 ± 0.02 |
