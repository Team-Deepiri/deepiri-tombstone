# Contributing

## Commit convention

Use [conventional commits](https://www.conventionalcommits.org/):
`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`, `ci:`.

## One change per commit

Each commit should be a single logical change. If you're fixing two bugs, make two commits.

## Pipeline components

| Language | File | Maintainer |
|----------|------|------------|
| B | `src/orchestrator/*.b` | Cursor |
| C | `src/bridge/ollama_bridge.c` | Cursor |
| BCPL | `src/request/build_request.b` | opencode |
| Forth | `src/tokenize/tokenize.fs` | opencode |
| Fortran | `src/score/score.f` | opencode |
| COBOL | `src/audit/ledger.cob` | opencode |
| AWK | `src/parse/response.awk` | opencode |
| Perl | `src/transport/http_fallback.pl` | opencode |

## Before submitting

```bash
bash scripts/verify_all.sh
make clean && make
```
