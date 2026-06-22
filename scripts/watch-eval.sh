#!/usr/bin/env bash
# Enhanced live eval progress watcher with trend overlay
set -euo pipefail

LEDGER="${1:-reports/audit.ledger}"
SUMMARY="${2:-reports/summary.txt}"
CAT_STATS="${3:-reports/category_stats.txt}"
TREND="${4:-reports/trend.dat}"
TOTAL="${5:-}"
INTERVAL="${6:-2}"

if [[ ! -f "$LEDGER" ]]; then
  echo "Waiting for $LEDGER to appear..."
fi

echo "Watching $LEDGER (refresh every ${INTERVAL}s)..."
while true; do
  clear 2>/dev/null || true
  echo "╔══════════════════════════════════════════════╗"
  echo "║       deepiri-tombstone Eval Monitor         ║"
  echo "╚══════════════════════════════════════════════╝"
  echo "Time: $(date '+%H:%M:%S')"
  echo ""

  if [[ -f "$LEDGER" ]]; then
    count=$(wc -l < "$LEDGER")
    pass=$(grep -c "|PASS" "$LEDGER" 2>/dev/null || echo 0)
    fail=$(grep -c "|FAIL" "$LEDGER" 2>/dev/null || echo 0)
    rate=$((count > 0 ? (pass * 100) / count : 0))

    echo " Progress:"
    echo "   Records: $count"
    [[ -n "$TOTAL" ]] && echo "   Complete: $((count * 100 / TOTAL))%"
    echo "   Pass:    $pass"
    echo "   Fail:    $fail"
    echo "   Rate:    ${rate}%"

    # Progress bar
    if [[ -n "$TOTAL" && "$TOTAL" -gt 0 ]]; then
      bar_width=40
      filled=$((count * bar_width / TOTAL))
      bar=""
      for ((i=0; i<bar_width; i++)); do
        [[ "$i" -lt "$filled" ]] && bar="${bar}█" || bar="${bar}░"
      done
      echo "   [$bar]"
    fi
    echo ""
  else
    echo " No records yet"
    echo ""
  fi

  if [[ -f "$SUMMARY" ]]; then
    echo " Performance:"
    while IFS=' ' read -r key val; do
      case "$key" in
        MEAN_LATENCY_MS) echo "   Avg Latency: ${val}ms" ;;
        PASS_RATE_PCT)   echo "   Pass Rate:   ${val}%" ;;
        QUALITY_SCORE)   echo "   Quality:     ${val}" ;;
        P95_LATENCY_MS)  echo "   P95 Latency: ${val}ms" ;;
        RUNS)            echo "   Stats Runs:  ${val}" ;;
      esac
    done < "$SUMMARY"
    echo ""
  fi

  if [[ -f "$CAT_STATS" ]]; then
    echo " Categories:"
    while read -r cat rate total; do
      [[ "$cat" == "CATEGORY" ]] && continue
      echo "   $cat: ${rate}% ($total)"
    done < "$CAT_STATS" 2>/dev/null | head -10
    echo ""
  fi

  if [[ -f "$TREND" ]]; then
    echo " Trend (last 5):"
    tail -5 "$TREND" 2>/dev/null | while read -r ts lat pr len qual; do
      echo "   $ts  ${pr}%  ${lat}ms"
    done
    echo ""
  fi

  sleep "$INTERVAL"
done
