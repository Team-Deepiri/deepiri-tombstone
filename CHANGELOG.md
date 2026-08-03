# Changelog

## Unreleased

### Fixed
- Ledger rows whose prompt contained a `|` silently reported the latency as the
  status and the response as the latency, in every consumer. Fields are now
  recovered from both ends by a shared parser (`src/common/ledger.py`), used by
  the export, replay, dashboard, and cost stages.
- `make` overwrote the checked-in CLI dispatcher with `scripts/run-b.sh`, so a
  freshly built tree silently lost all nineteen subcommands beyond
  `ping`/`ask`/`eval`. `make clean` also deleted the tracked file.
- The Docker image shipped that same launcher as its entrypoint.
- The `rag` dispatch passed its third argument twice, so the retrieved context
  was always the answer and faithfulness scored the answer against itself.
- `verify_all.sh` and CI enumerated test suites by hand and had drifted from
  `tests/`; both now discover them. The cost and export suites depended on a
  ledger written by the dashboard suite and now build their own.

### Added
- `version` command (and `--version`/`-V`) reporting the VERSION file.
- Test suites for CLI dispatch and the shared ledger parser.
- B-language orchestrator with `ping`, `ask`, `eval` commands
- C bridge (`libdeepiri_tombstone.a`) for Ollama HTTP
- Vintage pipeline: Forth, Fortran, COBOL, AWK, Perl, BCPL fallback
- Post-training eval fixtures and COBOL audit ledger
- Makefile and dependency installer
- chore: history slice 1
- chore: history slice 2
- chore: history slice 3
- chore: history slice 4
- chore: history slice 5
- chore: history slice 6
- chore: history slice 7
- chore: history slice 8
- chore: history slice 9
- chore: history slice 10
- chore: history slice 11
- chore: history slice 12
- chore: history slice 13
- chore: history slice 14
- chore: history slice 15
- chore: history slice 16
- chore: history slice 17
- chore: history slice 18
- chore: history slice 19
- chore: history slice 20
- chore: history slice 21
- chore: history slice 22
- chore: history slice 23
- chore: history slice 24
- chore: history slice 25
- chore: history slice 26
- chore: history slice 27
- chore: history slice 28
- chore: history slice 29
- chore: history slice 30
