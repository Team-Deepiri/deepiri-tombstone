# Architecture

## Pipeline

```mermaid
flowchart TD
    CLI[deepiri-tombstone CLI] --> Orch[src/orchestrator]
    Orch --> Tokenize[src/tokenize]
    Orch --> Bridge[src/bridge]
    Bridge --> Ollama[Ollama localhost:11434]
    Ollama --> Parse[src/parse]
    Parse --> Score[src/score]
    Score --> Audit[src/audit]
    Audit --> Reports[reports/]
```

## Why the bridge is separate

[blang libb](https://github.com/sergev/blang) is freestanding. HTTP and shared buffers live in `src/bridge/`.

## Reports

| File | Stage |
|------|-------|
| `reports/audit.ledger` | audit |
| `reports/stats.dat` | score |
| `reports/summary.txt` | score |
