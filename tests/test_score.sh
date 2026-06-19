#!/usr/bin/env bash
set -euo pipefail
echo hi > /tmp/dt_score_test.txt
bash scripts/score_fallback.sh 100 /tmp/dt_score_test.txt | grep -q SCORE