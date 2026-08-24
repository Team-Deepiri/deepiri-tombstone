#!/usr/bin/env python3
"""
Parallel Evaluation Runner for deepiri-tombstone.
Keep-alive HTTP, response cache, warm-on-start, adaptive jobs, SLO report.
"""
import os
import sys

# Locate shared helpers (bin/ after make, or src/common/ in-tree).
_HERE = os.path.dirname(os.path.abspath(__file__))
for _cand in (_HERE, os.path.join(_HERE, "..", "common"), os.path.join(_HERE, "..", "..", "src", "common")):
    if os.path.isfile(os.path.join(_cand, "paths.py")):
        if _cand not in sys.path:
            sys.path.insert(0, _cand)
        break
from paths import ensure_common_path, read_version  # noqa: E402
ensure_common_path(__file__)

import argparse
import json
import signal
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

from ollama_client import OllamaClient, cache_stats  # noqa: E402
from ledger import append_batch, append_stats_batch  # noqa: E402
from slo import compute_slo, default_jobs  # noqa: E402

running = True

def handle_signal(signum, frame):
    global running
    print("\nGraceful shutdown requested...", file=sys.stderr)
    running = False

signal.signal(signal.SIGINT, handle_signal)
signal.signal(signal.SIGTERM, handle_signal)

def load_fixture(path):
    prompts = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "|" in line:
                p, k = line.split("|", 1)
                prompts.append((p.strip(), k.strip()))
            else:
                prompts.append((line, ""))
    return prompts

def check_keyword(response, keyword):
    if not keyword:
        return True
    return keyword.lower() in response.lower()

def evaluate_one(client, model, prompt, keyword, idx, use_cache):
    resp, elapsed_ms, err, from_cache = client.generate(model, prompt, use_cache=use_cache)
    if err:
        return (idx, prompt, "", elapsed_ms, False, err, False)
    text = resp or ""
    passed = check_keyword(text, keyword)
    return (idx, prompt, text, elapsed_ms, passed, None, from_cache)

