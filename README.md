# deepiri-tombstone

**Deepiri post-training eval harness** — vintage-language pipeline stages orchestrated in Ken Thompson's [B](https://en.wikipedia.org/wiki/B_(programming_language)), talking to local [Ollama](https://ollama.com).

> C's grandparent runs your post-training QA.

## Quick start

```bash
./setup.sh
./deepiri-tombstone doctor
./deepiri-tombstone ping
./deepiri-tombstone eval llama3.2 -j 8
./deepiri-tombstone eval --classic llama3.2   # B keep-alive castle
./deepiri-tombstone dashboard
```

`./setup.sh` installs build deps (including libcurl), compiles the project,
starts **Ollama in Docker**, pulls the default model (`llama3.2`), and runs a
ping smoke test. `doctor` confirms the install is evaluation-ready.

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

See [src/README.md](src/README.md), [docs/MODULES.md](docs/MODULES.md), and
[docs/PERFORMANCE.md](docs/PERFORMANCE.md) (η, cache hit rate, prompts/sec).

## Commands

| Command | Description |
|---------|-------------|
| `ping` | Check Ollama at `DEEPIRI_TOMBSTONE_HOST` (B keep-alive bridge) |
| `models` | List Ollama models (B core) |
| `warm [model]` | Preload model into VRAM (B core) |
| `ask <model> <prompt>` | Single spot-check (B core) |
| `summary` | Print classic-eval running stats |
| `eval [model] [fixture] [-j N]` | Cache-first parallel eval (warm-on-miss, early-stop, SLO, ledger) |
| `eval --classic [model] [fixture]` | B core: keep-alive + shared SHA-256 cache + batch ledger + warm + fail-fast |
| `judge <model> <prompt> [response] [criteria]` | G-Eval LLM-as-a-Judge scoring |
| `mutate <fixture>` | Adversarial prompt mutation |
| `bench <fixture> <model>...` | Multi-model benchmark comparison |
| `synth <seed> [count]` | Synthetic dataset generation |
| `dashboard` | Generate HTML evaluation report |
| `trace [start\|view] [file]` | Span tracing & observability |
| `rag <metric> <question> <answer> [context]` | RAG metrics — pass the retrieved context as the 4th argument |
| `doctor` | Verify toolchain, B bridge, Ollama, fixtures |
| `version` | Print the harness version |
| `help` | Show full usage |

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEEPIRI_TOMBSTONE_MODEL` | `llama3.2` | Default model |
| `DEEPIRI_TOMBSTONE_HOST` | `127.0.0.1:11434` | Ollama host |
| `DEEPIRI_TOMBSTONE_JOBS` | adaptive 4–16 | Parallel workers for `eval` / `runner` / `bench` |
| `DEEPIRI_TOMBSTONE_CACHE_DIR` | `reports/cache` | Shared SHA-256 response cache (B ↔ Python) |
| `DEEPIRI_TOMBSTONE_NO_CACHE` | (unset) | Set to `1` to disable response cache |
| `DEEPIRI_TOMBSTONE_KEEP_ALIVE` | `30m` | Ollama model pin between calls |
| `DEEPIRI_TOMBSTONE_FAIL_FAST` | (unset) | Stop after N failures on hot or classic path |

## Advanced features

### G-Eval (LLM-as-a-Judge)
```bash
./deepiri-tombstone judge llama3.2 "What is 2+2?" response.txt
```
Scores responses on relevance, coherence, helpfulness, harmlessness, factuality, and completeness using a judge model. Returns JSON with per-criterion scores and overall.

### Adversarial mutation
```bash
./deepiri-tombstone mutate fixtures/eval_prompts.txt
```
Generates 8 types of prompt mutations (typos, case attacks, prompt injections, Unicode homoglyphs) for stress-testing LLM robustness.

### Multi-model benchmark
```bash
./deepiri-tombstone bench fixtures/eval_prompts.txt llama3.2 mistral phi
```
Runs the same eval across multiple models, comparing pass rates, latency, and response length.

### Synthetic dataset generation
```bash
./deepiri-tombstone synth fixtures/eval_prompts.txt 10
```
Scales small seed sets into large evaluation datasets using Ollama for semantic variant generation.

### HTML dashboard
```bash
./deepiri-tombstone dashboard
```
Generates a rich HTML report from evaluation results with pass/fail breakdowns and model comparison.

### Span tracing
```bash
./deepiri-tombstone trace start    # outputs trace ID
./deepiri-tombstone trace view reports/trace.json
```
Records timing spans for each pipeline stage with tree visualization.

## License

Apache License 2.0 — Copyright 2026 Deepiri. See [LICENSE](LICENSE).
