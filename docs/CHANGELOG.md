# Changelog

All notable changes to deepiri-tombstone are documented here.

## [0.1.0] — 2026-06-19

### Added

- Repository scaffold with Makefile, .gitignore, LICENSE
- COBOL append-only audit ledger (`cobol/audit.cob`)
- Fortran scorer with running stats (`fortran/score.f`)
- AWK JSON response parser (`awk/parse_response.awk`)
- Perl HTTP fallback client (`perl/http_fallback.pl`)
- Forth prompt tokenizer (`forth/tokenize.fs`)
- BCPL JSON request builder (`bcpl/build_request.b`)
- B orchestrator (`b/main.b`, `b/cli.b`, `b/util.b`)
- C bridge library (`c/ollama_bridge.c`, `c/ollama_bridge.h`)
- CI workflow (`.github/workflows/ci.yml`)
- Fixture-based eval system (`fixtures/eval_prompts.txt`)
- Dependency installer, model puller, validator scripts
