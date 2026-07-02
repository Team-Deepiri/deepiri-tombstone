#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RAG="$ROOT/src/rag/fallback.sh"
RAG_PY="$ROOT/src/rag/rag.py"
errors=0

echo "=== RAG tests ==="

# Python syntax check
if python3 -c "import py_compile; py_compile.compile('$RAG_PY', doraise=True)" 2>/dev/null; then
  echo "  PASS: rag.py syntax OK"
else
  echo "  FAIL: rag.py syntax error"
  errors=$((errors + 1))
fi

# Test missing args
result=$(bash "$RAG" 2>&1 || true)
if echo "$result" | grep -qi "usage"; then
  echo "  PASS: missing args shows usage"
else
  echo "  FAIL: missing args should show usage (got: $result)"
  errors=$((errors + 1))
fi

# Test faithfulness metric
result=$(bash "$RAG" "faithfulness" "What is Paris?" "Paris is the capital." 2>/dev/null || true)
note=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('note',''))" 2>/dev/null || echo "err")
if [[ "$note" == "heuristic-fallback" ]]; then
  echo "  PASS: faithfulness metric"
else
  echo "  FAIL: faithfulness metric (result=$result)"
  errors=$((errors + 1))
fi

# Test relevance metric
result=$(bash "$RAG" "relevance" "What is Paris?" "Paris is the capital." 2>/dev/null || true)
note=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('note',''))" 2>/dev/null || echo "err")
if [[ "$note" == "heuristic-fallback" ]]; then
  echo "  PASS: relevance metric"
else
  echo "  FAIL: relevance metric"
  errors=$((errors + 1))
fi

# Test recall metric
result=$(bash "$RAG" "recall" "What is Paris?" "Paris is the capital." "Paris is in France." 2>/dev/null || true)
recall=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('context_recall',0))" 2>/dev/null || echo "err")
if [[ "$recall" =~ ^[0-9] ]]; then
  echo "  PASS: recall metric (context_recall=$recall)"
else
  echo "  FAIL: recall metric"
  errors=$((errors + 1))
fi

# Test all metrics with context
result=$(bash "$RAG" "all" "What is Python?" "Python is a language." "Python is a high-level language." 2>/dev/null || true)
note=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('note',''))" 2>/dev/null || echo "err")
if [[ "$note" == "heuristic-fallback" ]]; then
  echo "  PASS: all metrics"
else
  echo "  FAIL: all metrics"
  errors=$((errors + 1))
fi

# Test empty answer - should score 0.00
result=$(bash "$RAG" "faithfulness" "question" "" 2>/dev/null || true)
if echo "$result" | grep -q '"faithfulness":0'; then
  echo "  PASS: empty answer gives faithfulness=0"
else
  echo "  FAIL: empty answer should give faithfulness=0 (got: $result)"
  errors=$((errors + 1))
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL RAG TESTS PASSED"
else echo "$errors RAG TEST(S) FAILED"; fi
exit "$errors"
