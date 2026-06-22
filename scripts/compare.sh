#!/usr/bin/env bash
# Enhanced audit ledger comparison with rich stats
set -euo pipefail

ledger1="${1:-reports/audit.ledger}"
ledger2="${2:-reports/audit.ledger}"
format="${3:-text}"  # text, markdown, json

if [[ ! -f "$ledger1" ]]; then echo "File not found: $ledger1"; exit 1; fi
if [[ ! -f "$ledger2" ]]; then echo "File not found: $ledger2"; exit 1; fi

stats() {
  local ledger="$1"
  local total pass fail
  total=$(wc -l < "$ledger")
  pass=$(grep -c "|PASS" "$ledger" 2>/dev/null || echo 0)
  fail=$(grep -c "|FAIL" "$ledger" 2>/dev/null || echo 0)
  echo "$total $pass $fail"
}

read -r t1 p1 f1 <<< "$(stats "$ledger1")"
read -r t2 p2 f2 <<< "$(stats "$ledger2")"

r1=0; [[ "$t1" -gt 0 ]] && r1=$((p1 * 100 / t1))
r2=0; [[ "$t2" -gt 0 ]] && r2=$((p2 * 100 / t2))

case "$format" in
  json)
    echo '{'
    echo '  "ledger1": "'"$ledger1"'",'
    echo '  "ledger2": "'"$ledger2"'",'
    echo '  "records1": '"$t1"','
    echo '  "records2": '"$t2"','
    echo '  "pass1": '"$p1"','
    echo '  "pass2": '"$p2"','
    echo '  "fail1": '"$f1"','
    echo '  "fail2": '"$f2"','
    echo '  "rate1": '"$r1"','
    echo '  "rate2": '"$r2"''
    echo '}'
    ;;
  markdown|md)
    echo "## Comparison Report"
    echo ""
    echo "| Metric | $ledger1 | $ledger2 | Change |"
    echo "|--------|----------|----------|--------|"
    echo "| Records | $t1 | $t2 | $((t2 - t1)) |"
    echo "| Pass | $p1 | $p2 | $((p2 - p1)) |"
    echo "| Fail | $f1 | $f2 | $((f2 - f1)) |"
    echo "| Pass Rate | ${r1}% | ${r2}% | $((r2 - r1))% |"
    echo ""
    if [[ "$ledger1" != "$ledger2" ]]; then
      diff_lines=$(diff --new-line-format="" --unchanged-line-format="" \
        <(sort "$ledger1") <(sort "$ledger2") 2>/dev/null | wc -l || echo 0)
      echo "**Unique records:** $diff_lines"
    fi
    ;;
  *)
    echo "╔══════════════════════════════════════════════╗"
    echo "║        deepiri-tombstone Comparison          ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "1: $ledger1 ($t1 records)"
    echo "2: $ledger2 ($t2 records)"
    echo ""
    printf "%-20s %8s %8s %8s\n" "Metric" "Run 1" "Run 2" "Δ"
    echo "-------------------- -------- -------- --------"
    printf "%-20s %8d %8d %+8d\n" "Records" "$t1" "$t2" "$((t2 - t1))"
    printf "%-20s %8d %8d %+8d\n" "Pass" "$p1" "$p2" "$((p2 - p1))"
    printf "%-20s %8d %8d %+8d\n" "Fail" "$f1" "$f2" "$((f2 - f1))"
    printf "%-20s %8d%% %8d%% %+8d%%\n" "Pass Rate" "$r1" "$r2" "$((r2 - r1))"
    echo ""

    if [[ "$t1" -gt 0 && "$t2" -gt 0 ]]; then
      if (( r2 > r1 )); then
        echo "Status: IMPROVEMENT (+$((r2 - r1))%)"
      elif (( r2 < r1 )); then
        echo "Status: REGRESSION ($((r2 - r1))%)"
      else
        echo "Status: STABLE"
      fi
    fi

    if [[ "$ledger1" != "$ledger2" ]]; then
      echo ""
      echo "=== Unique records ==="
      diff --new-line-format="%L" --unchanged-line-format="" \
        <(sort "$ledger1") <(sort "$ledger2") 2>/dev/null | head -20 || true
      diff_count=$(diff --new-line-format="%L" --unchanged-line-format="" \
        <(sort "$ledger1") <(sort "$ledger2") 2>/dev/null | wc -l || echo 0)
      [[ "$diff_count" -gt 20 ]] && echo "... and $((diff_count - 20)) more"
    fi
    ;;
esac
