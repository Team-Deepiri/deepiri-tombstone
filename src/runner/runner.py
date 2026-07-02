#!/usr/bin/env python3
"""
Parallel Evaluation Runner for deepiri-tombstone.
Run multiple prompts concurrently with progress tracking.
"""
import json, sys, os, subprocess, argparse, signal, time, threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

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
            if not line or line.startswith('#'): continue
            if '|' in line:
                p, k = line.split('|', 1)
                prompts.append((p.strip(), k.strip()))
            else:
                prompts.append((line, ''))
    return prompts

def check_keyword(response, keyword):
    if not keyword: return True
    return keyword.lower() in response.lower()

def evaluate_one(model, prompt, keyword, host, idx):
    payload = json.dumps({"model": model, "prompt": prompt, "stream": False})
    start = time.time()
    try:
        r = subprocess.run(["curl", "-sf", "--max-time", "60", f"http://{host}/api/generate", "-d", payload],
                          capture_output=True, text=True, timeout=70)
        elapsed_ms = int((time.time() - start) * 1000)
        if r.returncode != 0:
            return (idx, prompt, "", elapsed_ms, False, f"curl error {r.returncode}")
        resp = json.loads(r.stdout).get("response", "")
        passed = check_keyword(resp, keyword)
        return (idx, prompt, resp[:200], elapsed_ms, passed, None)
    except subprocess.TimeoutExpired:
        return (idx, prompt, "", 60000, False, "timeout")
    except Exception as e:
        return (idx, prompt, "", 0, False, str(e))

def main():
    parser = argparse.ArgumentParser(description="Parallel evaluation runner")
    parser.add_argument("fixture", help="Fixture file")
    parser.add_argument("-m", "--model", default=os.environ.get("DEEPIRI_TOMBSTONE_MODEL", "llama3.2"))
    parser.add_argument("-j", "--jobs", type=int, default=4, help="Parallel jobs")
    parser.add_argument("-o", "--output", help="Output JSON")
    parser.add_argument("--no-progress", action="store_true", help="Disable progress")
    args = parser.parse_args()

    if not os.path.exists(args.fixture):
        print(f"ERROR: fixture not found: {args.fixture}", file=sys.stderr)
        sys.exit(1)

    prompts = load_fixture(args.fixture)
    if not prompts:
        print("ERROR: no prompts in fixture", file=sys.stderr)
        sys.exit(1)

    host = os.environ.get("DEEPIRI_TOMBSTONE_HOST", "127.0.0.1:11434")
    total = len(prompts)
    completed = 0
    results = [None] * total
    passes = 0
    start_time = time.time()

    print(f"Running {total} prompts with {args.jobs} workers...", file=sys.stderr)
    with ThreadPoolExecutor(max_workers=args.jobs) as ex:
        futures = {ex.submit(evaluate_one, args.model, p, k, host, i): i for i, (p, k) in enumerate(prompts)}
        try:
            for f in as_completed(futures):
                if not running:
                    break
                idx, prompt, resp, lat, passed, err = f.result()
                results[idx] = {"prompt": prompt, "response": resp, "latency_ms": lat, "pass": passed, "error": err}
                if passed: passes += 1
                completed += 1
                if not args.no_progress:
                    pct = int(completed / total * 100)
                    bar = '█' * (pct // 5) + '░' * (20 - pct // 5)
                    print(f"\r  [{bar}] {pct}% ({completed}/{total}) pass={passes} fail={completed-passes}", file=sys.stderr, end='')
        except KeyboardInterrupt:
            print("\nInterrupted, saving partial results...", file=sys.stderr)

    elapsed = int(time.time() - start_time)
    if not args.no_progress: print(file=sys.stderr)
    output = {
        "timestamp": datetime.now().isoformat(),
        "model": args.model,
        "fixture": args.fixture,
        "total": total,
        "completed": completed,
        "passes": passes,
        "failures": completed - passes,
        "pass_rate": round(passes / completed * 100, 1) if completed > 0 else 0,
        "elapsed_seconds": elapsed,
        "avg_latency_ms": round(sum(r["latency_ms"] for r in results if r and r["latency_ms"]) / max(completed, 1)),
        "results": results[:completed],
    }
    report = {k: v for k, v in output.items() if k != "results"}
    report["results_summary"] = f"{completed}/{total} completed"
    print(json.dumps(report, indent=2))
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(output, f, indent=2)
        print(f"Results to {args.output}", file=sys.stderr)
    sys.exit(0 if output["pass_rate"] >= 50 else 1)

if __name__ == "__main__":
    main()
