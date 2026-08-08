#!/usr/bin/env python3
"""
Export results in JSON, CSV, Markdown, or HTML formats.
"""
import json, sys, os, argparse, csv, io
from datetime import datetime

# Installed beside this script in bin/, or under src/common/ when run in tree.
_HERE = os.path.dirname(os.path.abspath(__file__))
for _cand in (_HERE, os.path.join(_HERE, "..", "..", "src", "common")):
    if os.path.exists(os.path.join(_cand, "ledger.py")):
        sys.path.insert(0, _cand)
        break
from ledger import load_ledger, load_stats

def export_json(entries, stats, output):
    data = {
        "timestamp": datetime.now().isoformat(),
        "entries": entries,
        "stats": stats,
    }
    if output:
        with open(output, 'w') as f:
            json.dump(data, f, indent=2)
    print(json.dumps(data, indent=2))

def export_csv(entries, stats, output):
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["run_id", "model", "prompt", "response", "latency_ms", "status"])
    for e in entries:
        writer.writerow([e["run_id"], e["model"], e["prompt"], e["response"], e["latency_ms"], e["status"]])
    csv_out = out.getvalue()
    if output:
        with open(output, 'w') as f:
            f.write(csv_out)
    print(csv_out)

def export_markdown(entries, stats, output):
    md = f"# Evaluation Report\n\nGenerated: {datetime.now().isoformat()}\n\n"
    md += "## Summary\n\n"
    passes = sum(1 for e in entries if e["status"] == "PASS")
    md += f"- Total: {len(entries)}\n- Passed: {passes}\n- Failed: {len(entries) - passes}\n"
    md += f"- Pass rate: {round(passes / max(len(entries), 1) * 100, 1)}%\n\n"
    md += "## Results\n\n"
    md += "| Run ID | Model | Prompt | Latency | Status |\n"
    md += "|--------|-------|--------|---------|--------|\n"
    for e in entries[-20:]:
        md += f"| {e['run_id']} | {e['model']} | {e['prompt'][:40]}... | {e['latency_ms']}ms | {e['status']} |\n"
    if output:
        with open(output, 'w') as f:
            f.write(md)
    print(md)

def export_html(entries, stats, output):
    passes = sum(1 for e in entries if e["status"] == "PASS")
    rate = round(passes / max(len(entries), 1) * 100, 1)
    rows = ""
    for e in entries[-30:]:
        cls = "pass" if e["status"] == "PASS" else "fail"
        rows += f"<tr class='{cls}'><td>{e['run_id']}</td><td>{e['model']}</td><td>{e['prompt'][:50]}</td><td>{e['latency_ms']}ms</td><td>{e['status']}</td></tr>\n"
    html = f"""<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>deepiri-tombstone Export</title>
<style>
:root{{color-scheme:light dark;--bg:#0d1117;--card:#161b22;--elevated:#1c2128;--border:#30363d;--text:#c9d1d9;--muted:#8b949e;--heading:#58a6ff;--pass:#3fb950;--fail:#f85149;--radius:10px}}
@media (prefers-color-scheme: light){{:root{{--bg:#f6f8fa;--card:#fff;--elevated:#eef1f4;--border:#d0d7de;--text:#24292f;--muted:#57606a;--heading:#0969da;--pass:#1a7f37;--fail:#cf222e}}}}
body{{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;background:var(--bg);color:var(--text);padding:clamp(16px,3vw,32px);line-height:1.55}}
h1{{color:var(--heading);border-bottom:1px solid var(--border);padding-bottom:12px;font-size:clamp(1.4rem,1rem+2vw,2rem)}}
.summary{{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:14px;margin:20px 0}}
.card{{background:var(--card);border:1px solid var(--border);border-radius:var(--radius);padding:15px;box-shadow:0 8px 24px rgba(0,0,0,.25)}}
.card .val{{font-size:clamp(22px,3vw,28px);font-weight:700;color:var(--heading)}}
.card .lbl{{font-size:11px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em;margin-top:4px}}
.table-wrap{{overflow-x:auto;border:1px solid var(--border);border-radius:var(--radius)}}
table{{width:100%;border-collapse:collapse;min-width:520px}}
th{{background:var(--elevated);color:var(--muted);padding:9px 10px;text-align:left;border-bottom:1px solid var(--border);font-size:12px;text-transform:uppercase;letter-spacing:.05em}}
td{{padding:9px 10px;border-bottom:1px solid var(--border);font-size:13px}}
tr:nth-child(even){{background:var(--card)}}
tr:hover{{background:var(--elevated)}}
.pass td:nth-child(5){{color:var(--pass);font-weight:600}}
.fail td:nth-child(5){{color:var(--fail);font-weight:600}}
@media (prefers-reduced-motion: reduce){{*{{transition:none}}}}
@media print{{.summary{{grid-template-columns:repeat(4,1fr)}}.table-wrap{{border:none}}.card{{box-shadow:none}}}}
</style></head><body>
<h1>deepiri-tombstone Export</h1>
<p>Generated: {datetime.now().isoformat()}</p>
<div class="summary">
<div class="card"><div class="val">{len(entries)}</div><div class="lbl">Entries</div></div>
<div class="card"><div class="val">{rate}%</div><div class="lbl">Pass Rate</div></div>
<div class="card"><div class="val">{passes}</div><div class="lbl">Passed</div></div>
<div class="card"><div class="val">{len(entries) - passes}</div><div class="lbl">Failed</div></div>
</div>
<div class="table-wrap"><table><tr><th>Run ID</th><th>Model</th><th>Prompt</th><th>Latency</th><th>Status</th></tr>
{rows}</table></div></body></html>"""
    if output:
        with open(output, 'w') as f:
            f.write(html)
    print(html)

EXPORTERS = {
    "json": export_json,
    "csv": export_csv,
    "md": export_markdown,
    "html": export_html,
}

def main():
    parser = argparse.ArgumentParser(description="Export evaluation results")
    parser.add_argument("format", choices=list(EXPORTERS.keys()), help="Export format")
    parser.add_argument("-o", "--output", help="Output file")
    parser.add_argument("--ledger", default="reports/audit.ledger", help="Audit ledger path")
    parser.add_argument("--stats", default="reports/stats.dat", help="Stats file path")
    args = parser.parse_args()
    entries = load_ledger(args.ledger)
    stats = load_stats(args.stats)
    if not entries:
        print("No entries found in ledger", file=sys.stderr)
        sys.exit(1)
    EXPORTERS[args.format](entries, stats, args.output)

if __name__ == "__main__":
    main()
