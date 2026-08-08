#!/usr/bin/env python3
"""
HTML Dashboard Generator for deepiri-tombstone.
Produces rich visual reports from evaluation results.
"""
import json, sys, os, argparse
from datetime import datetime

# Installed beside this script in bin/, or under src/common/ when run in tree.
_HERE = os.path.dirname(os.path.abspath(__file__))
for _cand in (_HERE, os.path.join(_HERE, "..", "..", "src", "common")):
    if os.path.exists(os.path.join(_cand, "ledger.py")):
        sys.path.insert(0, _cand)
        break
from ledger import load_ledger

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>deepiri-tombstone Evaluation Dashboard</title>
<style>
:root {{
  color-scheme: light dark;
  --bg: #0d1117;
  --bg-card: #161b22;
  --bg-elevated: #1c2128;
  --border: #30363d;
  --text: #c9d1d9;
  --muted: #8b949e;
  --heading: #58a6ff;
  --accent-warm: #f0883e;
  --pass: #3fb950;
  --fail: #f85149;
  --font: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, monospace;
  --radius: 10px;
  --radius-sm: 6px;
  --shadow: 0 10px 30px rgba(0, 0, 0, 0.35);
  --card-pad: clamp(14px, 2vw, 22px);
  --fs-hero: clamp(1.6rem, 0.8rem + 3vw, 2.6rem);
  --fs-value: clamp(24px, 2.5vw, 32px);
  --ease: cubic-bezier(0.4, 0, 0.2, 1);
}}
@media (prefers-color-scheme: light) {{
  :root {{
    --bg: #f6f8fa;
    --bg-card: #ffffff;
    --bg-elevated: #eef1f4;
    --border: #d0d7de;
    --text: #24292f;
    --muted: #57606a;
    --heading: #0969da;
    --accent-warm: #bc4c00;
    --pass: #1a7f37;
    --fail: #cf222e;
    --shadow: 0 10px 30px rgba(31, 35, 40, 0.12);
  }}
}}
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{ font-family: var(--font); background: var(--bg); color: var(--text); padding: clamp(16px, 3vw, 32px); line-height: 1.55; }}
h1 {{ color: var(--heading); border-bottom: 1px solid var(--border); padding-bottom: 12px; margin-bottom: 18px; font-size: var(--fs-hero); font-weight: 800; letter-spacing: -0.01em; }}
h2 {{ color: var(--accent-warm); margin: 24px 0 10px; }}
h3 {{ color: var(--muted); margin: 15px 0 8px; }}
.summary {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: clamp(10px, 1.5vw, 16px); margin: 20px 0; }}
.card {{ background: var(--bg-card); border: 1px solid var(--border); border-radius: var(--radius); padding: var(--card-pad); box-shadow: var(--shadow); transition: transform .18s var(--ease), border-color .18s var(--ease); }}
.card:hover {{ transform: translateY(-2px); border-color: var(--heading); }}
.card .value {{ font-size: var(--fs-value); font-weight: 700; color: var(--heading); }}
.card .label {{ font-size: 12px; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; margin-top: 6px; }}
.card.pass .value {{ color: var(--pass); }}
.card.fail .value {{ color: var(--fail); }}
.table-wrap {{ overflow-x: auto; margin: 15px 0; border-radius: var(--radius); border: 1px solid var(--border); }}
table {{ width: 100%; border-collapse: collapse; min-width: 640px; }}
thead th {{ position: sticky; top: 0; }}
th {{ background: var(--bg-elevated); color: var(--muted); padding: 9px 12px; text-align: left; font-size: 12px; text-transform: uppercase; letter-spacing: .05em; border-bottom: 1px solid var(--border); }}
td {{ padding: 9px 12px; border-bottom: 1px solid var(--border); font-size: 13px; }}
tr:nth-child(even) {{ background: var(--bg-card); }}
tr:hover {{ background: var(--bg-elevated); }}
.pass {{ color: var(--pass); }}
.fail {{ color: var(--fail); }}
.model-bar {{ display: flex; align-items: center; margin: 6px 0; }}
.model-name {{ width: 150px; font-size: 13px; }}
.model-bar-fill {{ height: 20px; border-radius: 4px; margin-left: 10px; min-width: 4px; animation: grow .8s var(--ease) both; transform-origin: left; }}
@keyframes grow {{ from {{ transform: scaleX(0); }} to {{ transform: scaleX(1); }} }}
.model-pct {{ margin-left: 10px; font-size: 12px; color: var(--muted); min-width: 48px; }}
.footer {{ margin-top: 32px; padding-top: 12px; border-top: 1px solid var(--border); font-size: 11px; color: var(--muted); }}
pre {{ background: var(--bg-card); padding: 12px; border-radius: var(--radius-sm); border: 1px solid var(--border); overflow-x: auto; font-size: 12px; }}
@media (prefers-reduced-motion: reduce) {{
  *, *::before, *::after {{ animation: none !important; transition: none !important; }}
}}
@media print {{
  .table-wrap table {{ min-width: 0; }}
  thead th {{ position: static; }}
  .card, body, .footer {{ box-shadow: none; }}
}}
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
    """Parse reports/audit.ledger, truncating long fields for display."""
    entries = []
    for e in load_ledger(path):
        entries.append({
            "run_id": e["run_id"],
            "model": e["model"],
            "prompt": e["prompt"][:60],
            "response": e["response"][:80],
            "latency": e["latency_ms"],
            "status": e["status"],
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
    table = f"<h2>{title}</h2><div class='table-wrap'><table><tr><th>Run</th><th>Model</th><th>Prompt</th><th>Response</th><th>Latency</th><th>Status</th></tr>"
    for e in entries[-50:]:
        status_class = "pass" if e["status"] == "PASS" else "fail"
        table += f"<tr><td>{e['run_id']}</td><td>{e['model']}</td><td>{e['prompt']}</td><td>{e['response']}</td><td>{e['latency']}ms</td><td class='{status_class}'>{e['status']}</td></tr>"
    table += "</table></div>"
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
