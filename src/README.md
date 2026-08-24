# Source layout (`src/`)

Pipeline code is grouped by **function**, not programming language.

```
src/
  orchestrator/   ping, ask — B orchestrator; classic eval
  bridge/         Ollama HTTP, buffers, fixture I/O — C
  tokenize/       prompt word budget
  parse/          extract model response from JSON
  score/          latency + pass-rate statistics
  audit/          append-only eval ledger
  request/        build /api/generate JSON payload
  transport/      HTTP fallback when bridge fails
  runner/         fast parallel eval (default `eval` path)
  common/         shared helpers (ledger.py, ollama_client.py)
```

Each stage directory contains its implementation plus an optional `fallback.sh`
for hosts missing native compilers (gforth, gfortran, gnucobol, etc.).

Built binaries land in `bin/` (`bin/parse`, `bin/score`, …).

Python stages are installed into `bin/` as standalone copies, so anything they
share is installed beside them: `src/common/ledger.py` and
`src/common/ollama_client.py` become `bin/ledger.py` / `bin/ollama_client.py`,
and each stage resolves imports from whichever directory it is running in.
