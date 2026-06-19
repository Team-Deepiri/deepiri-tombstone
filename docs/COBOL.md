# COBOL audit

File: `src/audit/ledger.cob`
Binary: `bin/audit`
Fallback: `src/audit/fallback.sh`

Reads pipe-delimited fields from stdin and appends a fixed-width record
to `reports/audit.ledger`.

Input format: `RUN_ID|MODEL|PROMPT|RESPONSE|LATENCY_MS|STATUS`

Output: `AUDIT OK` on success, `AUDIT FAIL` on error.
