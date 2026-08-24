#!/usr/bin/env python3
"""
Parallel Evaluation Runner for deepiri-tombstone.

Cache-first → warm only if misses → parallel miss pool with optional
stream early-stop on keywords → fail-fast → SLO report.
"""
import os
import sys

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

from ollama_client import OllamaClient, cache_get, cache_stats  # noqa: E402
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

def fail_fast_limit(explicit):
    if explicit is not None and explicit >= 0:
        return explicit
    env = os.environ.get("DEEPIRI_TOMBSTONE_FAIL_FAST", "")
    if env:
        try:
            return max(0, int(env))
        except ValueError:
            pass
    return 0

def evaluate_one(client, model, prompt, keyword, idx, use_cache, early_stop):
    stop_when = None
    if early_stop and keyword:
        needle = keyword.lower()
        stop_when = lambda text, n=needle: n in text.lower()
    resp, elapsed_ms, err, from_cache = client.generate(
        model, prompt, use_cache=use_cache, stop_when=stop_when
    )
    if err:
        return (idx, prompt, "", elapsed_ms, False, err, False, False)
    text = resp or ""
    passed = check_keyword(text, keyword)
    early = stop_when is not None and passed and not from_cache and elapsed_ms > 0
    return (idx, prompt, text, elapsed_ms, passed, None, from_cache, early)

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
    parser.add_argument("--no-early-stop", action="store_true",
                        help="Disable stream early-stop on keyword match")
    parser.add_argument("--fail-fast", type=int, default=None, metavar="N",
                        help="Stop after N failures (0=off; env DEEPIRI_TOMBSTONE_FAIL_FAST)")
    parser.add_argument("--no-progress", action="store_true", help="Disable progress")
    args = parser.parse_args()

    jobs = default_jobs(args.jobs)
    ff = fail_fast_limit(args.fail_fast)
    use_cache = not args.no_cache
    early_stop = not args.no_early_stop
    if args.no_cache:
        os.environ["DEEPIRI_TOMBSTONE_NO_CACHE"] = "1"

    if not os.path.exists(args.fixture):
        print(f"ERROR: fixture not found: {args.fixture}", file=sys.stderr)
        sys.exit(1)

    prompts = load_fixture(args.fixture)
    if not prompts:
        print("ERROR: no prompts in fixture", file=sys.stderr)
        sys.exit(1)

    total = len(prompts)
    results = [None] * total
    passes = 0
    cache_hits = 0
    early_stops = 0
    completed = 0
    failures = 0
    run_id = f"run-{datetime.now().strftime('%Y%m%d%H%M%S')}"
    start_time = time.monotonic()

    # Phase 1: cache-first — resolve hits without threads or GPU.
    misses = []
    if use_cache:
        for i, (p, k) in enumerate(prompts):
            cached = cache_get(args.model, p, "generate")
            if cached is not None:
                passed = check_keyword(cached, k)
                results[i] = {
                    "prompt": p,
                    "response": cached[:500],
                    "latency_ms": 0,
                    "pass": passed,
                    "error": None,
                    "cache_hit": True,
                    "early_stop": False,
                }
                if passed:
                    passes += 1
                else:
                    failures += 1
                cache_hits += 1
                completed += 1
            else:
                misses.append((i, p, k))
    else:
        misses = [(i, p, k) for i, (p, k) in enumerate(prompts)]

    if cache_hits and not args.no_progress:
        print(f"cache-first: {cache_hits}/{total} hits resolved instantly", file=sys.stderr)

    if ff and failures >= ff:
        print(f"fail-fast: {failures} failures before miss pool — aborting", file=sys.stderr)
        misses = []

    client = OllamaClient()
    warm_ms = 0
    need_gpu = len(misses) > 0
    if need_gpu and not args.no_warm:
        ok, warm_ms, werr = client.warm(args.model)
        if ok:
            print(f"warm ok in {warm_ms}ms", file=sys.stderr)
        else:
            print(f"warm skipped/failed: {werr}", file=sys.stderr)
    elif not need_gpu:
        print("full cache hit — skipped warm and GPU", file=sys.stderr)

    print(
        f"Running {len(misses)} misses / {total} total with {jobs} workers "
        f"(cache={'off' if args.no_cache else 'on'}, early_stop={'on' if early_stop else 'off'}, "
        f"fail_fast={ff or 'off'})...",
        file=sys.stderr,
    )

    aborted = False
    if misses:
        with ThreadPoolExecutor(max_workers=max(1, jobs)) as ex:
            futures = {
                ex.submit(
                    evaluate_one, client, args.model, p, k, i, use_cache, early_stop
                ): i
                for i, p, k in misses
            }
            try:
                for f in as_completed(futures):
                    if not running:
                        aborted = True
                        break
                    idx, prompt, resp, lat, passed, err, from_cache, early = f.result()
                    results[idx] = {
                        "prompt": prompt,
                        "response": resp[:500],
                        "latency_ms": lat,
                        "pass": passed,
                        "error": err,
                        "cache_hit": from_cache,
                        "early_stop": early,
                    }
                    if passed:
                        passes += 1
                    else:
                        failures += 1
                    if from_cache:
                        cache_hits += 1
                    if early:
                        early_stops += 1
                    completed += 1
                    if not args.no_progress:
                        wall = max(time.monotonic() - start_time, 0.001)
                        pps = round(completed / wall, 1)
                        pct = int(completed / total * 100)
                        bar = "█" * (pct // 5) + "░" * (20 - pct // 5)
                        print(
                            f"\r  [{bar}] {pct}% ({completed}/{total}) "
                            f"pass={passes} fail={failures} cache={cache_hits} "
                            f"early={early_stops} {pps}pps",
                            file=sys.stderr,
                            end="",
                        )
                    if ff and failures >= ff:
                        print(f"\nfail-fast: reached {failures} failures — cancelling",
                              file=sys.stderr)
                        aborted = True
                        for pending in futures:
                            pending.cancel()
                        break
            except KeyboardInterrupt:
                print("\nInterrupted, saving partial results...", file=sys.stderr)
                aborted = True

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
        "failures": failures,
        "pass_rate": round(passes / completed * 100, 1) if completed > 0 else 0,
        "elapsed_seconds": elapsed,
        "warm_ms": warm_ms,
        "avg_latency_ms": round(
            sum(r["latency_ms"] for r in done if r["latency_ms"]) /
            max(len([r for r in done if r["latency_ms"]]), 1)
        ) if any(r["latency_ms"] for r in done) else 0,
        "jobs": jobs,
        "cache_hits": cache_hits,
        "early_stops": early_stops,
        "fail_fast": ff,
        "aborted": aborted,
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
