# Source layout (`src/`)

Pipeline code is grouped by **function**, not programming language.

```
src/
  orchestrator/   ping, ask, eval — B orchestrator
  bridge/         Ollama HTTP, buffers, fixture I/O — C
  tokenize/       prompt word budget
  parse/          extract model response from JSON
  score/          latency + pass-rate statistics
  audit/          append-only eval ledger
  request/        build /api/generate JSON payload
  transport/      HTTP fallback when bridge fails
```

Each stage directory contains its implementation plus an optional `fallback.sh`
for hosts missing native compilers (gforth, gfortran, gnucobol, etc.).

Built binaries land in `bin/` (`bin/parse`, `bin/score`, …).
