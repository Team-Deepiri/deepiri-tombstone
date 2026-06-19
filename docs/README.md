# deepiri-tombstone

Post-training evaluation toolchain for Ollama models, built by Team Deepiri.

### Prerequisites

- Linux (x86_64, aarch64, riscv64)
- [blang](https://github.com/sergev/blang) — B language compiler
- [Ollama](https://ollama.com) — local LLM runtime
- gforth, gnucobol, gfortran, awk, perl, make, clang

### Quick start

```bash
./scripts/install-deps.sh
./scripts/pull-model.sh
make
./deepiri-tombstone ping
./deepiri-tombstone ask llama3.2 "What is 2+2?"
./deepiri-tombstone eval
```

### Architecture

```
src/orchestrator/   CLI and eval loop
src/bridge/         Ollama HTTP bridge
src/tokenize/       prompt word budget
src/parse/          JSON response extraction
src/score/          latency and pass-rate stats
src/audit/          append-only eval ledger
src/request/        generate API JSON builder
src/transport/      HTTP fallback client
scripts/            dependency install, model pull, validation
fixtures/           eval prompts with optional keyword pass criteria
docs/               documentation
```

See [MODULES.md](MODULES.md) and [../src/README.md](../src/README.md).

### License

Apache License 2.0 — see [LICENSE](../LICENSE).
