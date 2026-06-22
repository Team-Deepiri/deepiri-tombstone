.PHONY: all help clean dist test verify unit-test smoke-test hooks install-completion \
        stats check-deps config archive watch clean-all components \
        validate-requirements validate-config validate-fixtures validate-scripts validate-commits \
        update-changelog summary e2e benchmark compare-models trend report-full \
        libdeepiri_tombstone.a combined.b \
        bin/tokenize bin/score bin/audit bin/parse bin/build_request \
        bin/http_fallback deepiri-tombstone-core deepiri-tombstone \
        stage.tokenize stage.score stage.audit stage.parse stage.request stage.transport \
        docker-build docker-run docker-shell man

SRC_ORCH   := src/orchestrator
SRC_BRIDGE := src/bridge
SRC_TOKEN  := src/tokenize
SRC_PARSE  := src/parse
SRC_SCORE  := src/score
SRC_AUDIT  := src/audit
SRC_REQ    := src/request
SRC_HTTP   := src/transport

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
	@echo "  unit-test       — run unit tests for each component"
	@echo "  smoke-test      — quick project health check"
	@echo "  components      — list pipeline stages"
	@echo "  docker-build    — build Docker image"

hooks:
	bash scripts/install-hooks.sh

install-completion:
	@mkdir -p $(HOME)/.local/share/bash-completion/completions
	cp scripts/completion.sh $(HOME)/.local/share/bash-completion/completions/deepiri-tombstone

stats:
	bash scripts/stats.sh

check-deps:
	bash scripts/check-deps.sh

config:
	bash scripts/config.sh

archive:
	bash scripts/archive-reports.sh

watch:
	bash scripts/watch.sh

clean-all:
	bash scripts/clean-all.sh

smoke-test:
	bash scripts/smoke-test.sh

validate-requirements:
	bash scripts/validate-requirements.sh

validate-config:
	bash scripts/validate-config.sh

validate-fixtures:
	bash scripts/validate_fixtures.sh

validate-scripts:
	bash scripts/verify-scripts.sh

validate-commits:
	bash scripts/verify-commits.sh

update-changelog:
	bash scripts/update-changelog.sh

summary:
	bash scripts/summary.sh

e2e:
	bash scripts/e2e.sh

benchmark:
	bash scripts/benchmark.sh

compare-models:
	bash scripts/compare-models.sh

trend:
	bash scripts/trend.sh

report-full:
	bash scripts/report.sh

components:
	@echo "Pipeline stages (src/):"
	@echo "  orchestrator/  — B eval loop (ping, ask, eval)"
	@echo "  bridge/        — Ollama HTTP + buffers"
	@echo "  tokenize/      — prompt word budget"
	@echo "  parse/         — Ollama JSON response extract"
	@echo "  score/         — latency and pass-rate stats"
	@echo "  audit/         — eval ledger append"
	@echo "  request/       — generate API JSON builder"
	@echo "  transport/     — HTTP fallback client"

libdeepiri_tombstone.a: $(SRC_BRIDGE)/ollama_bridge.c $(SRC_BRIDGE)/ollama_bridge.h
	$(CC) -c -o $(SRC_BRIDGE)/ollama_bridge.o $(SRC_BRIDGE)/ollama_bridge.c
	ar rcs libdeepiri_tombstone.a $(SRC_BRIDGE)/ollama_bridge.o

combined.b: $(SRC_ORCH)/util.b $(SRC_ORCH)/cli.b $(SRC_ORCH)/main.b
	cat $(SRC_ORCH)/util.b $(SRC_ORCH)/cli.b $(SRC_ORCH)/main.b > combined.b

vendor/llvm/usr/bin/clang-18:
	@echo "run scripts/bootstrap-toolchain.sh to extract vendored clang"
	@exit 1

B_BRIDGE_FUNCS := get_cmd get_arg1 get_arg2 format_run_id str_len str_copy getenv_str \
	time_ms read_file write_file ollama_ping ollama_generate ollama_chat run_filter \
	system_cmd fixture_open fixture_next fixture_close format_audit run_score run_score_args run_tokenize \
	resp_buf parsed_buf prompt_buf keyword_buf audit_buf runid_buf status_buf model_buf \
	fixture_buf cmd_buf arg1_buf arg2_buf set_retry_count ollama_retry_generate ollama_models fixture_category
