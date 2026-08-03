#!/usr/bin/env python3
"""
Shared audit-ledger parsing for deepiri-tombstone stages.

The ledger written by src/audit is pipe-delimited with six fields:

    run_id|model|prompt|response|latency_ms|status

Prompts come from fixtures and routinely contain a literal '|', which a
naive str.split('|') cannot survive: every field after the prompt shifts
left, so status silently becomes the latency and latency becomes the
response. Fields are therefore recovered from both ends, where the
delimiters are unambiguous, and the remainder is attributed to the
prompt.
"""
import os

FIELDS = ("run_id", "model", "prompt", "response", "latency_ms", "status")


def parse_line(line):
    """Parse one ledger line into a dict, or return None if malformed.

    run_id and model are taken from the left and status, latency_ms and
    response from the right; anything left over belongs to the prompt.
    """
    line = line.strip()
    if not line:
        return None
    parts = line.split('|')
    if len(parts) < len(FIELDS):
        return None
    return {
        "run_id": parts[0],
        "model": parts[1],
        # Re-join the surplus: a prompt containing '|' lands here intact.
        "prompt": '|'.join(parts[2:-3]),
        "response": parts[-3],
        "latency_ms": parts[-2],
        "status": parts[-1],
    }


def load_ledger(path):
    """Read a ledger file into a list of dicts. Missing file yields []."""
    entries = []
    if not os.path.exists(path):
        return entries
    with open(path) as f:
        for line in f:
            entry = parse_line(line)
            if entry is not None:
                entries.append(entry)
    return entries


def load_stats(path):
    """Read reports/stats.dat: whitespace-separated latency, length, pass."""
    stats = []
    if not os.path.exists(path):
        return stats
    with open(path) as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 3:
                stats.append({
                    "latency_ms": parts[0],
                    "length": parts[1],
                    "pass": parts[2],
                })
    return stats
