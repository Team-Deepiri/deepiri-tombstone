# Fortran scorer

File: `src/score/score.f`
Binary: `bin/score`
Fallback: `src/score/fallback.sh`

Usage: `score <latency_ms> <response_file>`

Appends a record to `reports/stats.dat` and writes `reports/summary.txt`
with running means and pass rate.

Output: `SCORE latency=<n> length=<n> pass=<0|1>`
