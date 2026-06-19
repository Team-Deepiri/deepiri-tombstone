# Architecture

## Pipeline

```mermaid
flowchart TD
    CLI[deepiri-tombstone CLI wrapper] --> B[b/main.b orchestrator]
    B --> Forth[forth/tokenize.fs]
    B --> CBridge[c/ollama_bridge.c]
    CBridge --> Ollama[Ollama localhost:11434]
    Ollama --> AWK[awk/parse_response.awk]
    AWK --> Fortran[fortran/score.f]
    Fortran --> COBOL[cobol/audit.cob]
    COBOL --> Reports[reports/]
```

## Why B needs a C bridge

[blang libb](https://github.com/sergev/blang) is freestanding — `read`, `write`, `printf` only. HTTP and `system()` live in `libdeepiri_tombstone.a`.

## Reports

| File | Producer |
|------|----------|
| `reports/audit.ledger` | COBOL |
| `reports/stats.dat` | Fortran |
| `reports/summary.txt` | Fortran |
