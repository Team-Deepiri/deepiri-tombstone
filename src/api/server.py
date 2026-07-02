#!/usr/bin/env python3
"""
REST API Server for deepiri-tombstone.
Zero-dependency HTTP API for running evaluations programmatically.
"""
import json, sys, os, subprocess, argparse, http.server, urllib.parse, threading, time
from datetime import datetime

HOST = os.environ.get("DEEPIRI_TOMBSTONE_HOST", "127.0.0.1:11434")
MODEL = os.environ.get("DEEPIRI_TOMBSTONE_MODEL", "llama3.2")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def call_ollama(prompt, model=None):
    m = model or MODEL
    payload = json.dumps({"model": m, "prompt": prompt, "stream": False})
    try:
        r = subprocess.run(["curl", "-sf", "--max-time", "60", f"http://{HOST}/api/generate", "-d", payload],
                          capture_output=True, text=True, timeout=70)
        if r.returncode != 0: return None, f"curl error {r.returncode}"
        resp = json.loads(r.stdout)
        return resp.get("response", ""), None
    except Exception as e: return None, str(e)

class APIHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        sys.stderr.write(f"[API] {self.address_string()} - {format % args}\n")

    def _json_response(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length == 0: return {}
        body = self.rfile.read(length)
        try: return json.loads(body)
        except: return {"text": body.decode()}

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path.rstrip("/")
        if path == "/api/health":
            self._json_response({"status": "ok", "host": HOST, "model": MODEL, "timestamp": datetime.now().isoformat()})
        elif path == "/api/v1/models":
            r, err = call_ollama("List available models")
            try:
                result = subprocess.run(["curl", "-sf", f"http://{HOST}/api/tags"], capture_output=True, text=True, timeout=10)
                models = json.loads(result.stdout) if result.returncode == 0 else {"models": []}
                self._json_response(models)
            except: self._json_response({"models": [{"name": MODEL}]})
        elif path.startswith("/api/v1/stats"):
            stats_path = os.path.join(ROOT, "..", "reports", "stats.dat")
            if os.path.exists(stats_path):
                with open(stats_path) as f:
                    lines = f.readlines()
                self._json_response({"entries": len(lines), "file": stats_path})
            else: self._json_response({"entries": 0, "file": stats_path})
        else:
            self._json_response({"error": "not found", "paths": ["/api/health", "/api/v1/models", "/api/v1/stats", "/api/v1/evaluate"]}, 404)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path.rstrip("/")
        if path == "/api/v1/evaluate":
            body = self._read_body()
            prompt = body.get("prompt", body.get("text", ""))
            model = body.get("model", MODEL)
            if not prompt:
                self._json_response({"error": "prompt required"}, 400)
                return
            start = time.time()
            response, error = call_ollama(prompt, model)
            elapsed_ms = int((time.time() - start) * 1000)
            if error:
                self._json_response({"error": error, "prompt": prompt, "model": model, "latency_ms": elapsed_ms}, 500)
            else:
                self._json_response({
                    "prompt": prompt, "model": model, "response": response,
                    "latency_ms": elapsed_ms, "timestamp": datetime.now().isoformat(),
                })
        elif path == "/api/v1/benchmark":
            body = self._read_body()
            fixture = body.get("fixture", "fixtures/eval_prompts.txt")
            models = body.get("models", [MODEL])
            results = {}
            for m in models:
                passes = 0
                total = 0
                fixture_path = os.path.join(ROOT, "..", fixture) if not os.path.isabs(fixture) else fixture
                if os.path.exists(fixture_path):
                    with open(fixture_path) as f:
                        for line in f:
                            line = line.strip()
                            if not line or line.startswith("#"): continue
                            total += 1
                            p = line.split("|")[0] if "|" in line else line
                            resp, _ = call_ollama(p, m)
                            if resp: passes += 1
                results[m] = {"passes": passes, "total": total, "pass_rate": round(passes/total*100, 1) if total > 0 else 0}
            self._json_response({"models": results, "fixture": fixture, "timestamp": datetime.now().isoformat()})
        else:
            self._json_response({"error": "not found"}, 404)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

def main():
    parser = argparse.ArgumentParser(description="REST API server for deepiri-tombstone")
    parser.add_argument("--port", type=int, default=8080, help="Server port")
    parser.add_argument("--host", default="127.0.0.1", help="Bind address")
    args = parser.parse_args()
    server = http.server.HTTPServer((args.host, args.port), APIHandler)
    print(f"deepiri-tombstone API server: http://{args.host}:{args.port}", file=sys.stderr)
    print(f"  Health: http://{args.host}:{args.port}/api/health", file=sys.stderr)
    print(f"  Evaluate: POST /api/v1/evaluate", file=sys.stderr)
    print(f"  Benchmark: POST /api/v1/benchmark", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...", file=sys.stderr)
        server.shutdown()

if __name__ == "__main__":
    main()
