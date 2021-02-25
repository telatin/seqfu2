| Command | Mean [s] | Min [s] | Max [s] | Relative |
|:---|---:|---:|---:|---:|
| `./bin/seqfu interleave -1 R1.fq -2 R2.fq` | 4.229 ± 0.032 | 4.201 | 4.310 | 1.01 ± 0.02 |
| `seqfu interleave -1 R1.fq -2 R2.fq` | 4.202 ± 0.056 | 4.168 | 4.355 | 1.00 |
| `paste R1.fq R2.fq \| paste - - - - \| awk -v OFS='\n' -v FS='\t' '{print($1,$3,$5,$7,$2,$4,$6,$8)}'` | 4.699 ± 0.033 | 4.670 | 4.786 | 1.12 ± 0.02 |
