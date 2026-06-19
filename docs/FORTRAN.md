# Fortran scorer

File: `fortran/score.f`
Binary: `bin/score`
Fallback: `scripts/score_fallback.sh`

Usage: `score <latency_ms> <response_file>`

Appends a record to `reports/stats.dat` and writes `reports/summary.txt`
with running means and pass rate.

Output: `SCORE latency=<n> length=<n> pass=<0|1>`
