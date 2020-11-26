| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `vsearch --derep_fulllength ./input/filt.fa.gz --output /tmp/vsearch.fa` | 179.1 ± 9.6 | 170.1 | 198.0 | 1.06 ± 0.10 |
| `./bin/derep_Darwin ./input/filt.fa.gz > /tmp/derep.fa` | 169.2 ± 13.1 | 150.0 | 211.8 | 1.00 |
| `perl ./test/uniq.pl ./input/filt.fa.gz > /tmp/uniq.fa ` | 956.9 ± 64.5 | 866.4 | 1063.1 | 5.65 ± 0.58 |
