#!/usr/bin/env bash
# BCPL fallback: build Ollama /api/generate JSON request
set -euo pipefail
model="${1:-llama3.2}"
prompt="${2:-}"
python3 - "$model" "$prompt" <<'PY'
import json, sys
model, prompt = sys.argv[1], sys.argv[2]
print(json.dumps({"model": model, "prompt": prompt, "stream": False}))
PY
