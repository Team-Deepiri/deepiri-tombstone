#!/usr/bin/env python3
"""
Cost Analytics for deepiri-tombstone.
Track token usage and estimate costs across models.
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

MODEL_COSTS = {
    "llama3.2": {"input_per_1k": 0.0, "output_per_1k": 0.0, "notes": "local"},
    "llama3.1": {"input_per_1k": 0.0, "output_per_1k": 0.0, "notes": "local"},
    "llama3": {"input_per_1k": 0.0, "output_per_1k": 0.0, "notes": "local"},
    "mistral": {"input_per_1k": 0.0, "output_per_1k": 0.0, "notes": "local"},
    "phi3": {"input_per_1k": 0.0, "output_per_1k": 0.0, "notes": "local"},
    "gpt-4": {"input_per_1k": 0.03, "output_per_1k": 0.06, "notes": "openai"},
    "gpt-3.5-turbo": {"input_per_1k": 0.0015, "output_per_1k": 0.002, "notes": "openai"},
    # Anthropic rates are per 1M tokens upstream; divided by 1000 here.
    "claude-opus-5": {"input_per_1k": 0.005, "output_per_1k": 0.025, "notes": "anthropic"},
    "claude-sonnet-5": {"input_per_1k": 0.003, "output_per_1k": 0.015, "notes": "anthropic"},
    "claude-haiku-4-5": {"input_per_1k": 0.001, "output_per_1k": 0.005, "notes": "anthropic"},
}

def estimate_tokens(text):
    """Rough token estimation (~4 chars per token)"""
    return max(1, len(text) // 4)

def estimate_cost(model, input_text, output_text):
    pricing = MODEL_COSTS.get(model, {"input_per_1k": 0.0, "output_per_1k": 0.0})
    input_tokens = estimate_tokens(input_text) if input_text else 0
    output_tokens = estimate_tokens(output_text) if output_text else 0
    input_cost = input_tokens / 1000 * pricing["input_per_1k"]
    output_cost = output_tokens / 1000 * pricing["output_per_1k"]
    return {
        "model": model,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "total_tokens": input_tokens + output_tokens,
        "input_cost_usd": round(input_cost, 6),
        "output_cost_usd": round(output_cost, 6),
        "total_cost_usd": round(input_cost + output_cost, 6),
        "pricing": pricing,
    }

def analyze_ledger_costs(ledger_path, model_override=None):
    costs = []
    for entry in load_ledger(ledger_path):
        model = model_override or entry["model"]
        costs.append(estimate_cost(model, entry["prompt"], entry["response"]))
    return costs

def main():
    parser = argparse.ArgumentParser(description="Cost analytics")
    parser.add_argument("action", choices=["estimate", "ledger", "models", "config"], help="Action")
    parser.add_argument("-m", "--model", default="llama3.2", help="Model name")
    parser.add_argument("--prompt", help="Prompt text")
    parser.add_argument("--response", help="Response text")
    parser.add_argument("-f", "--file", help="File with prompt text")
    parser.add_argument("-l", "--ledger", default="reports/audit.ledger", help="Audit ledger path")
    parser.add_argument("--set-cost", nargs=3, metavar=("MODEL", "INPUT_COST", "OUTPUT_COST"), help="Set model cost")
    args = parser.parse_args()
    if args.action == "estimate":
        prompt = args.prompt
        if args.file and os.path.exists(args.file):
            with open(args.file) as f:
                prompt = f.read()
        if not prompt:
            prompt = "sample prompt text for estimation"
        response = args.response or "sample response text for estimation"
        result = estimate_cost(args.model, prompt, response)
        print(json.dumps(result, indent=2))
    elif args.action == "ledger":
        costs = analyze_ledger_costs(args.ledger)
        if not costs:
            print(f"No entries in {args.ledger} or file not found", file=sys.stderr)
            sys.exit(1)
        total_cost = sum(c["total_cost_usd"] for c in costs)
        total_tokens = sum(c["total_tokens"] for c in costs)
        summary = {
            "source": args.ledger,
            "entries": len(costs),
            "total_tokens": total_tokens,
            "total_cost_usd": round(total_cost, 6),
            "models": list(set(c["model"] for c in costs)),
            "per_entry": costs[:10],
        }
        print(json.dumps(summary, indent=2))
    elif args.action == "models":
        print(json.dumps(MODEL_COSTS, indent=2))
    elif args.action == "config":
        if args.set_cost:
            model, in_cost, out_cost = args.set_cost
            if model in MODEL_COSTS:
                MODEL_COSTS[model]["input_per_1k"] = float(in_cost)
                MODEL_COSTS[model]["output_per_1k"] = float(out_cost)
                print(f"Updated {model}: input=${in_cost}/1k, output=${out_cost}/1k", file=sys.stderr)
            else:
                print(f"Model {model} not in registry", file=sys.stderr)
                sys.exit(1)
        print(json.dumps(MODEL_COSTS, indent=2))

if __name__ == "__main__":
    main()
