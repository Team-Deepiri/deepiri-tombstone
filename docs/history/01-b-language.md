# B orchestrator

Ken Thompson's B drives the **classic** core: `ping`, `ask`, `eval`, `models`,
`warm`, and `summary`.

## What makes it effective (not ceremonial)

The C bridge (`src/bridge/ollama_bridge.c`) is the muscle:

| Old (hut) | New (castle) |
|-----------|--------------|
| `system("curl …")` per prompt | Process-lifetime **libcurl keep-alive** |
| Spawn AWK to parse JSON | **`parse_response_json` in-process** |
| Spawn Forth tokenize | **In-process word budget** |
| Spawn COBOL every row | **`ledger_queue` + `ledger_flush` batch** |
| Cold first token every run | **`ollama_warm` before eval** |
| No memory of prior answers | **Response cache** (`reports/cache/`) |
| Silent sequential slog | Progress `[i/n]`, pass-rate, **fail-fast** |

B still owns control flow, keyword checks, relevance, and the ritual of a
vintage-language harness. The bridge removes every fork that was not the model.

## Commands (via `deepiri-tombstone` → core)

```
ping
models
warm [model]
ask <model> <prompt>
eval --classic [model] [fixture]   # or DEEPIRI_TOMBSTONE_CMD=eval
summary
```

## Environment

| Variable | Effect |
|----------|--------|
| `DEEPIRI_TOMBSTONE_FAIL_FAST` | Stop classic eval after N failures |
| `DEEPIRI_TOMBSTONE_NO_CACHE` | Disable response cache |
| `DEEPIRI_TOMBSTONE_CACHE_DIR` | Cache directory (default `reports/cache`) |
| `DEEPIRI_TOMBSTONE_MODEL` | Default model |
| `DEEPIRI_TOMBSTONE_HOST` | Ollama `host:port` |

## Sources

- `src/orchestrator/util.b` — strings / itoa helpers
- `src/orchestrator/cli.b` — command implementations
- `src/orchestrator/main.b` — dispatch
- `src/bridge/ollama_bridge.c` — keep-alive HTTP + cache + stats + ledger