B_DEFSYMS := $(foreach fn,$(B_BRIDGE_FUNCS),-Wl,--defsym=b.$(fn)=$(fn))

deepiri-tombstone-core: combined.b libdeepiri_tombstone.a vendor/llvm/usr/bin/clang-18
	@mkdir -p bin
	@command -v $(BLANG) >/dev/null || { echo "install blang first: ./setup.sh"; exit 1; }
	$(BLANG) combined.b --emit-llvm -o combined.ll
	$(CLANG) combined.ll $(SRC_BRIDGE)/ollama_bridge.o $(LIBB) $(B_DEFSYMS) -o bin/deepiri-tombstone-core

deepiri-tombstone: deepiri-tombstone-core scripts/run-b.sh bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback
	cp scripts/run-b.sh deepiri-tombstone
	chmod +x deepiri-tombstone bin/deepiri-tombstone-core bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback

test verify:
	bash scripts/verify_all.sh

unit-test:
	bash tests/run_tests.sh

bin/tokenize: $(SRC_TOKEN)/tokenize.fs $(SRC_TOKEN)/fallback.sh
	@mkdir -p bin
	if command -v gforth >/dev/null 2>&1; then \
	  printf '#!/usr/bin/env bash\nset -euo pipefail\ncd "$$(dirname "$$0")/.."\ngforth -e "include src/tokenize/tokenize.fs"\n' > bin/tokenize; \
	else \
	  cp $(SRC_TOKEN)/fallback.sh bin/tokenize; \
	fi
	chmod +x bin/tokenize

bin/score: $(SRC_SCORE)/score.f $(SRC_SCORE)/fallback.sh
	@mkdir -p bin reports
	if command -v gfortran >/dev/null 2>&1; then \
	  gfortran -o bin/score $(SRC_SCORE)/score.f; \
	else \
	  cp $(SRC_SCORE)/fallback.sh bin/score; \
	fi
	chmod +x bin/score

bin/audit: $(SRC_AUDIT)/ledger.cob $(SRC_AUDIT)/fallback.sh
	@mkdir -p bin reports
	if command -v cobc >/dev/null 2>&1; then \
	  cobc -x -o bin/audit $(SRC_AUDIT)/ledger.cob; \
	else \
	  cp $(SRC_AUDIT)/fallback.sh bin/audit; \
	fi
	chmod +x bin/audit

bin/parse: $(SRC_PARSE)/response.awk
	@mkdir -p bin
	cp $(SRC_PARSE)/response.awk bin/parse
	chmod +x bin/parse

bin/build_request: $(SRC_REQ)/build_request.b $(SRC_REQ)/fallback.sh
	@mkdir -p bin
	cp $(SRC_REQ)/fallback.sh bin/build_request
	chmod +x bin/build_request

bin/http_fallback: $(SRC_HTTP)/http_fallback.pl
	@mkdir -p bin
	cp $(SRC_HTTP)/http_fallback.pl bin/http_fallback
	chmod +x bin/http_fallback

stage.tokenize: bin/tokenize
stage.score: bin/score
stage.audit: bin/audit
stage.parse: bin/parse
stage.request: bin/build_request
stage.transport: bin/http_fallback

clean:
	rm -f combined.b combined.ll $(SRC_BRIDGE)/ollama_bridge.o libdeepiri_tombstone.a
	rm -f bin/deepiri-tombstone-core deepiri-tombstone
	rm -f bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback

dist: clean all

docker-build:
	docker build -t deepiri-tombstone .

docker-run:
	docker run --rm -e DEEPIRI_TOMBSTONE_HOST -e DEEPIRI_TOMBSTONE_MODEL deepiri-tombstone

docker-shell:
	docker run --rm -it --entrypoint bash deepiri-tombstone

man:
	@mkdir -p /usr/local/share/man/man1 2>/dev/null; \
	 cp man/man1/deepiri-tombstone.1 /usr/local/share/man/man1/ 2>/dev/null && \
	 echo "installed man page" || echo "copy man/man1/deepiri-tombstone.1 manually"