def main():
    parser = argparse.ArgumentParser(description="Parallel evaluation runner")
    parser.add_argument("fixture", help="Fixture file")
    parser.add_argument("-m", "--model", default=os.environ.get("DEEPIRI_TOMBSTONE_MODEL", "llama3.2"))
    parser.add_argument("-j", "--jobs", type=int, default=None,
                        help="Parallel jobs (default: adaptive 4–16, or DEEPIRI_TOMBSTONE_JOBS)")
    parser.add_argument("-o", "--output", help="Output JSON")
    parser.add_argument("--ledger", action="store_true",
                        help="Batch-append results to reports/audit.ledger and stats.dat")
    parser.add_argument("--ledger-path", default="reports/audit.ledger")
    parser.add_argument("--stats-path", default="reports/stats.dat")
    parser.add_argument("--no-cache", action="store_true", help="Disable response cache")
    parser.add_argument("--no-warm", action="store_true", help="Skip model warm-up before eval")
    parser.add_argument("--no-progress", action="store_true", help="Disable progress")
    args = parser.parse_args()

    jobs = default_jobs(args.jobs)
    if args.no_cache:
        os.environ["DEEPIRI_TOMBSTONE_NO_CACHE"] = "1"

    if not os.path.exists(args.fixture):
        print(f"ERROR: fixture not found: {args.fixture}", file=sys.stderr)
        sys.exit(1)

    prompts = load_fixture(args.fixture)
    if not prompts:
        print("ERROR: no prompts in fixture", file=sys.stderr)
        sys.exit(1)

    client = OllamaClient()
    warm_ms = 0
    if not args.no_warm:
        ok, warm_ms, werr = client.warm(args.model)
        if ok:
            print(f"warm ok in {warm_ms}ms", file=sys.stderr)
        else:
            print(f"warm skipped/failed: {werr}", file=sys.stderr)

    total = len(prompts)
    completed = 0
    results = [None] * total
    passes = 0
    cache_hits = 0
    start_time = time.monotonic()
    run_id = f"run-{datetime.now().strftime('%Y%m%d%H%M%S')}"

    print(f"Running {total} prompts with {jobs} workers (cache={'off' if args.no_cache else 'on'})...",
          file=sys.stderr)
    with ThreadPoolExecutor(max_workers=max(1, jobs)) as ex:
        futures = {
            ex.submit(evaluate_one, client, args.model, p, k, i, not args.no_cache): i
            for i, (p, k) in enumerate(prompts)
        }
        try:
            for f in as_completed(futures):
                if not running:
                    break
                idx, prompt, resp, lat, passed, err, from_cache = f.result()
                results[idx] = {
                    "prompt": prompt,
                    "response": resp[:500],
                    "latency_ms": lat,
                    "pass": passed,
                    "error": err,
                    "cache_hit": from_cache,
                }
                if passed:
                    passes += 1
                if from_cache:
                    cache_hits += 1
                completed += 1
                if not args.no_progress:
                    pct = int(completed / total * 100)
                    bar = "█" * (pct // 5) + "░" * (20 - pct // 5)
                    print(
                        f"\r  [{bar}] {pct}% ({completed}/{total}) "
                        f"pass={passes} fail={completed - passes} cache={cache_hits}",
                        file=sys.stderr,
                        end="",
                    )
        except KeyboardInterrupt:
            print("\nInterrupted, saving partial results...", file=sys.stderr)

    client.close()
    wall_seconds = time.monotonic() - start_time
    elapsed = int(wall_seconds)
    if not args.no_progress:
        print(file=sys.stderr)

    done = [r for r in results if r is not None]
    if args.ledger and done:
        ledger_rows = []
        stats_rows = []
        for i, r in enumerate(results):
            if r is None:
                continue
            status = "PASS" if r["pass"] else "FAIL"
            ledger_rows.append({
                "run_id": f"{run_id}-{i:04d}",
                "model": args.model,
                "prompt": r["prompt"],
                "response": r["response"],
                "latency_ms": r["latency_ms"],
                "status": status,
            })
            stats_rows.append({
                "latency_ms": r["latency_ms"],
                "length": len(r["response"]),
                "pass": 1 if r["pass"] else 0,
            })
        n_led = append_batch(args.ledger_path, ledger_rows)
        n_st = append_stats_batch(args.stats_path, stats_rows)
        print(f"Batched {n_led} ledger rows → {args.ledger_path}; "
              f"{n_st} stats → {args.stats_path}", file=sys.stderr)

    cs = cache_stats()
    latencies = [r["latency_ms"] for r in done]
    slo = compute_slo(
        completed=completed,
        cache_hits=cache_hits,
        wall_seconds=wall_seconds,
        latencies_ms=latencies,
        jobs=jobs,
    )
    output = {
        "timestamp": datetime.now().isoformat(),
        "version": read_version(__file__),
        "model": args.model,
        "fixture": args.fixture,
        "total": total,
        "completed": completed,
        "passes": passes,
        "failures": completed - passes,
        "pass_rate": round(passes / completed * 100, 1) if completed > 0 else 0,
        "elapsed_seconds": elapsed,
        "warm_ms": warm_ms,
        "avg_latency_ms": round(
            sum(r["latency_ms"] for r in done if r["latency_ms"]) / max(len([r for r in done if r["latency_ms"]]), 1)
        ) if any(r["latency_ms"] for r in done) else 0,
        "jobs": jobs,
        "cache_hits": cache_hits,
        "cache_entries": cs.get("entries", 0),
        "prompts_per_sec": slo["prompts_per_sec"],
        "slo": slo,
        "results": [r for r in results if r is not None],
    }
    report = {k: v for k, v in output.items() if k != "results"}
    report["results_summary"] = f"{completed}/{total} completed"
    print(json.dumps(report, indent=2))
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(output, f, indent=2)
        print(f"Results to {args.output}", file=sys.stderr)
    sys.exit(0 if output["pass_rate"] >= 50 else 1)

if __name__ == "__main__":
    main()
