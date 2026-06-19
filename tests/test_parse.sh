#!/usr/bin/env bash
set -euo pipefail
echo '{"response":"ok"}' | awk -f awk/parse_response.awk | grep -q ok