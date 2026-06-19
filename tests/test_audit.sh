#!/usr/bin/env bash
set -euo pipefail
echo "run-1|m|p|r|10|PASS" | bash scripts/audit_fallback.sh | grep -q "AUDIT OK"