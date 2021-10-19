FROM debian:stretch-slim

LABEL maintainer="andrea.telatin@quadram.ac.uk"

RUN apt-get update && apt-get install -y wget=1.18-5 --no-install-recommends && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
RUN wget -q https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
RUN bash Miniconda3-latest-Linux-x86_64.sh -b -f -p "$HOME"/miniconda
RUN rm Miniconda3-latest-Linux-x86_64.sh

ENV PATH=/root/miniconda/bin:$PATH
RUN conda update -n base -c defaults conda
RUN conda install -y -c conda-forge  -c bioconda seqfu
