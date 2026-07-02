#!/usr/bin/env python3
"""
Checkpointing for deepiri-tombstone.
Save and restore evaluation state to resume interrupted runs.
"""
import json, sys, os, argparse
from datetime import datetime

class Checkpoint:
    def __init__(self, path):
        self.path = path
        self.data = {"timestamp": None, "model": "", "fixture": "", "completed": [], "remaining": [], "results": {}}

    def save(self):
        self.data["timestamp"] = datetime.now().isoformat()
        os.makedirs(os.path.dirname(self.path) or ".", exist_ok=True)
        with open(self.path, 'w') as f:
            json.dump(self.data, f, indent=2)

    def load(self):
        if os.path.exists(self.path):
            with open(self.path) as f:
                self.data = json.load(f)
            return True
        return False

    def init_from_fixture(self, fixture_path, model):
        prompts = []
        with open(fixture_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'): continue
                if '|' in line:
                    p, k = line.split('|', 1)
                    prompts.append((p.strip(), k.strip()))
                else:
                    prompts.append((line.strip(), ''))
        self.data = {
            "timestamp": datetime.now().isoformat(),
            "model": model,
            "fixture": fixture_path,
            "completed": [],
            "remaining": [{"prompt": p, "keyword": k} for p, k in prompts],
            "results": {},
        }

    def mark_completed(self, idx, result):
        if idx < len(self.data["remaining"]):
            item = self.data["remaining"][idx]
            self.data["completed"].append(item)
            self.data["results"][item["prompt"]] = result
            self.data["remaining"] = [r for i, r in enumerate(self.data["remaining"]) if i != idx]

    def get_progress(self):
        total = len(self.data["completed"]) + len(self.data["remaining"])
        done = len(self.data["completed"])
        return done, total, round(done / total * 100, 1) if total > 0 else 0

def main():
    parser = argparse.ArgumentParser(description="Evaluation checkpointing")
    parser.add_argument("action", choices=["save", "load", "status", "init", "clear"])
    parser.add_argument("-f", "--fixture", help="Fixture path (for init)")
    parser.add_argument("-m", "--model", help="Model name (for init)")
    parser.add_argument("-c", "--checkpoint", default="reports/checkpoint.json", help="Checkpoint file")
    parser.add_argument("--completed-idx", type=int, help="Index of completed item")
    parser.add_argument("--result", help="Result JSON for completed item")
    args = parser.parse_args()

    cp = Checkpoint(args.checkpoint)

    if args.action == "init":
        if not args.fixture:
            print("ERROR: --fixture required for init", file=sys.stderr)
            sys.exit(1)
        cp.init_from_fixture(args.fixture, args.model or os.environ.get("DEEPIRI_TOMBSTONE_MODEL", "llama3.2"))
        cp.save()
        print(f"Checkpoint initialized: {len(cp.data['remaining'])} items", file=sys.stderr)
        print(json.dumps(cp.data, indent=2))

    elif args.action == "save":
        cp.load()
        if not cp.data["remaining"] and not cp.data["completed"]:
            print("ERROR: no checkpoint data. Use 'init' first.", file=sys.stderr)
            sys.exit(1)
        cp.save()
        done, total, pct = cp.get_progress()
        print(f"Checkpoint saved: {done}/{total} ({pct}%)", file=sys.stderr)

    elif args.action == "load":
        if cp.load():
            done, total, pct = cp.get_progress()
            print(json.dumps(cp.data, indent=2))
            print(f"Checkpoint loaded: {done}/{total} ({pct}%)", file=sys.stderr)
        else:
            print(f"No checkpoint found at {args.checkpoint}", file=sys.stderr)
            sys.exit(1)

    elif args.action == "status":
        if cp.load():
            done, total, pct = cp.get_progress()
            print(f"Checkpoint: {args.checkpoint}")
            print(f"Progress: {done}/{total} ({pct}%)")
            print(f"Model: {cp.data.get('model', '?')}")
            print(f"Fixture: {cp.data.get('fixture', '?')}")
            print(f"Last saved: {cp.data.get('timestamp', '?')}")
        else:
            print(f"No checkpoint found", file=sys.stderr)

    elif args.action == "clear":
        if os.path.exists(args.checkpoint):
            os.remove(args.checkpoint)
            print(f"Checkpoint cleared: {args.checkpoint}", file=sys.stderr)

if __name__ == "__main__":
    main()
