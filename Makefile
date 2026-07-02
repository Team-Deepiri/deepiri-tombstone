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
SRC_JUDGE  := src/judge
SRC_MUTATE := src/mutate
SRC_BENCH  := src/bench
SRC_SYNTH  := src/synth
SRC_REPORT := src/report
SRC_TRACE  := src/trace

BLANG ?= $(CURDIR)/vendor/blang
CC ?= gcc
CLANG ?= $(CURDIR)/vendor/llvm/usr/bin/clang-18
LLVM_LIB ?= $(CURDIR)/vendor/llvm/usr/lib/x86_64-linux-gnu
LIBB ?= $(CURDIR)/vendor/libb.a
export LD_LIBRARY_PATH := $(LLVM_LIB):$(LD_LIBRARY_PATH)

all: deepiri-tombstone judge mutate bench synth dashboard trace

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
	@echo ""
	@echo "New Advanced Stages:"
	@echo "  judge           — G-Eval LLM-as-a-Judge scorer"
	@echo "  mutate          — Adversarial prompt mutation engine"
	@echo "  bench           — Multi-model benchmark runner"
	@echo "  synth           — Synthetic dataset generator"
	@echo "  dashboard       — HTML report dashboard generator"
	@echo "  trace           — Span tracing & observability"

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
	@echo ""
	@echo "Advanced evaluation stages (new):"
	@echo "  judge/         — G-Eval LLM-as-a-Judge (Python)"
	@echo "  mutate/        — Adversarial mutation engine (Python)"
	@echo "  bench/         — Multi-model benchmark runner (Python)"
	@echo "  synth/         — Synthetic dataset generator (Python)"
	@echo "  report/        — HTML dashboard generator (Python)"
	@echo "  trace/         — Span tracing & observability (Python)"

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

# --- Advanced evaluation stages ---

bin/judge: $(SRC_JUDGE)/judge.py $(SRC_JUDGE)/fallback.sh
	@mkdir -p bin
	if command -v python3 >/dev/null 2>&1; then \
	  cp $(SRC_JUDGE)/judge.py bin/judge; \
	else \
	  cp $(SRC_JUDGE)/fallback.sh bin/judge; \
	fi
	chmod +x bin/judge

bin/mutate: $(SRC_MUTATE)/mutate.py $(SRC_MUTATE)/fallback.sh
	@mkdir -p bin
	if command -v python3 >/dev/null 2>&1; then \
	  cp $(SRC_MUTATE)/mutate.py bin/mutate; \
	else \
	  cp $(SRC_MUTATE)/fallback.sh bin/mutate; \
	fi
	chmod +x bin/mutate

bin/bench: $(SRC_BENCH)/bench.py $(SRC_BENCH)/fallback.sh
	@mkdir -p bin
	if command -v python3 >/dev/null 2>&1; then \
	  cp $(SRC_BENCH)/bench.py bin/bench; \
	else \
	  cp $(SRC_BENCH)/fallback.sh bin/bench; \
	fi
	chmod +x bin/bench

bin/synth: $(SRC_SYNTH)/synth.py $(SRC_SYNTH)/fallback.sh
	@mkdir -p bin
	if command -v python3 >/dev/null 2>&1; then \
	  cp $(SRC_SYNTH)/synth.py bin/synth; \
	else \
	  cp $(SRC_SYNTH)/fallback.sh bin/synth; \
	fi
	chmod +x bin/synth

bin/dashboard: $(SRC_REPORT)/dashboard.py
	@mkdir -p bin
	cp $(SRC_REPORT)/dashboard.py bin/dashboard
	chmod +x bin/dashboard

bin/trace: $(SRC_TRACE)/trace.py
	@mkdir -p bin
	cp $(SRC_TRACE)/trace.py bin/trace
	chmod +x bin/trace

# --- Stage aliases ---

stage.tokenize: bin/tokenize
stage.score: bin/score
stage.audit: bin/audit
stage.parse: bin/parse
stage.request: bin/build_request
stage.transport: bin/http_fallback
stage.judge: bin/judge
stage.mutate: bin/mutate
stage.bench: bin/bench
stage.synth: bin/synth
stage.dashboard: bin/dashboard
stage.trace: bin/trace

judge: bin/judge
mutate: bin/mutate
bench: bin/bench
synth: bin/synth
dashboard: bin/dashboard
trace: bin/trace

clean:
	rm -f combined.b combined.ll $(SRC_BRIDGE)/ollama_bridge.o libdeepiri_tombstone.a
	rm -f bin/deepiri-tombstone-core deepiri-tombstone
	rm -f bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback
	rm -f bin/judge bin/mutate bin/bench bin/synth bin/dashboard bin/trace

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
