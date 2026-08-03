#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc"
  else
    echo "  FAIL: $desc (expected '$expected', got '$actual')"
    errors=$((errors + 1))
  fi
}

echo "=== Shared ledger parser tests ==="

LEDGER=$(mktemp)
cat > "$LEDGER" <<'LINES'
run-001|llama3.2|plain prompt|plain response|1234|PASS

run-002|llama3.2|Compare A | B and C|the response|5678|FAIL
run-003|mistral|a|b|9|PASS
too|few|fields
LINES

read -r n_entries clean_status pipe_prompt pipe_resp pipe_lat pipe_status short_run <<EOF
$(python3 - "$LEDGER" "$ROOT" <<'PY'
import sys, os
sys.path.insert(0, os.path.join(sys.argv[2], "src", "common"))
import ledger
e = ledger.load_ledger(sys.argv[1])
p = e[1]
print(len(e), e[0]["status"], p["prompt"].replace(" ", "_"),
      p["response"].replace(" ", "_"), p["latency_ms"], p["status"], e[2]["run_id"])
PY
)
EOF

check "blank and malformed lines are skipped" "3" "$n_entries"
check "well-formed row parses status" "PASS" "$clean_status"
check "prompt containing a pipe is preserved" "Compare_A_|_B_and_C" "$pipe_prompt"
check "response is not absorbed by the prompt" "the_response" "$pipe_resp"
check "latency survives a piped prompt" "5678" "$pipe_lat"
check "status survives a piped prompt" "FAIL" "$pipe_status"
check "later rows still parse" "run-003" "$short_run"

missing=$(python3 -c "
import sys, os
sys.path.insert(0, os.path.join('$ROOT', 'src', 'common'))
import ledger
print(len(ledger.load_ledger('/tmp/deepiri_no_such_ledger.dat')))
")
check "missing ledger yields no entries" "0" "$missing"

STATS=$(mktemp)
printf '1200 45 1\n900 30 0\nbad\n' > "$STATS"
n_stats=$(python3 -c "
import sys, os
sys.path.insert(0, os.path.join('$ROOT', 'src', 'common'))
import ledger
print(len(ledger.load_stats('$STATS')))
")
check "stats file skips malformed rows" "2" "$n_stats"

rm -f "$LEDGER" "$STATS"

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL LEDGER TESTS PASSED"
else echo "$errors LEDGER TEST(S) FAILED"; fi
exit "$errors"
