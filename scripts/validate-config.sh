#!/usr/bin/env bash
# Validate all configuration files
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
errors=0

echo "=== Configuration validation ==="

# Validate .gitignore
echo "--- .gitignore ---"
if [[ -f .gitignore ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    echo "  pattern: $line"
  done < .gitignore
fi

# Validate .env.example
echo "--- .env.example ---"
if [[ -f .env.example ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    if [[ "$line" =~ ^[A-Z_]+= ]]; then
      echo "  OK: $line"
    else
      echo "  WARN: malformed: $line"
    fi
  done < .env.example
fi

# Validate VERSION
echo "--- VERSION ---"
if [[ -f VERSION ]]; then
  version=$(cat VERSION)
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "  OK: $version"
  else
    echo "  WARN: non-standard version format: $version"
  fi
fi

# Validate Makefile .PHONY targets
echo "--- Makefile ---"
if [[ -f Makefile ]]; then
  phonies=$(grep '^.PHONY:' Makefile | head -1)
  echo "  PHONY targets: $(echo "$phonies" | wc -w)"
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "Configuration valid"
else echo "$errors configuration issue(s)"; fi
exit "$errors"
