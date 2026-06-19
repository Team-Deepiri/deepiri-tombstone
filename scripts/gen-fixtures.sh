#!/usr/bin/env bash
# Generate test prompts programmatically
set -euo pipefail

COUNT="${1:-10}"
PREFIX="${2:-auto}"

echo "# Auto-generated test prompts ($(date))"
echo "# $COUNT prompts"
echo ""

for i in $(seq 1 "$COUNT"); do
  case $((i % 5)) in
    0) echo "What is ${i}+${i}?|$((i + i))" ;;
    1) echo "Respond with exactly the word prompt${i}|prompt${i}" ;;
    2) echo "Capital of country number ${i} is|City" ;;
    3) echo "Say hello in exactly one word|hello" ;;
    4) echo "Count from 1 to ${i}|${i}" ;;
  esac
done
