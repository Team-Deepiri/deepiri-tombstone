#!/usr/bin/env bash
# Validate fixture file format
set -euo pipefail

file="${1:-fixtures/eval_prompts.txt}"
errors=0
line_num=0

if [[ ! -f "$file" ]]; then
  echo "ERROR: fixture file not found: $file" >&2
  exit 1
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  line_num=$((line_num + 1))
  # Skip blank and comment lines
  if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
    continue
  fi
  # Must contain at least one pipe or be a bare prompt
  if [[ "$line" != *"|"* && ! "$line" =~ [^[:space:]] ]]; then
    echo "ERROR:$line_num: bad format (no pipe separator, non-empty): $line" >&2
    errors=$((errors + 1))
    continue
  fi
  # Check for trailing whitespace that would break parsing
  if [[ "$line" =~ [[:space:]]$ ]]; then
    echo "WARN:$line_num: trailing whitespace: '$line'" >&2
  fi
  # Check pipe isn't at start (empty prompt) unless intentional
  if [[ "$line" == "|"* ]]; then
    echo "WARN:$line_num: empty prompt before pipe: '$line'" >&2
  fi
done < "$file"

if [[ "$errors" -eq 0 ]]; then
  echo "OK: $file — $line_num lines, no errors" >&2
else
  echo "FAIL: $file — $errors error(s)" >&2
fi
exit "$errors"
