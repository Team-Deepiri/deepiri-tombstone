#!/usr/bin/env python3
"""
Export results in JSON, CSV, Markdown, or HTML formats.
"""
import json, sys, os, argparse, csv, io
from datetime import datetime

def load_ledger(path):
    entries = []
    if not os.path.exists(path): return entries
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            parts = line.split('|')
            if len(parts) >= 6:
                entries.append({
                    "run_id": parts[0], "model": parts[1],
                    "prompt": parts[2], "response": parts[3],
                    "latency_ms": parts[4], "status": parts[5],
                })
    return entries

def load_stats(path):
    stats = []
    if not os.path.exists(path): return stats
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            parts = line.split()
            if len(parts) >= 4:
                stats.append({"latency_ms": parts[0], "length": parts[1], "pass": parts[2]})
    return stats

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
    html = f"""<!DOCTYPE html><html><head><meta charset="UTF-8"><title>deepiri-tombstone Export</title>
<style>body{{font-family:monospace;background:#0d1117;color:#c9d1d9;padding:20px}}
h1{{color:#58a6ff}}table{{width:100%;border-collapse:collapse}}
th{{background:#21262d;color:#8b949e;padding:8px;text-align:left;border:1px solid #30363d;font-size:12px}}
td{{padding:8px;border:1px solid #30363d;font-size:13px}}
tr:nth-child(even){{background:#161b22}}
.pass td:nth-child(5){{color:#3fb950}}
.fail td:nth-child(5){{color:#f85149}}
.summary{{display:flex;gap:20px;margin:20px 0}}
.card{{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:15px}}
.card .val{{font-size:24px;font-weight:bold;color:#58a6ff}}
.card .lbl{{font-size:11px;color:#8b949e}}
</style></head><body>
<h1>deepiri-tombstone Export</h1>
<p>Generated: {datetime.now().isoformat()}</p>
<div class="summary">
<div class="card"><div class="val">{len(entries)}</div><div class="lbl">Entries</div></div>
<div class="card"><div class="val">{rate}%</div><div class="lbl">Pass Rate</div></div>
<div class="card"><div class="val">{passes}</div><div class="lbl">Passed</div></div>
<div class="card"><div class="val">{len(entries) - passes}</div><div class="lbl">Failed</div></div>
</div>
<table><tr><th>Run ID</th><th>Model</th><th>Prompt</th><th>Latency</th><th>Status</th></tr>
{rows}</table></body></html>"""
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
