#!/usr/bin/env python3
"""
Production Replay Engine for deepiri-tombstone.
Re-runs evaluations from audit ledger and compares results across runs.
"""
import json, sys, os, subprocess, argparse, time
from datetime import datetime

# Installed beside this script in bin/, or under src/common/ when run in tree.
_HERE = os.path.dirname(os.path.abspath(__file__))
for _cand in (_HERE, os.path.join(_HERE, "..", "..", "src", "common")):
    if os.path.exists(os.path.join(_cand, "ledger.py")):
        sys.path.insert(0, _cand)
        break
from ledger import load_ledger as parse_ledger

def replay_entry(entry, model, host):
    """Re-run a single prompt/response evaluation"""
    prompt = entry["prompt"]
    payload = json.dumps({"model": model, "prompt": prompt, "stream": False})
    start = time.time()
    try:
        r = subprocess.run(["curl", "-sf", "--max-time", "60", f"http://{host}/api/generate", "-d", payload],
                          capture_output=True, text=True, timeout=70)
        elapsed = int((time.time() - start) * 1000)
        if r.returncode != 0:
            return {"prompt": prompt, "error": f"curl {r.returncode}", "latency_ms": elapsed, "pass": False}
        resp = json.loads(r.stdout).get("response", "")
        passed = entry["status"] == "PASS"
        return {"prompt": prompt, "response": resp[:200], "latency_ms": elapsed, "pass": passed}
    except Exception as e:
        return {"prompt": prompt, "error": str(e), "latency_ms": 0, "pass": False}

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
    results = []
    for i, e in enumerate(entries):
        print(f"  [{i+1}/{len(entries)}] {e['prompt'][:50]}...", file=sys.stderr)
        results.append(replay_entry(e, model, host))
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
