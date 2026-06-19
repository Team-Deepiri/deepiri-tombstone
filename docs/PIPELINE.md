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
