# deepiri-tombstone

**Deepiri post-training eval harness** — vintage-language pipeline stages orchestrated in Ken Thompson's [B](https://en.wikipedia.org/wiki/B_(programming_language)), talking to local [Ollama](https://ollama.com).

> C's grandparent runs your post-training QA.

## Quick start

```bash
./setup.sh
./deepiri-tombstone ping
./deepiri-tombstone ask llama3.2 "Say hello in one word"
./deepiri-tombstone eval llama3.2
```

`./setup.sh` installs build deps, compiles the project, starts **Ollama in Docker**, pulls the default model (`llama3.2`), and runs a ping smoke test.

## Source layout

Code lives under `src/` by **pipeline stage** (not by language):

| Stage | Path |
|-------|------|
| Orchestrator | `src/orchestrator/` |
| Ollama bridge | `src/bridge/` |
| Tokenize | `src/tokenize/` |
| Parse | `src/parse/` |
| Score | `src/score/` |
| Audit | `src/audit/` |
| Request builder | `src/request/` |
| HTTP transport | `src/transport/` |

See [src/README.md](src/README.md) and [docs/MODULES.md](docs/MODULES.md).

## Commands

| Command | Description |
|---------|-------------|
| `ping` | Check Ollama at `DEEPIRI_TOMBSTONE_HOST` |
| `ask <model> <prompt>` | Single spot-check |
| `eval [model] [fixture]` | Run fixture suite |

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEEPIRI_TOMBSTONE_MODEL` | `llama3.2` | Default model |
| `DEEPIRI_TOMBSTONE_HOST` | `127.0.0.1:11434` | Ollama host |

## License

Apache License 2.0 — Copyright 2026 Deepiri. See [LICENSE](LICENSE).
