#!/usr/bin/env bash
set -euo pipefail
echo "one two three" | bash scripts/tokenize_fallback.sh | grep -q WORDS