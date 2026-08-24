#!/usr/bin/env python3
"""
Production Replay Engine for deepiri-tombstone.
Re-runs evaluations from audit ledger and compares results across runs.
"""
import json, sys, os, argparse
from datetime import datetime

# Installed beside this script in bin/, or under src/common/ when run in tree.
_HERE = os.path.dirname(os.path.abspath(__file__))
for _cand in (_HERE, os.path.join(_HERE, "..", "common"), os.path.join(_HERE, "..", "..", "src", "common")):
    if os.path.exists(os.path.join(_cand, "ledger.py")):
        sys.path.insert(0, _cand)
        break
from ledger import load_ledger as parse_ledger
from ollama_client import OllamaClient  # noqa: E402


def replay_entry(entry, model, host, client=None):
    """Re-run a single prompt/response evaluation"""
    prompt = entry["prompt"]
    client = client or OllamaClient(host=host)
    resp, elapsed, err, _ = client.generate(model, prompt, use_cache=True)
    if err:
        return {"prompt": prompt, "error": err, "latency_ms": elapsed, "pass": False}
    passed = entry["status"] == "PASS"
    return {"prompt": prompt, "response": (resp or "")[:200], "latency_ms": elapsed, "pass": passed}

def compare_runs(original, replayed):
    changes = []
    for orig, rep in zip(original, replayed):
        status_changed = (orig["status"] == "PASS") != rep["pass"]
        changes.append({
            "prompt": orig["prompt"][:60],
            "original_status": orig["status"],
            "replayed_status": "PASS" if rep["pass"] else "FAIL",
            "changed": status_changed,
            "original_latency": orig["latency_ms"],
            "replayed_latency": rep["latency_ms"],
        })
    return changes

def main():
    parser = argparse.ArgumentParser(description="Replay evaluations from ledger")
    parser.add_argument("ledger", nargs="?", default="reports/audit.ledger", help="Audit ledger path")
    parser.add_argument("-m", "--model", help="Override model")
    parser.add_argument("-n", "--count", type=int, default=0, help="Entries to replay (0=all)")
    parser.add_argument("-o", "--output", help="Output comparison JSON")
    parser.add_argument("--compare", action="store_true", help="Compare with original results")
    args = parser.parse_args()
    host = os.environ.get("DEEPIRI_TOMBSTONE_HOST", "127.0.0.1:11434")
    model = args.model or os.environ.get("DEEPIRI_TOMBSTONE_MODEL", "llama3.2")
    entries = parse_ledger(args.ledger)
    if not entries:
        print(f"No entries found in {args.ledger}", file=sys.stderr)
        sys.exit(1)
    if args.count > 0:
        entries = entries[:args.count]
    print(f"Replaying {len(entries)} entries with model={model}...", file=sys.stderr)
    client = OllamaClient(host=host)
    results = []
    for i, e in enumerate(entries):
        print(f"  [{i+1}/{len(entries)}] {e['prompt'][:50]}...", file=sys.stderr)
        results.append(replay_entry(e, model, host, client))
    client.close()
    output = {
        "timestamp": datetime.now().isoformat(),
        "model": model,
        "source_ledger": args.ledger,
        "entries_replayed": len(results),
        "passes": sum(1 for r in results if r.get("pass")),
        "failures": sum(1 for r in results if not r.get("pass")),
        "results": results,
    }
    if args.compare:
        output["comparison"] = compare_runs(entries, results)
        regressions = sum(1 for c in output["comparison"] if c.get("changed") and c["original_status"] == "PASS")
        output["regressions"] = regressions
    print(json.dumps({k: v for k, v in output.items() if k != "results"}, indent=2))
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(output, f, indent=2)
        print(f"Results to {args.output}", file=sys.stderr)
    if output.get("regressions", 0) > 0:
        print(f"WARNING: {output['regressions']} regression(s) detected!", file=sys.stderr)
    sys.exit(0)

if __name__ == "__main__":
    main()
