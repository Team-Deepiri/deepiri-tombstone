#!/usr/bin/env bash
set -euo pipefail
bash scripts/build_request_fallback.sh llama3.2 hi | grep -q model