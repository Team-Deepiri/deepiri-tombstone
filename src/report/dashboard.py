#!/usr/bin/env python3
"""
HTML Dashboard Generator for deepiri-tombstone.
Produces rich visual reports from evaluation results.
"""
import json, sys, os, argparse
from datetime import datetime

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>deepiri-tombstone Evaluation Dashboard</title>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, monospace; background: #0d1117; color: #c9d1d9; padding: 20px; }}
h1 {{ color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 10px; margin-bottom: 20px; }}
h2 {{ color: #f0883e; margin: 20px 0 10px; }}
h3 {{ color: #8b949e; margin: 15px 0 8px; }}
.summary {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }}
.card {{ background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 15px; }}
.card .value {{ font-size: 28px; font-weight: bold; color: #58a6ff; }}
.card .label {{ font-size: 12px; color: #8b949e; text-transform: uppercase; margin-top: 5px; }}
.card.pass .value {{ color: #3fb950; }}
.card.fail .value {{ color: #f85149; }}
table {{ width: 100%; border-collapse: collapse; margin: 15px 0; }}
th {{ background: #21262d; color: #8b949e; padding: 8px 12px; text-align: left; font-size: 12px; text-transform: uppercase; border: 1px solid #30363d; }}
td {{ padding: 8px 12px; border: 1px solid #30363d; font-size: 13px; }}
tr:nth-child(even) {{ background: #161b22; }}
tr:hover {{ background: #1c2128; }}
.pass {{ color: #3fb950; }}
.fail {{ color: #f85149; }}
.model-bar {{ display: flex; align-items: center; margin: 5px 0; }}
.model-name {{ width: 150px; font-size: 13px; }}
.model-bar-fill {{ height: 20px; border-radius: 4px; margin-left: 10px; min-width: 4px; }}
.model-pct {{ margin-left: 10px; font-size: 12px; }}
.footer {{ margin-top: 30px; padding-top: 10px; border-top: 1px solid #30363d; font-size: 11px; color: #484f58; }}
pre {{ background: #161b22; padding: 10px; border-radius: 6px; overflow-x: auto; font-size: 12px; }}
</style>
</head>
<body>
<h1>🔱 deepiri-tombstone — Evaluation Dashboard</h1>
<p>Generated: {timestamp}</p>

<div class="summary">
  <div class="card"><div class="value">{total_prompts}</div><div class="label">Total Prompts</div></div>
  <div class="card pass"><div class="value">{pass_rate:.1f}%</div><div class="label">Pass Rate</div></div>
  <div class="card"><div class="value">{passes}</div><div class="label">Passed</div></div>
  <div class="card fail"><div class="value">{failures}</div><div class="label">Failed</div></div>
  <div class="card"><div class="value">{avg_latency}ms</div><div class="label">Avg Latency</div></div>
  <div class="card"><div class="value">{models_count}</div><div class="label">Models</div></div>
</div>
{model_comparison}
{results_table}
{audit_log}
<div class="footer">
  <p>deepiri-tombstone v1.0.0-dev — Post-training LLM Evaluation Harness</p>
  <p>Report path: {report_path}</p>
</div>
</body>
</html>"""

def parse_stats(path):
    """Parse reports/stats.dat"""
    stats = {"runs": 0, "total_latency": 0, "total_length": 0, "passes": 0}
    if not os.path.exists(path):
        return stats
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) >= 4:
                stats["runs"] += 1
                try:
                    stats["total_latency"] += int(parts[0])
                    stats["total_length"] += int(parts[1])
                    stats["passes"] += int(parts[2])
                except (ValueError, IndexError):
                    pass
    return stats

def parse_audit(path):
    """Parse reports/audit.ledger"""
    entries = []
    if not os.path.exists(path):
        return entries
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split('|')
            if len(parts) >= 6:
                entries.append({
                    "run_id": parts[0],
                    "model": parts[1],
                    "prompt": parts[2][:60],
                    "response": parts[3][:80],
                    "latency": parts[4],
                    "status": parts[5],
                })
    return entries

def build_model_comparison(summary):
    if not summary or len(summary) <= 1:
        return ""
    models_html = "<h2>Model Comparison</h2><div>"
    best = max(summary.values(), key=lambda x: x.get("pass_rate", 0))
    for model, s in sorted(summary.items(), key=lambda x: -x[1]["pass_rate"]):
        rate = s.get("pass_rate", 0)
        color = "#3fb950" if rate >= 80 else "#f0883e" if rate >= 50 else "#f85149"
        is_best = "⭐ " if rate == best["pass_rate"] else ""
        models_html += f"""<div class="model-bar">
          <div class="model-name">{is_best}{model}</div>
          <div class="model-bar-fill" style="width:{rate}%;background:{color}"></div>
          <div class="model-pct">{rate:.1f}%</div>
        </div>"""
    models_html += "</div>"
    return models_html

def build_results_table(entries, title="Results"):
    if not entries:
        return ""
    table = f"<h2>{title}</h2><table><tr><th>Run</th><th>Model</th><th>Prompt</th><th>Response</th><th>Latency</th><th>Status</th></tr>"
    for e in entries[-50:]:
        status_class = "pass" if e["status"] == "PASS" else "fail"
        table += f"<tr><td>{e['run_id']}</td><td>{e['model']}</td><td>{e['prompt']}</td><td>{e['response']}</td><td>{e['latency']}ms</td><td class='{status_class}'>{e['status']}</td></tr>"
    table += "</table>"
    return table

def build_benchmark_section(bench_path):
    """Include benchmark results if available"""
    if not os.path.exists(bench_path):
        return ""
    with open(bench_path) as f:
        data = json.load(f)
    return build_model_comparison(data.get("models", {}))

def main():
    parser = argparse.ArgumentParser(description="Generate HTML evaluation dashboard")
    parser.add_argument("-o", "--output", default="reports/dashboard.html", help="Output HTML file")
    parser.add_argument("--stats", default="reports/stats.dat", help="Stats file")
    parser.add_argument("--audit", default="reports/audit.ledger", help="Audit ledger file")
    parser.add_argument("--bench", help="Benchmark JSON results file")
    args = parser.parse_args()

    stats = parse_stats(args.stats)
    entries = parse_audit(args.audit)

    passes = stats.get("passes", 0)
    failures = stats.get("runs", 0) - passes
    pass_rate = (passes / stats["runs"] * 100) if stats["runs"] > 0 else 0
    avg_latency = (stats["total_latency"] // stats["runs"]) if stats["runs"] > 0 else 0

    model_comparison = ""
    if args.bench:
        model_comparison = build_benchmark_section(args.bench)

    # Try to extract unique models from audit
    models = set(e["model"] for e in entries if e["model"])
    models_count = len(models) if models else 1

    html = HTML_TEMPLATE.format(
        timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        total_prompts=stats["runs"],
        pass_rate=pass_rate,
        passes=passes,
        failures=failures,
        avg_latency=avg_latency,
        models_count=models_count,
        model_comparison=model_comparison,
        results_table=build_results_table(entries),
        audit_log="",
        report_path=os.path.abspath(args.output),
    )

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, 'w') as f:
        f.write(html)
    print(f"Dashboard written to {args.output}")
    print(f"  Stats: {stats['runs']} runs, {pass_rate:.1f}% pass rate, {avg_latency}ms avg latency")

if __name__ == "__main__":
    main()
