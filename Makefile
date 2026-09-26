
# Create "make test"
.PHONY: all test clean build remove-obsolete

BIN=./bin
SCRIPTS=./scripts
SOURCE=./src
DATA=./data
# CC/CXX use make's defaults (cc, g++) unless set in the environment or on the
# command line, so toolchains such as conda-build are honoured without patching.
CFLAGS ?= -O3
CXXFLAGS ?= -std=c++11 -O3
LDLIBS=-lz
PTHREADLIBS=-pthread
VERSION := $(shell grep version seqfu.nimble  | grep  -o "[0-9]\\+\.[0-9]\\+\.[0-9]\\+")
# LTO=0 disables link-time optimisation (faster builds, or toolchains without LTO).
# NIMSTRIP=0 keeps symbols (not named STRIP: conda exports STRIP as a tool path).
# NIMFLAGS appends extra Nim options, e.g.
#   make NIMFLAGS='--passL:-Wl,-headerpad_max_install_names'
LTO ?= 1
NIMSTRIP ?= 1
NIMFLAGS ?=
ifeq ($(shell uname -s),Darwin)
# Apple ld ignores -s (what -d:strip adds); -x drops local symbols instead
STRIPFLAG := --passL:-Wl,-x
else
STRIPFLAG := -d:strip
endif
NIMPARAM := --mm:orc -d:NimblePkgVersion=$(VERSION) -d:release --opt:speed --passC:"-Wno-error=incompatible-pointer-types"
NIMPARAM += $(if $(filter 1,$(LTO)),-d:lto) $(if $(filter 1,$(NIMSTRIP)),$(STRIPFLAG)) $(NIMFLAGS)
TARGETS=$(BIN)/seqfu $(BIN)/fu-msa $(BIN)/fu-primers $(BIN)/dadaist2-mergeseqs $(BIN)/fu-shred $(BIN)/fu-multirelabel $(BIN)/fu-index $(BIN)/fu-cov $(BIN)/fu-16Sregion  $(BIN)/fu-nanotags  $(BIN)/fu-orf  $(BIN)/fu-sw  $(BIN)/fu-virfilter  $(BIN)/fu-tabcheck $(BIN)/byteshift $(BIN)/SeqCountHelper $(BIN)/fu-secheck
OBSOLETE_TARGETS=$(BIN)/fu-homocomp $(BIN)/fu-readtope
PYTARGETS=$(BIN)/fu-split $(BIN)/fu-pecheck

all: remove-obsolete $(TARGETS) $(PYTARGETS)

remove-obsolete:
	rm -f $(OBSOLETE_TARGETS)

sources/: src/sfu.nim
	mkdir -p sources
	nim c --cc:gcc $(NIMPARAM) --nimcache:sources/ --genScript ./src/sfu.nim
	bash test/convert.sh sources/compile_sfu.sh

# nimble can exit 0 after failing to resolve dependencies: check its output
src/deps.txt: seqfu.nimble
	nimble install -y --depsOnly > $@.log 2>&1 || { cat $@.log; rm -f $@.log; exit 1; }
	@if grep -q "Error:" $@.log; then cat $@.log; rm -f $@.log; exit 1; fi
	mv $@.log $@

src/sfu.nim: ./src/fast*.nim ./src/filter_*.nim ./src/*utils*.nim src/adapters.nim src/known_adapters.nim src/fu_tabcheck.nim src/fu_orf.nim src/msa.nim src/shred.nim src/lib/msa_reader.nim src/deps.txt seqfu.nimble
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

$(BIN)/seqfu: src/sfu.nim
	nim c --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/fu-primers: src/fu_primers.nim src/deps.txt
	nim c --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/fu-shred: src/fu_shred.nim src/deps.txt
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-nanotags: src/fu_nanotags.nim src/deps.txt
	nim c  --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/fu-orf: src/fu_orf.nim src/deps.txt
	nim c --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/fu-sw: src/fu_sw.nim src/deps.txt
	nim c --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/fu-multirelabel: src/fu_multirelabel.nim src/deps.txt
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-index: src/fu_index.nim src/deps.txt
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-cov: src/fu_cov.nim src/deps.txt
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-msa: src/fu_msa.nim src/deps.txt
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-virfilter: src/fu_virfilter.nim src/deps.txt
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-tabcheck: src/fu_tabcheck.nim src/deps.txt
	nim c $(NIMPARAM) --out:$@ $<

$(BIN)/fu-16Sregion: src/dadaist2_region.nim src/deps.txt
	nim c  --threads:on $(NIMPARAM) --out:$@ $<

$(BIN)/dadaist2-mergeseqs: src/dadaist2_mergeseqs.nim src/deps.txt
	nim c $(NIMPARAM) --out:$@ $<

multiqc: $(BIN)/seqfu
	mkdir -p temp-mqc
	$(BIN)/seqfu stats $(DATA)/filt.fa.gz $(DATA)/orf.fa.gz --multiqc temp-mqc/stats_mqc.txt
	$(BIN)/seqfu count-legacy $(DATA)/filt.fa.gz $(DATA)/orf.fa.gz --multiqc temp-mqc/counts_mqc.txt
	multiqc -f -o multiqc/ temp-mqc
	rm -rf temp-mqc
	open "multiqc/multiqc_report.html"

build: remove-obsolete
	nimble build

test: all
	bash ./test/mini.sh

clean:
	@echo "Cleaning..."
	@for i in $(TARGETS); \
	do \
		if [ -e "$$i" ]; then rm -f $$i; echo "Removing $$i"; else echo "$$i Not found"; fi \
	done
	@rm -f $(OBSOLETE_TARGETS)
