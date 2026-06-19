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
b/          orchestrator (B language)
c/          C bridge library (libdeepiri_tombstone.a)
cobol/      append-only audit ledger
fortran/    scoring / running statistics
awk/        JSON response parser
perl/       HTTP fallback (curl + JSON parse)
forth/      prompt tokenizer / budget check
bcpl/       JSON request builder
scripts/    dependency install, model pull, validation
fixtures/   eval prompts with optional keyword pass criteria
docs/       documentation
```

### License

MIT — see LICENSE.
