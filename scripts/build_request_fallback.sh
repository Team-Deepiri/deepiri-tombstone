#!/usr/bin/env bash
# BCPL fallback: build Ollama /api/generate JSON request
set -euo pipefail

model="${1:-${DEEPIRI_TOMBSTONE_MODEL:-llama3.2}}"
prompt="${2:-}"

if [[ -z "$prompt" ]]; then
  echo '{"error":"prompt is required"}'
  exit 1
fi

python3 - "$model" "$prompt" <<'PY'
import json, sys
model, prompt = sys.argv[1], sys.argv[2]
# Validate prompt is not empty after stripping
if not prompt.strip():
    print(json.dumps({"error": "empty prompt"}))
    sys.exit(1)
print(json.dumps({"model": model, "prompt": prompt, "stream": False}))
PY
