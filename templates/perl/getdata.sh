#!/bin/bash
set -euxo pipefail
## https://umi-tools.readthedocs.io/en/latest/Single_cell_tutorial.html#step-1-obtaining-the-data
wget "http://cf.10xgenomics.com/samples/cell-exp/1.3.0/hgmm_100/hgmm_100_fastqs.tar"
tar -x hgmm_100_fastqs.tar
