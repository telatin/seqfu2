
# Create "make test"
.PHONY: test clean build

BIN=./bin
SOURCE=./src
VERSION := $(shell grep version seqfu.nimble  | grep  -o "[0-9]\\+\.[0-9]\.[0-9]\\+")
NIMPARAM :=  --gc:arc -d:NimblePkgVersion=$(VERSION) -d:release --opt:speed 
TARGETS=$(BIN)/seqfu $(BIN)/fu-primers $(BIN)/dadaist2-mergeseqs $(BIN)/fu-shred $(BIN)/fu-homocomp $(BIN)/fu-multirelabel $(BIN)/fu-index $(BIN)/fu-cov $(BIN)/fu-16Sregion  $(BIN)/fu-nanotags  $(BIN)/fu-orf  $(BIN)/fu-sw  $(BIN)/fu-virfilter  $(BIN)/fu-tabcheck  $(BIN)/fu-homocomp 

all: $(TARGETS)

bin/seqfu: src/sfu.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-primers: src/fu_primers.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-shred: src/fu_shred.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-nanotags: src/fu_nanotags.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-orf: src/fu_orf.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-sw: src/fu_sw.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-homocomp: src/fu_homocomp.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-multirelabel: src/fu_multirelabel.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-index: src/fu_index.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-cov: src/fu_cov.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-virfilter: src/fu_virfilter.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-tabcheck: src/fu_tabcheck.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/fu-16Sregion: src/dadaist2_region.nim
	nim c $(NIMPARAM) --out:$@ $<

bin/dadaist2-mergeseqs: src/dadaist2_mergeseqs.nim
	nim c $(NIMPARAM) --out:$@ $<





build:
	nimble build

test:
	bash ./test/mini.sh

clean:
	@echo "Cleaning..."
	@for i in $(TARGETS); \
	do \
		if [ -e "$$i" ]; then rm -f $$i; echo "Removing $$i"; else echo "$$i Not found"; fi \
	done