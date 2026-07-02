#!/usr/bin/env python3
"""
Multi-Model Benchmark Runner for deepiri-tombstone.
Runs the same eval fixture across multiple models and compares results.
"""
import json, sys, os, subprocess, time, argparse
from datetime import datetime

def load_fixture(path):
    prompts = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '|' in line:
                prompt, keyword = line.split('|', 1)
                prompts.append((prompt.strip(), keyword.strip()))
            else:
                prompts.append((line, ''))
    return prompts

def call_ollama(model, prompt, host):
    payload = json.dumps({"model": model, "prompt": prompt, "stream": False})
    start = time.time()
    try:
        result = subprocess.run(
            ["curl", "-sf", "--max-time", "120", f"http://{host}/api/generate", "-d", payload],
            capture_output=True, text=True, timeout=130
        )
        elapsed = int((time.time() - start) * 1000)
        if result.returncode != 0:
            return None, elapsed, f"curl error {result.returncode}"
        resp_data = json.loads(result.stdout)
        response = resp_data.get("response", "")
        return response, elapsed, None
    except subprocess.TimeoutExpired:
        return None, 120000, "timeout"
    except json.JSONDecodeError as e:
        return None, 0, f"JSON error: {e}"
    except Exception as e:
        return None, 0, str(e)

def check_keyword(response, keyword):
    if not keyword:
        return True
    return keyword.lower() in response.lower()

def main():
    parser = argparse.ArgumentParser(description="Run multi-model benchmark")
    parser.add_argument("fixture", help="Fixture file (PROMPT|KEYWORD format)")
    parser.add_argument("models", nargs="+", help="Model(s) to benchmark")
    parser.add_argument("-o", "--output", help="Output file for results (JSON)")
    parser.add_argument("--table", action="store_true", help="Print comparison table")
    args = parser.parse_args()

    if not os.path.exists(args.fixture):
        print(f"ERROR: fixture not found: {args.fixture}", file=sys.stderr)
        sys.exit(1)

    prompts = load_fixture(args.fixture)
    if not prompts:
        print("ERROR: no prompts in fixture", file=sys.stderr)
        sys.exit(1)

    host = os.environ.get("DEEPIRI_TOMBSTONE_HOST", "127.0.0.1:11434")
    results = {}
    summary = {}

    for model in args.models:
        print(f"Benchmarking model: {model} ({len(prompts)} prompts)...", file=sys.stderr)
        model_results = []
        passes = 0
        total_latency = 0
        total_length = 0

        for prompt, keyword in prompts:
            response, latency, error = call_ollama(model, prompt, host)
            if error:
                model_results.append({
                    "prompt": prompt, "keyword": keyword,
                    "response": "", "latency_ms": latency,
                    "pass": False, "error": error
                })
                continue

            passed = check_keyword(response, keyword)
            if passed:
                passes += 1
            total_latency += latency
            total_length += len(response)

            model_results.append({
                "prompt": prompt, "keyword": keyword,
                "response": response, "latency_ms": latency,
                "pass": passed
            })

        n = len(prompts)
        summary[model] = {
            "pass_rate": round(passes / n * 100, 1) if n > 0 else 0,
            "passes": passes,
            "total": n,
            "avg_latency_ms": round(total_latency / n) if n > 0 else 0,
            "avg_response_length": round(total_length / n) if n > 0 else 0,
            "total_time_ms": total_latency,
        }
        results[model] = model_results

    benchmark_result = {
        "timestamp": datetime.now().isoformat(),
        "fixture": args.fixture,
        "models": summary,
        "details": results,
    }

    if args.table:
        print()
        print("=" * 80)
        print(f"{'Model':<20} {'Pass Rate':<12} {'Passes':<10} {'Avg Lat':<12} {'Avg Len':<12}")
        print("-" * 80)
        for model, s in sorted(summary.items(), key=lambda x: -x[1]["pass_rate"]):
            print(f"{model:<20} {s['pass_rate']:<11.1f}% {s['passes']}/{s['total']:<5} {s['avg_latency_ms']:<10}ms {s['avg_response_length']:<10}chars")
        print("=" * 80)

    output = {
        "timestamp": datetime.now().isoformat(),
        "fixture": args.fixture,
        "models": summary,
    }
    print(json.dumps(output, indent=2))

    if args.output:
        with open(args.output, 'w') as f:
            json.dump(benchmark_result, f, indent=2)
        print(f"Results written to {args.output}", file=sys.stderr)

    # Exit code: 0 if any model passes > 50%, else 1
    best_rate = max((s["pass_rate"] for s in summary.values()), default=0)
    sys.exit(0 if best_rate >= 50 else 1)

if __name__ == "__main__":
    main()
