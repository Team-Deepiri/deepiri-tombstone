.PHONY: all help clean dist test verify \
        libdeepiri_tombstone.a combined.b \
        bin/tokenize bin/score bin/audit bin/parse bin/build_request \
        bin/http_fallback deepiri-tombstone-core deepiri-tombstone

BLANG ?= $(CURDIR)/vendor/blang
CLANG ?= gcc
LIBB ?= $(CURDIR)/vendor/libb.a

all: deepiri-tombstone

help:
	@echo "deepiri-tombstone Makefile"
	@echo "  all       — build everything (default)"
	@echo "  clean     — remove build artifacts"
	@echo "  dist      — clean + all"
	@echo "  test      — run integration verification"
	@echo "  verify    — alias for test"

libdeepiri_tombstone.a: c/ollama_bridge.c c/ollama_bridge.h
	$(CLANG) -c -o c/ollama_bridge.o c/ollama_bridge.c
	ar rcs libdeepiri_tombstone.a c/ollama_bridge.o

combined.b: b/util.b b/cli.b b/main.b
	cat b/util.b b/cli.b b/main.b > combined.b

deepiri-tombstone-core: combined.b libdeepiri_tombstone.a
	@mkdir -p bin
	@command -v $(BLANG) >/dev/null || { echo "install blang first: ./scripts/install-deps.sh"; exit 1; }
	$(BLANG) combined.b --emit-llvm -o combined.ll
	$(CLANG) combined.ll -L. -ldeepiri_tombstone $(LIBB) -o bin/deepiri-tombstone-core

deepiri-tombstone: deepiri-tombstone-core scripts/run-b.sh bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback
	cp scripts/run-b.sh deepiri-tombstone
	chmod +x deepiri-tombstone bin/deepiri-tombstone-core bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback

test verify:
	bash scripts/verify_all.sh

bin/tokenize: forth/tokenize.fs scripts/tokenize_fallback.sh
	@mkdir -p bin
	if command -v gforth >/dev/null 2>&1; then \
	  printf '#!/usr/bin/env bash\nset -euo pipefail\ncd "$$(dirname "$$0")/.."\ngforth -e "include forth/tokenize.fs"\n' > bin/tokenize; \
	else \
	  cp scripts/tokenize_fallback.sh bin/tokenize; \
	fi
	chmod +x bin/tokenize

bin/score: fortran/score.f scripts/score_fallback.sh
	@mkdir -p bin reports
	if command -v gfortran >/dev/null 2>&1; then \
	  gfortran -o bin/score fortran/score.f; \
	else \
	  cp scripts/score_fallback.sh bin/score; \
	fi
	chmod +x bin/score

bin/audit: cobol/audit.cob scripts/audit_fallback.sh
	@mkdir -p bin reports
	if command -v cobc >/dev/null 2>&1; then \
	  cobc -x -o bin/audit cobol/audit.cob; \
	else \
	  cp scripts/audit_fallback.sh bin/audit; \
	fi
	chmod +x bin/audit

bin/parse: awk/parse_response.awk
	@mkdir -p bin
	cp awk/parse_response.awk bin/parse
	chmod +x bin/parse

bin/build_request: bcpl/build_request.b scripts/build_request_fallback.sh
	@mkdir -p bin
	if command -v cintsys >/dev/null 2>&1; then \
	  echo "bcpl/build_request.b (BCPL source available — use cintsys manually for native)"; \
	  cp scripts/build_request_fallback.sh bin/build_request; \
	else \
	  cp scripts/build_request_fallback.sh bin/build_request; \
	fi
	chmod +x bin/build_request

bin/http_fallback: perl/http_fallback.pl
	@mkdir -p bin
	cp perl/http_fallback.pl bin/http_fallback
	chmod +x bin/http_fallback

clean:
	rm -f combined.b combined.ll c/ollama_bridge.o libdeepiri_tombstone.a
	rm -f bin/deepiri-tombstone-core deepiri-tombstone
	rm -f bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback

dist: clean all
