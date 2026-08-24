#!/usr/bin/env python3
"""
Multi-Model Benchmark Runner for deepiri-tombstone.
Runs the same eval fixture across multiple models and compares results.
Uses keep-alive HTTP + response cache from the shared Ollama client.
"""
import json
import sys
import os
import argparse
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

_HERE = os.path.dirname(os.path.abspath(__file__))
for _cand in (_HERE, os.path.join(_HERE, "..", "common"), os.path.join(_HERE, "..", "..", "src", "common")):
    if os.path.exists(os.path.join(_cand, "ollama_client.py")):
        sys.path.insert(0, _cand)
        break

from ollama_client import OllamaClient  # noqa: E402


def load_fixture(path):
    prompts = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "|" in line:
                prompt, keyword = line.split("|", 1)
                prompts.append((prompt.strip(), keyword.strip()))
            else:
                prompts.append((line, ""))
    return prompts


def check_keyword(response, keyword):
    if not keyword:
        return True
    return keyword.lower() in response.lower()


def eval_prompt(client, model, prompt, keyword, use_cache):
    response, latency, error, cache_hit = client.generate(model, prompt, use_cache=use_cache)
    if error:
        return {
            "prompt": prompt,
            "response": None,
            "latency_ms": latency,
            "pass": False,
            "error": error,
            "cache_hit": False,
        }
    passed = check_keyword(response or "", keyword)
    return {
        "prompt": prompt,
        "response": (response or "")[:200],
        "latency_ms": latency,
        "pass": passed,
        "error": None,
        "cache_hit": cache_hit,
    }


def main():
    parser = argparse.ArgumentParser(description="Run multi-model benchmark")
    parser.add_argument("fixture", help="Fixture file (PROMPT|KEYWORD format)")
    parser.add_argument("models", nargs="+", help="Model(s) to benchmark")
    parser.add_argument("-o", "--output", help="Output file for results (JSON)")
    parser.add_argument("-j", "--jobs", type=int,
                        default=int(os.environ.get("DEEPIRI_TOMBSTONE_JOBS", "4")),
                        help="Parallel prompts per model")
    parser.add_argument("--table", action="store_true", help="Print comparison table")
    parser.add_argument("--no-cache", action="store_true", help="Disable response cache")
    args = parser.parse_args()

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
    results = {}
    summary = {}

    for model in args.models:
        print(f"Benchmarking model: {model} ({len(prompts)} prompts, j={args.jobs})...",
              file=sys.stderr)
        model_results = [None] * len(prompts)
        with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as ex:
            futs = {
                ex.submit(eval_prompt, client, model, p, k, not args.no_cache): i
                for i, (p, k) in enumerate(prompts)
            }
            for fut in as_completed(futs):
                i = futs[fut]
                model_results[i] = fut.result()

        passes = sum(1 for r in model_results if r and r["pass"])
        total_latency = sum(r["latency_ms"] for r in model_results if r)
        total_length = sum(len(r["response"] or "") for r in model_results if r)
        cache_hits = sum(1 for r in model_results if r and r.get("cache_hit"))
        n = len(model_results)
        results[model] = model_results
        summary[model] = {
            "pass_rate": round(passes / n * 100, 1) if n else 0,
            "passes": passes,
            "total": n,
            "avg_latency_ms": round(total_latency / max(n, 1)),
            "avg_length": round(total_length / max(n, 1)),
            "cache_hits": cache_hits,
        }
        print(
            f"  {model}: pass_rate={summary[model]['pass_rate']}% "
            f"avg_latency={summary[model]['avg_latency_ms']}ms "
            f"cache_hits={cache_hits}",
            file=sys.stderr,
        )

    client.close()
    output = {
        "timestamp": datetime.now().isoformat(),
        "fixture": args.fixture,
        "jobs": args.jobs,
        "summary": summary,
        "results": {m: results[m] for m in args.models},
    }

    if args.table:
        print(f"{'model':<24} {'pass%':>8} {'avg_ms':>10} {'cache':>8}")
        print("-" * 54)
        for m, s in summary.items():
            print(f"{m:<24} {s['pass_rate']:>7.1f}% {s['avg_latency_ms']:>10} {s['cache_hits']:>8}")

    print(json.dumps({"timestamp": output["timestamp"], "fixture": args.fixture,
                      "jobs": args.jobs, "summary": summary}, indent=2))
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            json.dump(output, f, indent=2)
        print(f"Results to {args.output}", file=sys.stderr)

    rates = [s["pass_rate"] for s in summary.values()]
    sys.exit(0 if rates and min(rates) >= 50 else 1)


if __name__ == "__main__":
    main()
