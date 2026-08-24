# Changelog

## 2.1.1 — 2026-08-24

Production speed pass — shared cache identity + measurable SLOs.

### Added
- Unified SHA-256 cache keys across B bridge and Python (classic ↔ hot path share hits).
- Runner warm-on-start, adaptive jobs (`default_jobs` 4–16), `slo` block in eval JSON
  (`η`, cache hit rate, prompts/sec, production gates).
- `docs/PERFORMANCE.md` — harness speed model and invariants.
- Doctor checks `libcrypto`, SLO module, and adaptive job hint.

### Changed
- Core links `-lcrypto` for SHA-256; CI/Docker/install-deps install `libssl-dev`.

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
- Shared `src/common/paths.py` (`ensure_common_path`, `read_version`, `repo_root`)
  used by all Python stages; CLI exports `PYTHONPATH`.
- CI and Docker install `libcurl` for the keep-alive B bridge.

### Fixed
- Ledger `|`-in-prompt field shift (shared `ledger.py` parser).
- `make` overwriting the CLI dispatcher; Docker entrypoint truncation.
- `rag` context argument duplication; CI test discovery drift.

## Earlier

See git history for 2.0.x harness stages, vintage pipeline, and fixtures.
