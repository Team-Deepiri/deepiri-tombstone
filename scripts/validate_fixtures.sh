#!/usr/bin/env bash
# Validate fixture file format — supports 2-column (PROMPT|KEYWORD)
# and 3-column (PROMPT|KEYWORD|CATEGORY) formats
set -euo pipefail

file="${1:-fixtures/eval_prompts.txt}"
errors=0
warnings=0
line_num=0
valid_categories="knowledge instruction reasoning language safety coding general"

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

  # Check for pipe separator
  if [[ "$line" != *"|"* ]]; then
    echo "ERROR:$line_num: bad format (no pipe separator): $line" >&2
    errors=$((errors + 1))
    continue
  fi

  # Validate 2 or 3 column format
  pipe_count=$(echo "$line" | awk -F'|' '{print NF-1}')
  if [[ "$pipe_count" -lt 1 || "$pipe_count" -gt 2 ]]; then
    echo "ERROR:$line_num: bad format (expected 1-2 pipes, got $pipe_count): $line" >&2
    errors=$((errors + 1))
    continue
  fi

  # Check for trailing whitespace
  if [[ "$line" =~ [[:space:]]$ ]]; then
    echo "WARN:$line_num: trailing whitespace: '$line'" >&2
    warnings=$((warnings + 1))
  fi

  # Check pipe isn't at start (empty prompt)
  if [[ "$line" == "|"* ]]; then
    echo "WARN:$line_num: empty prompt before pipe: '$line'" >&2
    warnings=$((warnings + 1))
  fi

  # Validate category if 3-column format
  if [[ "$pipe_count" -eq 2 ]]; then
    category=$(echo "$line" | awk -F'|' '{print $3}')
    if ! echo "$valid_categories" | grep -qw "${category,,}" 2>/dev/null; then
      echo "WARN:$line_num: unrecognized category '$category' (valid: $valid_categories)" >&2
      warnings=$((warnings + 1))
    fi
  fi

  # Check for empty fields
  if [[ "$line" == "|" ]]; then
    echo "WARN:$line_num: entirely empty pipe line" >&2
    warnings=$((warnings + 1))
  fi

done < "$file"

if [[ "$errors" -eq 0 && "$warnings" -eq 0 ]]; then
  echo "OK: $file — $line_num lines, no errors" >&2
elif [[ "$errors" -eq 0 ]]; then
  echo "OK: $file — $line_num lines, $warnings warning(s)" >&2
fi

if [[ "$errors" -eq 0 ]]; then
  # Extract some stats
  total=$(grep -cve '^\s*#' -e '^\s*$' "$file" || true)
  cat_count=$(awk -F'|' 'NF>2 && !/^#/ && NF>0 {print $3}' "$file" | sort | uniq -c | sort -rn | head -10 2>/dev/null || true)
  if [[ -n "$cat_count" ]]; then
    echo "STATS: $total prompts" >&2
    while IFS= read -r line; do
      echo "  $line" >&2
    done <<< "$cat_count"
  fi
fi

exit "$errors"
