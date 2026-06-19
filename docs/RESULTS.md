# Results format

## Audit ledger (`reports/audit.ledger`)

Fixed-width format with columns:

| Column | Width | Description |
|--------|-------|-------------|
| RUN-ID | 20 | Unique run identifier |
| MODEL | 40 | Model name |
| PROMPT | 200 | Prompt text |
| RESPONSE | 500 | Model response |
| LATENCY-MS | 10 | Latency in milliseconds |
| STATUS | 4 | PASS or FAIL |

## Stats (`reports/stats.dat`)

Space-separated: `<latency_ms> <response_length> <pass_flag>`

One record per eval run.

## Summary (`reports/summary.txt`)

Key-value format:

```
RUNS <n>
MEAN_LATENCY_MS <float>
MEAN_LENGTH <float>
PASS_RATE_PCT <float>
```

## Interpreting results

- **PASS**: Response contains the keyword (case-insensitive) and is non-empty
- **FAIL**: Keyword not found or response is empty
- **Latency**: End-to-end time including curl, parse, and scoring
- **Pass rate**: Percentage of prompts that passed keyword check
