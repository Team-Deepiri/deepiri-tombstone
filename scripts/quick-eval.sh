#!/usr/bin/env bash
# Run a quick evaluation with a single prompt
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODEL="${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}"
PROMPT="${1:-What is 2+2?}"

echo "Quick eval: model=$MODEL prompt='$PROMPT'"
echo ""

# Tokenize
echo "--- Tokenize ---"
echo "$PROMPT" | bash src/tokenize/fallback.sh

# Build request
echo "--- Request ---"
bash src/request/fallback.sh "$MODEL" "$PROMPT"

# Generate (requires Ollama)
if command -v curl >/dev/null 2>&1; then
  echo "--- Generate ---"
  REQ=$(bash src/request/fallback.sh "$MODEL" "$PROMPT")
  HOST="${DEEPIRI_TOMBSTONE_HOST:-127.0.0.1:11434}"
  RAW=$(curl -sf "http://$HOST/api/generate" -d "$REQ" 2>/dev/null || echo '{"response":"(curl failed — is Ollama running?)"}')
  echo "$RAW" | awk -f src/parse/response.awk
fi

echo "--- Done ---"
