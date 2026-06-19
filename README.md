# deepiri-tombstone

**Deepiri post-training eval harness** — orchestrated in Ken Thompson's [B language](https://en.wikipedia.org/wiki/B_(programming_language)), with pipeline stages in BCPL, Forth, Fortran, COBOL, AWK, and Perl talking to local [Ollama](https://ollama.com).

> C's grandparent runs your post-training QA.

## Quick start

```bash
./scripts/install-deps.sh
make
./scripts/pull-model.sh
./deepiri-tombstone ping
./deepiri-tombstone ask llama3.2 "Say hello in one word"
./deepiri-tombstone eval llama3.2
```

## Commands

| Command | Description |
|---------|-------------|
| `ping` | Check Ollama at `DEEPIRI_TOMBSTONE_HOST` (default `127.0.0.1:11434`) |
| `ask <model> <prompt>` | Single spot-check after training |
| `eval [model] [fixture]` | Run fixture suite (default `fixtures/eval_prompts.txt`) |

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEEPIRI_TOMBSTONE_MODEL` | `llama3.2` | Default model |
| `DEEPIRI_TOMBSTONE_HOST` | `127.0.0.1:11434` | Ollama host |

Pair with [deepiri-gpu-utils](https://github.com/Team-Deepiri/deepiri-gpu-utils) for hardware-aware model tier picks:

```bash
deepiri-gpu ollama recommend --json
```

## Architecture

```
B orchestrator → Forth (tokenize) → C bridge (Ollama HTTP)
              → AWK (parse JSON) → Fortran (score) → COBOL (audit ledger)
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/LANGUAGES.md](docs/LANGUAGES.md).

## License

MIT — Copyright (c) 2026 Deepiri
