# Changelog

## 2.1.0 — 2026-08-24

Finished-product release of the Deepiri post-training eval harness.

### Added
- Unified keep-alive Ollama client across Python stages (judge, rag, synth,
  replay, guard, chat, api, runner, bench, jury).
- Classic B castle: libcurl keep-alive bridge, in-process JSON/tokenize, cache,
  batched ledger, warm-up, fail-fast, `models` / `warm` / `summary`.
- `doctor` command — toolchain / bridge / Ollama / fixture readiness check.
- Parallel default `eval` with response cache and batched ledger; `--classic`
  for the B core path.
- CI and Docker install `libcurl` for the keep-alive B bridge.

### Fixed
- Ledger `|`-in-prompt field shift (shared `ledger.py` parser).
- `make` overwriting the CLI dispatcher; Docker entrypoint truncation.
- `rag` context argument duplication; CI test discovery drift.

## Earlier

See git history for 2.0.x harness stages, vintage pipeline, and fixtures.
