#!/usr/bin/env python3
"""
Statistical Analysis for deepiri-tombstone.
Confidence intervals, significance testing, trend analysis.
"""
import json, sys, os, argparse, math, random
from datetime import datetime

random.seed(42)

def load_stats(path):
    stats = []
    if not os.path.exists(path): return stats
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            parts = line.split()
            if len(parts) >= 3:
                try:
                    stats.append({
                        "latency_ms": int(parts[0]),
                        "length": int(parts[1]),
                        "pass": int(parts[2]),
                    })
                except ValueError:
                    pass
    return stats

def mean(vals):
    return sum(vals) / len(vals) if vals else 0

def stdev(vals):
    if len(vals) < 2: return 0
    m = mean(vals)
    return math.sqrt(sum((v - m)**2 for v in vals) / (len(vals) - 1))

def bootstrap_ci(vals, metric=mean, n_samples=1000, ci=0.95):
    if len(vals) < 2: return {"estimate": mean(vals), "ci_lower": mean(vals), "ci_upper": mean(vals)}
    estimates = []
    for _ in range(n_samples):
        sample = [random.choice(vals) for _ in range(len(vals))]
        estimates.append(metric(sample))
    estimates.sort()
    lower_idx = int((1 - ci) / 2 * n_samples)
    upper_idx = int((1 + ci) / 2 * n_samples)
    return {
        "estimate": round(mean(vals), 2),
        "ci_lower": round(estimates[lower_idx], 2),
        "ci_upper": round(estimates[upper_idx], 2),
        "ci_level": ci,
        "n": len(vals),
    }

def mann_whitney_u(x, y):
    """Simple Mann-Whitney U test for significance"""
    n_x, n_y = len(x), len(y)
    if n_x == 0 or n_y == 0: return {"u": 0, "p_value": 1.0, "significant": False}
    combined = [(v, 0) for v in x] + [(v, 1) for v in y]
    combined.sort(key=lambda t: t[0])
    rank_sum_x = sum(i+1 for i, (_, g) in enumerate(combined) if g == 0)
    u = rank_sum_x - (n_x * (n_x + 1)) / 2
    u2 = n_x * n_y - u
    u_stat = min(u, u2)
    mu = n_x * n_y / 2
    sigma = math.sqrt(n_x * n_y * (n_x + n_y + 1) / 12)
    if sigma == 0: return {"u": u_stat, "p_value": 1.0, "significant": False}
    z = (u_stat - mu) / sigma
    p = 2 * (1 - 0.5 * (1 + math.erf(abs(z) / math.sqrt(2))))
    return {"u": u_stat, "p_value": round(p, 4), "significant": p < 0.05}

def analyze_trends(stats, window=10):
    if len(stats) < window:
        return {"error": f"need at least {window} data points"}
    recent = stats[-window:]
    past = stats[:-window] if len(stats) > window else []
    latencies = [s["latency_ms"] for s in stats]
    recent_lat = [s["latency_ms"] for s in recent]
    past_lat = [s["latency_ms"] for s in past] if past else []
    pass_rates = [s["pass"] for s in stats]
    recent_pass = [s["pass"] for s in recent]
    past_pass = [s["pass"] for s in past] if past else []
    result = {
        "overall": {
            "n": len(stats),
            "latency_ms": bootstrap_ci(latencies),
            "pass_rate": bootstrap_ci(pass_rates),
        },
        "recent": {
            "n": len(recent),
            "latency_ms": bootstrap_ci(recent_lat),
            "pass_rate": round(mean(recent_pass), 2),
        },
    }
    if past:
        sig_test = mann_whitney_u(past_lat, recent_lat)
        result["trend"] = {
            "latency_change": round(mean(recent_lat) - mean(past_lat), 2),
            "pass_rate_change": round(mean(recent_pass) - mean(past_pass), 2),
            "significant": sig_test["significant"],
            "p_value": sig_test["p_value"],
        }
    return result

def main():
    parser = argparse.ArgumentParser(description="Statistical analysis")
    parser.add_argument("-f", "--file", default="reports/stats.dat")
    parser.add_argument("--ci", action="store_true", help="Bootstrap confidence intervals")
    parser.add_argument("--trend", action="store_true", help="Trend analysis")
    parser.add_argument("--compare", nargs=2, metavar=("FILE1", "FILE2"), help="Compare two stat files")
    parser.add_argument("--window", type=int, default=10, help="Trend window")
    args = parser.parse_args()
    if args.compare:
        s1, s2 = load_stats(args.compare[0]), load_stats(args.compare[1])
        lat1 = [s["latency_ms"] for s in s1]
        lat2 = [s["latency_ms"] for s in s2]
        pass1 = [s["pass"] for s in s1]
        pass2 = [s["pass"] for s in s2]
        result = {
            "comparison": {
                "file1": {"file": args.compare[0], "n": len(s1), "latency": bootstrap_ci(lat1) if args.ci else {"mean": round(mean(lat1), 2)}},
                "file2": {"file": args.compare[1], "n": len(s2), "latency": bootstrap_ci(lat2) if args.ci else {"mean": round(mean(lat2), 2)}},
            },
            "latency_significance": mann_whitney_u(lat1, lat2),
            "pass_rate_1": round(mean(pass1), 2),
            "pass_rate_2": round(mean(pass2), 2),
        }
        print(json.dumps(result, indent=2))
        return
    stats = load_stats(args.file)
    if not stats:
        print(f"No data in {args.file}", file=sys.stderr)
        sys.exit(1)
    result = {"n": len(stats), "file": args.file}
    if args.ci:
        latencies = [s["latency_ms"] for s in stats]
        lengths = [s["length"] for s in stats]
        passes = [s["pass"] for s in stats]
        result["latency"] = bootstrap_ci(latencies)
        result["length"] = bootstrap_ci(lengths)
        result["pass_rate"] = bootstrap_ci(passes)
        result["latency_stdev"] = round(stdev(latencies), 2)
    if args.trend:
        result["trend"] = analyze_trends(stats, args.window)
    if not args.ci and not args.trend:
        latencies = [s["latency_ms"] for s in stats]
        passes = sum(s["pass"] for s in stats)
        result["summary"] = {
            "mean_latency_ms": round(mean(latencies), 2),
            "pass_rate": round(passes / len(stats) * 100, 1),
            "passes": passes,
            "total": len(stats),
        }
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
