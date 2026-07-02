# Pipeline

```
User input → B orchestrator → Forth (token count check)
                             → C bridge → curl → Ollama API
                             → AWK (JSON parse)
                             → Fortran (score & running stats)
                             → COBOL (audit ledger append)
```

## Data flow

1. `deepiri-tombstone` CLI parses command (ping/ask/eval)
2. B orchestrator (`src/orchestrator/main.b`) dispatches to `cmd_ping`, `cmd_ask`, or `cmd_eval`
3. For `cmd_eval`:
   - Load fixture file → iterate prompt/keyword pairs
   - Tokenize prompt (Forth) → word count + 512-budget check
   - Send to Ollama (C bridge + curl) → raw JSON response
   - Parse JSON (AWK) → extract `"response"` field
   - Check keyword match (B, case-insensitive)
   - Score (Fortran) → running latency/length/pass-rate stats
   - Audit (COBOL) → append fixed-width record to ledger

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | AWK parse: no JSON response field |
| 3 | AWK parse: unterminated string |

## File formats

### `fixtures/eval_prompts.txt`
```
PROMPT|KEYWORD
What is 2+2?|4
Hello|hello
```

### `reports/audit.ledger`
Fixed-width columns: RUN-ID, MODEL, PROMPT, RESPONSE, LATENCY-MS, STATUS

### `reports/stats.dat`
Space-separated: latency_ms response_length pass_flag

### `reports/summary.txt`
Key-value: RUNS, MEAN_LATENCY_MS, MEAN_LENGTH, PASS_RATE_PCT

---

## Advanced Evaluation Stages (v2.0)

The following advanced stages extend deepiri-tombstone into a full evaluation harness:

### G-Eval Judge (`src/judge/`)
LLM-as-a-Judge scoring using a separate judge model. Evaluates response quality on multiple criteria (relevance, coherence, helpfulness, harmlessness, factuality, completeness).

```
deepiri-tombstone judge <judge-model> <prompt> [response-file] [criteria-file]
```

- **Primary**: Python (`judge.py`) — calls Ollama judge, returns JSON scorecard
- **Fallback**: Bash (`fallback.sh`) — heuristic length-based scoring
- **Exit**: 0 if overall >= 3.0, 1 otherwise

### Adversarial Mutation Engine (`src/mutate/`)
Generates prompt variants to stress-test LLM robustness. 8 mutation types: typo swap/delete/repeat, case upper/alternating, prompt injection, Unicode homoglyphs, whitespace injection.

```
deepiri-tombstone mutate <fixture> [-n mutations] [-o output]
```

- **Primary**: Python (`mutate.py`) — stochastic mutation engine
- **Fallback**: Bash (`fallback.sh`) — case + instruction injection

### Multi-Model Benchmark (`src/bench/`)
Runs the same eval fixture across multiple Ollama models and compares pass rates, latency, and response length.

```
deepiri-tombstone bench <fixture> <model1> [model2 ...]
```

- **Primary**: Python (`bench.py`) — comparison table + JSON output
- **Fallback**: Bash (`fallback.sh`) — sequential model eval

### Synthetic Dataset Generator (`src/synth/`)
Expands small seed prompt sets into larger evaluation datasets using Ollama for semantic variant generation.

```
deepiri-tombstone synth <seed-file> [variants-per-seed] [--rule-based]
```

- **Primary**: Python (`synth.py`) — LLM-based variant generation with rule-based fallback
- **Fallback**: Bash (`fallback.sh`) — template-based expansion

### HTML Dashboard (`src/report/`)
Generates rich HTML evaluation reports from stats.dat and audit.ledger, with pass/fail breakdowns, latency metrics, and model comparison tables.

```
deepiri-tombstone dashboard [-o reports/dashboard.html]
```

- **Implementation**: Python (`dashboard.py`) — generates self-contained HTML

### Span Tracing (`src/trace/`)
Observability system that records timing spans for pipeline stages. Supports tree visualization of execution traces.

```
deepiri-tombstone trace start       # start new trace → prints trace ID
deepiri-tombstone trace view <file> # view trace tree
```

- **Implementation**: Python (`trace.py`) — span recording + tree printer

## New fixture files

| File | Purpose |
|------|---------|
| `fixtures/judge_criteria.txt` | G-Eval scoring criteria (6 dimensions) |
| `fixtures/adversarial_prompts.txt` | 15 stress-test prompts for robustness testing |

## Architecture diagram (updated)

```
User CLI (deepiri-tombstone)
  │
  ├── ping       → B orchestrator → C bridge → Ollama
  ├── ask        → B orchestrator → C bridge → Ollama → AWK → Fortran → COBOL
  ├── eval       → B orchestrator → Forth → C bridge → Ollama → AWK → B → Fortran → COBOL
  │
  ├── judge      → G-Eval (Python) → Ollama judge → JSON scorecard
  ├── mutate     → Mutation engine (Python) → mutated fixture
  ├── bench      → Benchmark (Python) → multi-model comparison
  ├── synth      → Dataset generator (Python) → expanded fixture
  ├── dashboard  → Report generator (Python) → HTML dashboard
  └── trace      → Span tracer (Python) → trace tree

```
