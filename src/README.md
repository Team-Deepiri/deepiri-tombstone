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
  common/         shared helpers imported by the Python stages
```

Each stage directory contains its implementation plus an optional `fallback.sh`
for hosts missing native compilers (gforth, gfortran, gnucobol, etc.).

Built binaries land in `bin/` (`bin/parse`, `bin/score`, …).

Python stages are installed into `bin/` as standalone copies, so anything they
share is installed beside them: `src/common/ledger.py` becomes `bin/ledger.py`,
and each stage resolves the import from whichever directory it is running in.
