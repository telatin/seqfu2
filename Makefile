
# Create "make test"
.PHONY: test clean build

BIN=./bin
SCRIPTS=./scripts
SOURCE=./src
DATA=./data
CC=gcc
CFLAGS=-O3
CXX=g++
CXXFLAGS=-std=c++11 -O3
LDLIBS=-lz
PTHREADLIBS=-pthread
VERSION := $(shell grep version seqfu.nimble  | grep  -o "[0-9]\\+\.[0-9]\\+\.[0-9]\\+")
NIMPARAM :=  --mm:orc -d:NimblePkgVersion=$(VERSION) -d:release --opt:speed --passC:"-Wno-error=incompatible-pointer-types"
TARGETS=$(BIN)/seqfu $(BIN)/fu-msa $(BIN)/fu-primers $(BIN)/dadaist2-mergeseqs $(BIN)/fu-shred $(BIN)/fu-homocomp $(BIN)/fu-multirelabel $(BIN)/fu-index $(BIN)/fu-cov $(BIN)/fu-16Sregion  $(BIN)/fu-nanotags  $(BIN)/fu-orf  $(BIN)/fu-sw  $(BIN)/fu-virfilter  $(BIN)/fu-tabcheck $(BIN)/byteshift $(BIN)/SeqCountHelper $(BIN)/fu-secheck
PYTARGETS=$(BIN)/fu-split $(BIN)/fu-pecheck $(BIN)/fu-readtope

all: $(TARGETS) $(PYTARGETS)

sources/: src/sfu.nim
	mkdir -p sources
	nim c --cc:$(CC) $(NIMPARAM) --nimcache:sources/ --genScript ./src/sfu.nim
	bash test/convert.sh sources/compile_sfu.sh

src/deps.txt:
	nimble install -y --depsOnly
	touch $@

src/sfu.nim: ./src/fast*.nim ./src/*utils*.nim src/msa.nim src/lib/msa_reader.nim src/deps.txt seqfu.nimble
	touch $@ 

$(BIN)/byteshift: test/byte/shifter.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

$(BIN)/fu-secheck: test/byte/validate.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LDLIBS)

$(BIN)/SeqCountHelper: test/byte/count.cpp
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $< $(LDLIBS) $(PTHREADLIBS)

$(BIN)/fu-split: $(SCRIPTS)/fu-split
	cp -f $(SCRIPTS)/fu-split $(BIN)/fu-split
	sed -i.bak '2 s/^/### DO NOT EDIT THIS SCRIPT!\n/' $(BIN)/fu-split
	rm -f $(BIN)/fu-split.bak
	chmod 555 $(BIN)/fu-split

$(BIN)/fu-pecheck: $(SCRIPTS)/fu-pecheck
	cp -f $(SCRIPTS)/fu-pecheck $(BIN)/fu-pecheck
	sed -i.bak '2 s/^/### DO NOT EDIT THIS SCRIPT!\n/' $(BIN)/fu-pecheck
	rm -f $(BIN)/fu-pecheck.bak
	chmod 555 $(BIN)/fu-pecheck

$(BIN)/fu-readtope: $(SCRIPTS)/fu-readtope
	cp -f $(SCRIPTS)/fu-readtope $(BIN)/fu-readtope
	sed -i.bak '2 s/^/### DO NOT EDIT THIS SCRIPT!\n/' $(BIN)/fu-readtope
	rm -f $(BIN)/fu-readtope.bak
	chmod 555 $(BIN)/fu-readtope

$(BIN)/seqfu: src/sfu.nim
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-primers: src/fu_primers.nim
	nim c --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/fu-shred: src/fu_shred.nim
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-nanotags: src/fu_nanotags.nim
	nim c  --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/fu-orf: src/fu_orf.nim
	nim c --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/fu-sw: src/fu_sw.nim
	nim c --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/fu-homocomp: src/fu_homocomp.nim
	nim c --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/fu-multirelabel: src/fu_multirelabel.nim
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-index: src/fu_index.nim
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-cov: src/fu_cov.nim
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-msa: src/fu_msa.nim
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-virfilter: src/fu_virfilter.nim
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-tabcheck: src/fu_tabcheck.nim
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-16Sregion: src/dadaist2_region.nim
	nim c  --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/dadaist2-mergeseqs: src/dadaist2_mergeseqs.nim
	nim c $(NIMPARAM) --out:$@ $<

multiqc: $(BIN)/seqfu
	mkdir -p temp-mqc
	$(BIN)/seqfu stats $(DATA)/filt.fa.gz $(DATA)/orf.fa.gz --multiqc temp-mqc/stats_mqc.txt
	$(BIN)/seqfu count-legacy $(DATA)/filt.fa.gz $(DATA)/orf.fa.gz --multiqc temp-mqc/counts_mqc.txt
	multiqc -f -o multiqc/ temp-mqc
	rm -rf temp-mqc
	open "multiqc/multiqc_report.html"

build:
	nimble build

test: all
	bash ./test/mini.sh

clean:
	@echo "Cleaning..."
	@for i in $(TARGETS); \
	do \
		if [ -e "$$i" ]; then rm -f $$i; echo "Removing $$i"; else echo "$$i Not found"; fi \
	done
