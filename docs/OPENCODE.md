# OPENCODE — deepiri-tombstone spec

## Build

```bash
make clean && make
```

Produces `bin/deepiri-tombstone-core` and wrapper `deepiri-tombstone`.

## Commands

| Command | Args | Description |
|---------|------|-------------|
| `ping` | — | Check Ollama reachability |
| `ask` | `<model> <prompt>` | Single prompt → response → audit |
| `eval` | `[model] [fixture]` | Batch eval from fixture file |

## Pipeline (one eval run)

1. `fixture_next()` → prompt + keyword
2. `run_tokenize(prompt)` — word count + 512-budget check
3. `ollama_generate(model, prompt)` → raw JSON
4. `bin/parse` — extract `"response"` field
5. `check_keyword(response, keyword)` — case-insensitive match
6. `run_score(latency, response)` — Fortran scorer
7. `bin/audit` — append to `reports/audit.ledger`

## Commit convention

`feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:` per conventional commits.

## Files not to touch

- `b/` — B orchestrator (Cursor)
- `c/` — C bridge library (Cursor)
- `Makefile` — root build (Cursor)
