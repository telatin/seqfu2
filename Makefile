
# Create "make test"
.PHONY: test clean build

BIN=./bin
SOURCE=./src
VERSION := $(shell grep version seqfu.nimble  | grep  -o "[0-9]\\+\.[0-9]\.[0-9]\\+")

TARGETS=$(BIN)/seqfu $(BIN)/fu-homocomp $(BIN)/fu-multirelabel $(BIN)/fu-index $(BIN)/fu-cov $(BIN)/fu-16Sregion  $(BIN)/fu-nanotags  $(BIN)/fu-orf  $(BIN)/fu-sw  $(BIN)/fu-virfilter  $(BIN)/fu-tabcheck  $(BIN)/fu-homocomp 


#bin/seqfu: src/sfu.nim
#	nim c -d:NimblePkgVersion=$(VERSION) -d:release -d:danger --opt:speed --out:$@ $<

bin/seqfu:
	nimble build
test:
	bash ./test/mini.sh

clean:
	@echo "Cleaning..."
	@for i in $(LIST) bin/seqfu; \
	do \
		if [ -e "$$i" ]; then rm -f $$i; echo "Removing $$i"; else echo "$$i Not found"; fi \
	done