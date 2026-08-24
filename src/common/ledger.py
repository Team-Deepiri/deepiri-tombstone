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


def _flat(value):
    """Collapse newlines so one logical row stays one physical line."""
    if value is None:
        return ""
    return str(value).replace("\r", " ").replace("\n", " ")


def format_line(run_id, model, prompt, response, latency_ms, status):
    """Serialize one ledger row. Pipes inside prompt are recoverable by parse_line."""
    return "|".join([
        _flat(run_id),
        _flat(model),
        _flat(prompt),
        _flat(response),
        _flat(latency_ms),
        _flat(status),
    ])


def append_batch(path, rows, mode="a"):
    """Append many ledger rows in one open/write/close. rows are dicts or 6-tuples."""
    if not rows:
        return 0
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    lines = []
    for row in rows:
        if isinstance(row, dict):
            line = format_line(
                row.get("run_id", ""),
                row.get("model", ""),
                row.get("prompt", ""),
                row.get("response", ""),
                row.get("latency_ms", ""),
                row.get("status", ""),
            )
        else:
            line = format_line(*row)
        lines.append(line)
    with open(path, mode, encoding="utf-8") as f:
        f.write("\n".join(lines))
        f.write("\n")
    return len(lines)


def append_stats_batch(path, rows, mode="a"):
    """Append stats.dat rows: (latency_ms, length, pass_flag)."""
    if not rows:
        return 0
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, mode, encoding="utf-8") as f:
        for row in rows:
            if isinstance(row, dict):
                lat = row.get("latency_ms", 0)
                length = row.get("length", 0)
                passed = row.get("pass", 0)
            else:
                lat, length, passed = row[0], row[1], row[2]
            f.write(f"{lat} {length} {int(passed)}\n")
    return len(rows)
