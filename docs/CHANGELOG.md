# Changelog

All notable changes to deepiri-tombstone are documented here.

## [0.1.0] — 2026-06-19

### Added

- Repository scaffold with Makefile, .gitignore, LICENSE
- COBOL append-only audit ledger (`src/audit/ledger.cob`)
- Fortran scorer with running stats (`src/score/score.f`)
- AWK JSON response parser (`src/parse/response.awk`)
- Perl HTTP fallback client (`src/transport/http_fallback.pl`)
- Forth prompt tokenizer (`src/tokenize/tokenize.fs`)
- BCPL JSON request builder (`src/request/build_request.b`)
- B orchestrator (`src/orchestrator/main.b`, `src/orchestrator/cli.b`, `src/orchestrator/util.b`)
- C bridge library (`src/bridge/ollama_bridge.c`, `src/bridge/ollama_bridge.h`)
- CI workflow (`.github/workflows/ci.yml`)
- Fixture-based eval system (`fixtures/eval_prompts.txt`)
- Dependency installer, model puller, validator scripts
