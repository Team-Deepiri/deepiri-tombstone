#!/usr/bin/env bash
# Quick test individual pipeline components
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

case "${1:-help}" in
  parse)
    echo '{"response":"hello world","done":true}' | awk -f src/parse/response.awk
    ;;
  tokenize)
    echo "${2:-hello world}" | gforth -e "include src/tokenize/tokenize.fs" 2>/dev/null \
      || echo "${2:-hello world}" | bash src/tokenize/fallback.sh
    ;;
  score)
    echo "test response" > /tmp/dt_quick_response.txt
    if command -v gfortran >/dev/null 2>&1; then
      gfortran -o /tmp/dt_quick_score src/score/score.f 2>/dev/null
      /tmp/dt_quick_score "${2:-500}" /tmp/dt_quick_response.txt
    else
      bash src/score/fallback.sh "${2:-500}" /tmp/dt_quick_response.txt
    fi
    ;;
  audit)
    echo "${2:-run-001|llama3.2|test prompt|test response|1234|PASS}" \
      | bash src/audit/fallback.sh
    ;;
  build-request)
    bash src/request/fallback.sh "${2:-llama3.2}" "${3:-hello}"
    ;;
  http)
    perl src/transport/http_fallback.pl "${2:-llama3.2}" "${3:-hello}"
    ;;
  all)
    $0 parse
    $0 tokenize "hello world"
    $0 score 500
    $0 audit "run-001|llama3.2|test prompt|ok|1234|PASS"
    $0 build-request llama3.2 "hello"
    ;;
  help|*)
    echo "Usage: $0 <component> [args]"
    echo "Components: parse, tokenize, score, audit, build-request, http, all"
    ;;
esac
