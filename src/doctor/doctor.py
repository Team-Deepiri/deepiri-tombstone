#!/usr/bin/env python3
"""
Product health doctor — verify toolchain, bridge, Ollama, cache, fixtures.
Exit 0 only when the harness is ready to evaluate.
"""
import os
import sys

# Locate shared helpers (bin/ after make, or src/common/ in-tree).
_HERE = os.path.dirname(os.path.abspath(__file__))
for _cand in (_HERE, os.path.join(_HERE, "..", "common"), os.path.join(_HERE, "..", "..", "src", "common")):
    if os.path.isfile(os.path.join(_cand, "paths.py")):
        if _cand not in sys.path:
            sys.path.insert(0, _cand)
        break
from paths import ensure_common_path, read_version, repo_root  # noqa: E402
ensure_common_path(__file__)

import json
import shutil
import subprocess

from ollama_client import OllamaClient, cache_stats  # noqa: E402


def check(name, ok, detail=""):
    status = "PASS" if ok else "FAIL"
    print(f"  [{status}] {name}" + (f" — {detail}" if detail else ""))
    return 1 if ok else 0


def main():
    root = repo_root(__file__)
    print(f"deepiri-tombstone doctor (root={root})")
    passed = 0
    total = 0

    def run(name, ok, detail=""):
        nonlocal passed, total
        total += 1
        passed += check(name, ok, detail)

    ver = read_version(__file__)
    vpath = os.path.join(root, "VERSION")
    run("VERSION file", os.path.isfile(vpath), ver)

    core = os.path.join(root, "bin", "deepiri-tombstone-core")
    run("B core binary", os.path.isfile(core) and os.access(core, os.X_OK), core)

    runner = os.path.join(root, "bin", "runner")
    run("parallel runner", os.path.isfile(runner), runner)

    client_py = os.path.join(root, "bin", "ollama_client.py")
    if not os.path.isfile(client_py):
        client_py = os.path.join(root, "src", "common", "ollama_client.py")
    run("shared Ollama client", os.path.isfile(client_py), client_py)

    for tool in ("curl", "python3", "gcc"):
        run(f"toolchain {tool}", shutil.which(tool) is not None, shutil.which(tool) or "missing")

    if os.path.isfile(core):
        try:
            out = subprocess.check_output(["ldd", core], text=True, stderr=subprocess.DEVNULL)
            run("core links libcurl", "libcurl" in out, "keep-alive bridge")
        except Exception:
            run("core links libcurl", False, "ldd failed")

    fixture = os.environ.get("DEEPIRI_TOMBSTONE_FIXTURE", "fixtures/eval_prompts.txt")
    fpath = fixture if os.path.isabs(fixture) else os.path.join(root, fixture)
    run("default fixture", os.path.isfile(fpath), fpath)

    host = os.environ.get("DEEPIRI_TOMBSTONE_HOST", "127.0.0.1:11434")
    client = OllamaClient(host=host)
    ok = client.ping()
    run("Ollama reachable", ok, host)
    if ok:
        tags, err = client.tags()
        names = []
        if tags and "models" in tags:
            names = [m.get("name", "") for m in tags["models"]]
        run("Ollama models listed", not err, ", ".join(names[:5]) or (err or "none"))
        model = os.environ.get("DEEPIRI_TOMBSTONE_MODEL", "llama3.2")
        present = any(model in n for n in names)
        if present:
            run(f"default model available ({model})", True, "ok")
        else:
            print(f"  [WARN] default model ({model}) not in tags — pull with: ollama pull {model}")
    client.close()

    cs = cache_stats()
    run("response cache dir", True, f"{cs.get('dir')} ({cs.get('entries', 0)} entries)")

    reports = os.path.join(root, "reports")
    if not os.path.isdir(reports):
        os.makedirs(reports, exist_ok=True)
    run("reports/ writable", os.path.isdir(reports), reports)

    print()
    print(json.dumps({
        "version": ver,
        "passed": passed,
        "total": total,
        "ready": passed == total,
        "host": host,
        "jobs": os.environ.get("DEEPIRI_TOMBSTONE_JOBS", "4"),
        "cache_dir": cs.get("dir"),
    }, indent=2))
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
