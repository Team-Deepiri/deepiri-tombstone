#!/usr/bin/env bash
# Generate a rich report from the audit ledger and stats
# Usage: scripts/report.sh [format] [ledger_file]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FORMAT="${1:-markdown}"
LEDGER="${2:-reports/audit.ledger}"
SUMMARY="${3:-reports/summary.txt}"
CAT_STATS="${4:-reports/category_stats.txt}"
TREND="${5:-reports/trend.dat}"

if [[ ! -f "$LEDGER" ]]; then
  echo "Audit ledger not found: $LEDGER" >&2
  echo "Run an eval first: deepiri-tombstone eval" >&2
  exit 1
fi

total_records=$(wc -l < "$LEDGER")
pass_count=$(grep -c "|PASS" "$LEDGER" 2>/dev/null || echo 0)
fail_count=$(grep -c "|FAIL" "$LEDGER" 2>/dev/null || echo 0)
pass_rate=$((total_records > 0 ? (pass_count * 100) / total_records : 0))

generate_markdown() {
  echo "# deepiri-tombstone Evaluation Report"
  echo ""
  echo "**Generated:** $(date)"
  echo "**Ledger:** $LEDGER"
  echo ""
  echo "## Summary"
  echo ""
  echo "| Metric | Value |"
  echo "|--------|-------|"
  echo "| Total Records | $total_records |"
  echo "| Pass | $pass_count |"
  echo "| Fail | $fail_count |"
  echo "| Pass Rate | ${pass_rate}% |"
  echo ""

  if [[ -f "$SUMMARY" ]]; then
    echo "## Performance"
    echo ""
    echo '```'
    cat "$SUMMARY"
    echo '```'
    echo ""
  fi

  if [[ -f "$CAT_STATS" ]]; then
    echo "## Category Breakdown"
    echo ""
    echo "| Category | Pass Rate | Total |"
    echo "|----------|-----------|-------|"
    while read -r cat rate total; do
      [[ "$cat" == "CATEGORY" ]] && continue
      echo "| $cat | ${rate}% | $total |"
    done < "$CAT_STATS"
    echo ""
  fi

  if [[ -f "$TREND" ]]; then
    echo "## Trend (Last 10 Runs)"
    echo ""
    echo "| Date | Latency (ms) | Pass Rate (%) | Length | Quality |"
    echo "|------|-------------|--------------|--------|---------|"
    tail -10 "$TREND" | while read -r ts lat pr len qual; do
      echo "| $ts | $lat | ${pr:-0} | $len | ${qual:-0} |"
    done
    echo ""
  fi

  echo "## Per-Prompt Results"
  echo ""
  echo "| # | Run ID | Model | Prompt | Status | Latency |"
  echo "|---|--------|-------|--------|--------|---------|"
  i=0
  while IFS='|' read -r runid model prompt response latency status; do
    [[ -z "$runid" || "$runid" =~ ^[[:space:]]*# ]] && continue
    i=$((i + 1))
    short="${prompt:0:60}"
    echo "| $i | $runid | $model | $short... | $status | ${latency}ms |"
  done < "$LEDGER"
  echo ""
}

generate_html() {
  echo "<!DOCTYPE html>"
  echo "<html><head><meta charset='utf-8'>"
  echo "<title>deepiri-tombstone Eval Report</title>"
  echo "<style>"
  echo "body{font-family:monospace;max-width:900px;margin:40px auto;padding:0 20px}"
  echo "h1{color:#333;border-bottom:2px solid #ddd}"
  echo "table{border-collapse:collapse;width:100%;margin:20px 0}"
  echo "th,td{border:1px solid #ddd;padding:8px;text-align:left}"
  echo "th{background:#f5f5f5}"
  echo ".pass{color:green;font-weight:bold}"
  echo ".fail{color:red;font-weight:bold}"
  echo "pre{background:#f8f8f8;padding:10px;border-radius:4px}"
  echo "</style></head><body>"
  echo "<h1>deepiri-tombstone Evaluation Report</h1>"
  echo "<p><strong>Generated:</strong> $(date)</p>"
  echo "<p><strong>Ledger:</strong> $LEDGER</p>"
  echo ""
  echo "<h2>Summary</h2>"
  echo "<table><tr><th>Metric</th><th>Value</th></tr>"
  echo "<tr><td>Total Records</td><td>$total_records</td></tr>"
  echo "<tr><td>Pass</td><td class='pass'>$pass_count</td></tr>"
  echo "<tr><td>Fail</td><td class='fail'>$fail_count</td></tr>"
  echo "<tr><td>Pass Rate</td><td>${pass_rate}%</td></tr>"
  echo "</table>"

  if [[ -f "$SUMMARY" ]]; then
    echo "<h2>Performance</h2><pre>"
    cat "$SUMMARY" | html_escape
    echo "</pre>"
  fi

  echo "<h2>Per-Prompt Results</h2>"
  echo "<table><tr><th>#</th><th>Model</th><th>Prompt</th><th>Status</th><th>Latency</th></tr>"
  i=0
  while IFS='|' read -r runid model prompt response latency status; do
    [[ -z "$runid" || "$runid" =~ ^[[:space:]]*# ]] && continue
    i=$((i + 1))
    short="${prompt:0:60}"
    cls="pass"
    [[ "$status" == "FAIL" ]] && cls="fail"
    echo "<tr><td>$i</td><td>$model</td><td>$short...</td><td class='$cls'>$status</td><td>${latency}ms</td></tr>"
  done < "$LEDGER"
  echo "</table>"
  echo "</body></html>"
}

html_escape() {
  sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

case "$FORMAT" in
  markdown|md)
    generate_markdown
    ;;
  html)
    generate_html
    ;;
  text)
    echo "=== deepiri-tombstone Evaluation Report ==="
    echo "Generated: $(date)"
    echo "Ledger: $LEDGER"
    echo ""
    echo "Records: $total_records | Pass: $pass_count | Fail: $fail_count | Rate: ${pass_rate}%"
    echo ""
    if [[ -f "$SUMMARY" ]]; then
      echo "--- Performance ---"
      cat "$SUMMARY"
      echo ""
    fi
    echo "--- Audit ledger ---"
    cat "$LEDGER"
    ;;
  *)
    echo "Usage: $0 [markdown|html|text] [ledger_file]" >&2
    exit 1
    ;;
esac
