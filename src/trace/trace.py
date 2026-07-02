#!/usr/bin/env python3
"""
Span Tracing for deepiri-tombstone.
Records timing spans for each pipeline stage and provides trace visualization.
"""
import json, sys, os, time, argparse, uuid
from datetime import datetime
from collections import defaultdict

class Tracer:
    def __init__(self):
        self.trace_id = str(uuid.uuid4())[:8]
        self.spans = []
        self._stack = []

    def start_span(self, name, metadata=None):
        span = {
            "trace_id": self.trace_id,
            "span_id": str(uuid.uuid4())[:8],
            "parent_id": self._stack[-1] if self._stack else None,
            "name": name,
            "start_time": time.time(),
            "metadata": metadata or {},
        }
        self._stack.append(span["span_id"])
        self.spans.append(span)
        return span["span_id"]

    def end_span(self, span_id=None, end_metadata=None):
        if span_id:
            for span in reversed(self.spans):
                if span["span_id"] == span_id:
                    span["end_time"] = time.time()
                    span["duration_ms"] = round((span["end_time"] - span["start_time"]) * 1000, 2)
                    if end_metadata:
                        span["metadata"].update(end_metadata)
                    if self._stack and self._stack[-1] == span_id:
                        self._stack.pop()
                    return span
        elif self._stack:
            sid = self._stack.pop()
            return self.end_span(sid)
        return None

    def to_json(self):
        return {
            "trace_id": self.trace_id,
            "timestamp": datetime.now().isoformat(),
            "spans": self.spans,
            "total_duration_ms": self._compute_total(),
        }

    def _compute_total(self):
        if not self.spans:
            return 0
        started = [s for s in self.spans if "start_time" in s]
        ended = [s for s in self.spans if "duration_ms" in s]
        if ended:
            return sum(s["duration_ms"] for s in ended)
        return 0

    def print_tree(self):
        """Print trace tree"""
        span_map = {s["span_id"]: s for s in self.spans}
        children = defaultdict(list)
        for s in self.spans:
            p = s.get("parent_id")
            if p:
                children[p].append(s["span_id"])

        def print_node(sid, depth=0):
            s = span_map.get(sid)
            if not s:
                return
            prefix = "  " * depth + "└─ " if depth > 0 else ""
            dur = s.get("duration_ms", "?")
            print(f"{prefix}{s['name']} ({dur}ms)")
            for cid in children.get(sid, []):
                print_node(cid, depth + 1)

        roots = [s for s in self.spans if not s.get("parent_id")]
        for r in roots:
            print_node(r["span_id"])

def trace_pipeline(tracer, stage_name, cmd_func, *args, **kwargs):
    """Run a pipeline stage with tracing"""
    sid = tracer.start_span(stage_name, {"args": str(args)})
    try:
        result = cmd_func(*args, **kwargs)
        tracer.end_span(sid, {"result": str(result)[:100]})
        return result
    except Exception as e:
        tracer.end_span(sid, {"error": str(e)})
        raise

def main():
    parser = argparse.ArgumentParser(description="Span tracing for deepiri-tombstone")
    parser.add_argument("action", nargs="?", choices=["start", "view", "list"],
                        default="start", help="Trace action")
    parser.add_argument("trace_file", nargs="?", help="Trace JSON file to view")
    parser.add_argument("-o", "--output", default="reports/trace.json", help="Output trace file")
    args = parser.parse_args()

    if args.action == "view" or args.action == "list":
        trace_path = args.trace_file or args.output
        if not os.path.exists(trace_path):
            print(f"No trace file found: {trace_path}")
            print("Run evaluation first with tracing enabled.")
            sys.exit(1)
        with open(trace_path) as f:
            trace_data = json.load(f)
        print(f"Trace: {trace_data['trace_id']}")
        print(f"Timestamp: {trace_data['timestamp']}")
        print(f"Total duration: {trace_data['total_duration_ms']}ms")
        print(f"Spans: {len(trace_data['spans'])}")
        print()
        # Rebuild tree
        span_map = {s["span_id"]: s for s in trace_data["spans"]}
        children = defaultdict(list)
        for s in trace_data["spans"]:
            p = s.get("parent_id")
            if p:
                children[p].append(s["span_id"])
        def print_node(sid, depth=0):
            s = span_map.get(sid)
            if not s:
                return
            prefix = "  " * depth + "└─ " if depth > 0 else ""
            dur = s.get("duration_ms", "?")
            name = s["name"]
            extra = ""
            if "metadata" in s and s["metadata"]:
                meta = s["metadata"]
                if "result" in meta:
                    extra = f" → {meta['result'][:60]}"
            print(f"{prefix}{name} ({dur}ms){extra}")
            for cid in children.get(sid, []):
                print_node(cid, depth + 1)
        roots = [s for s in trace_data["spans"] if not s.get("parent_id")]
        for r in roots:
            print_node(r["span_id"])
        return

    # Start new trace
    tracer = Tracer()
    trace_data = tracer.to_json()
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, 'w') as f:
        json.dump(trace_data, f, indent=2)
    print(tracer.trace_id)

if __name__ == "__main__":
    main()
