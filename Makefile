.PHONY: all help clean dist test verify hooks stats components \
        libdeepiri_tombstone.a combined.b \
        bin/tokenize bin/score bin/audit bin/parse bin/build_request \
        bin/http_fallback deepiri-tombstone-core deepiri-tombstone \
        fortran.score cobol.audit forth.tokenize awk.parse bcpl.request perl.http

BLANG ?= $(CURDIR)/vendor/blang
CC ?= gcc
CLANG ?= $(CURDIR)/vendor/llvm/usr/bin/clang-18
LLVM_LIB ?= $(CURDIR)/vendor/llvm/usr/lib/x86_64-linux-gnu
LIBB ?= $(CURDIR)/vendor/libb.a
export LD_LIBRARY_PATH := $(LLVM_LIB):$(LD_LIBRARY_PATH)

all: deepiri-tombstone

help:
	@echo "deepiri-tombstone Makefile"
	@echo "  all             — build everything (default)"
	@echo "  clean           — remove build artifacts"
	@echo "  dist            — clean + all"
	@echo "  test verify     — run integration verification"
	@echo "  hooks           — install git pre-commit hooks"
	@echo "  stats           — show project statistics"
	@echo "  components      — list all pipeline components"
	@echo "  fortran.score   — build Fortran scorer"
	@echo "  cobol.audit     — build COBOL audit"
	@echo "  forth.tokenize  — build Forth tokenizer"
	@echo "  awk.parse       — build AWK parser"
	@echo "  perl.http       — build Perl HTTP fallback"
	@echo "  bcpl.request    — build BCPL request builder"

hooks:
	bash scripts/install-hooks.sh

stats:
	bash scripts/stats.sh

components:
	@echo "Pipeline components:"
	@echo "  bin/tokenize       — Forth tokenizer"
	@echo "  bin/score          — Fortran scorer"
	@echo "  bin/audit          — COBOL audit"
	@echo "  bin/parse          — AWK JSON parser"
	@echo "  bin/build_request  — BCPL request builder"
	@echo "  bin/http_fallback  — Perl HTTP client"
	@echo "  bin/deepiri-tombstone-core — B orchestrator"

libdeepiri_tombstone.a: c/ollama_bridge.c c/ollama_bridge.h
	$(CC) -c -o c/ollama_bridge.o c/ollama_bridge.c
	ar rcs libdeepiri_tombstone.a c/ollama_bridge.o

combined.b: b/util.b b/cli.b b/main.b
	cat b/util.b b/cli.b b/main.b > combined.b

vendor/llvm/usr/bin/clang-18:
	@echo "run scripts/bootstrap-toolchain.sh to extract vendored clang"
	@exit 1

B_BRIDGE_FUNCS := get_cmd get_arg1 get_arg2 format_run_id str_len str_copy getenv_str \
	time_ms read_file write_file ollama_ping ollama_generate ollama_chat run_filter \
	system_cmd fixture_open fixture_next fixture_close format_audit run_score run_tokenize
B_DEFSYMS := $(foreach fn,$(B_BRIDGE_FUNCS),-Wl,--defsym=b.$(fn)=$(fn))

deepiri-tombstone-core: combined.b libdeepiri_tombstone.a vendor/llvm/usr/bin/clang-18
	@mkdir -p bin
	@command -v $(BLANG) >/dev/null || { echo "install blang first: ./scripts/install-deps.sh"; exit 1; }
	$(BLANG) combined.b --emit-llvm -o combined.ll
	$(CLANG) combined.ll c/ollama_bridge.o $(LIBB) $(B_DEFSYMS) -o bin/deepiri-tombstone-core

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

# Individual component aliases
fortran.score: bin/score
cobol.audit: bin/audit
forth.tokenize: bin/tokenize
awk.parse: bin/parse
bcpl.request: bin/build_request
perl.http: bin/http_fallback

clean:
	rm -f combined.b combined.ll c/ollama_bridge.o libdeepiri_tombstone.a
	rm -f bin/deepiri-tombstone-core deepiri-tombstone
	rm -f bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback

dist: clean all
