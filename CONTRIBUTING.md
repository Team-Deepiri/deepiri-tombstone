# Contributing

## Commit convention

Use [conventional commits](https://www.conventionalcommits.org/):
`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`, `ci:`.

## One change per commit

Each commit should be a single logical change. If you're fixing two bugs, make two commits.

## Pipeline components

| Language | File | Maintainer |
|----------|------|------------|
| B | `b/*.b` | Cursor |
| C | `c/ollama_bridge.c` | Cursor |
| BCPL | `bcpl/build_request.b` | opencode |
| Forth | `forth/tokenize.fs` | opencode |
| Fortran | `fortran/score.f` | opencode |
| COBOL | `cobol/audit.cob` | opencode |
| AWK | `awk/parse_response.awk` | opencode |
| Perl | `perl/http_fallback.pl` | opencode |

## Before submitting

```bash
bash scripts/verify_all.sh
make clean && make
```
