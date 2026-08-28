# DEEPIRI_TOMBSTONE environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEEPIRI_TOMBSTONE_HOST` | `127.0.0.1:11434` | Ollama server address |
| `DEEPIRI_TOMBSTONE_MODEL` | `llama3.2` | Default model for eval |
| `DEEPIRI_TOMBSTONE_JOBS` | adaptive 4–16 | Parallel workers for eval/runner/bench |
| `DEEPIRI_TOMBSTONE_CACHE_DIR` | `reports/cache` | Response cache directory (SHA-256 keys shared B↔Python) |
| `DEEPIRI_TOMBSTONE_NO_CACHE` | — | Set to `1` to disable response cache |
| `DEEPIRI_TOMBSTONE_KEEP_ALIVE` | `30m` | Ollama model pin duration |
| `DEEPIRI_TOMBSTONE_FAIL_FAST` | — | Stop after N failures (hot path + classic B) |
| `DEEPIRI_TOMBSTONE_CMD` | — | Command override for classic B core (ping/ask/eval/…) |
| `DEEPIRI_TOMBSTONE_ARG1` | — | First argument override |
| `DEEPIRI_TOMBSTONE_ARG2` | — | Second argument override |

See also [PERFORMANCE.md](PERFORMANCE.md) for \(\eta\), cache-first, early-stop, and prompts/sec.
