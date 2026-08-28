#!/usr/bin/env python3
"""
Multi-Turn Chat Evaluation for deepiri-tombstone.
Evaluate conversational agents over multiple turns.
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
import argparse
import re
from datetime import datetime

from ollama_client import OllamaClient  # noqa: E402

def call_chat(client, model, messages):
    content, _, err = client.chat(model, messages)
    return content, err

def evaluate_turn_coherence(client, conversation, model):
    turns_text = "\n".join([f"{m['role']}: {m['content'][:100]}" for m in conversation])
    judge = f"""Rate the conversational coherence from 0.0 to 1.0.
Does each turn logically follow from the previous?
Conversation:
{turns_text}
Respond ONLY JSON: {{"coherence": 0.0-1.0, "issues": ["..."]}}"""
    resp, _, err, _ = client.generate(model, judge, use_cache=True)
    if err or not resp:
        return {"coherence": 0.5, "issues": ["eval_error"]}
    m = re.search(r"\{[^}]+\}", resp, re.DOTALL)
    if m:
        try:
            return json.loads(m.group())
        except json.JSONDecodeError:
            pass
    return {"coherence": 0.5, "issues": ["eval_error"]}

def main():
    parser = argparse.ArgumentParser(description="Multi-turn chat evaluation")
    parser.add_argument("conversation_file", nargs="?", help="Conversation JSON file")
    parser.add_argument("-m", "--model", default=os.environ.get("DEEPIRI_TOMBSTONE_MODEL", "llama3.2"))
    parser.add_argument("--interactive", action="store_true", help="Interactive chat session")
    parser.add_argument("--turns", type=int, default=5, help="Max turns (interactive)")
    parser.add_argument("--system", help="System prompt for interactive")
    parser.add_argument("-o", "--output", help="Output conversation log")
    args = parser.parse_args()
    client = OllamaClient()

    if args.interactive:
        print(f"Interactive chat with {args.model} (max {args.turns} turns)", file=sys.stderr)
        print("Type 'exit' to quit, 'eval' to evaluate", file=sys.stderr)
        messages = []
        if args.system:
            messages.append({"role": "system", "content": args.system})
        turn = 0
        while turn < args.turns:
            try:
                user_input = input(f"\n[{turn+1}] You: ")
            except EOFError:
                break
            if user_input.lower() in ("exit", "quit"):
                break
            messages.append({"role": "user", "content": user_input})
            response, error = call_chat(client, args.model, messages)
            if error:
                print(f"Error: {error}", file=sys.stderr)
                break
            messages.append({"role": "assistant", "content": response})
            print(f"[{turn+1}] Assistant: {(response or '')[:500]}")
            turn += 1
            if user_input.lower() == "eval":
                eval_result = evaluate_turn_coherence(client, messages, args.model)
                print(f"\nCoherence: {eval_result}", file=sys.stderr)
        output = {"model": args.model, "messages": messages, "turns": turn}
        print(json.dumps(output, indent=2))
        if args.output:
            with open(args.output, "w") as f:
                json.dump(output, f, indent=2)
        client.close()
        return

    if not args.conversation_file:
        parser.print_help()
        sys.exit(1)

    if not os.path.exists(args.conversation_file):
        print(f"ERROR: file not found: {args.conversation_file}", file=sys.stderr)
        sys.exit(1)

    with open(args.conversation_file) as f:
        data = json.load(f)
    messages = data if isinstance(data, list) else data.get("messages", [])
    coherence = evaluate_turn_coherence(client, messages, args.model)
    result = {
        "timestamp": datetime.now().isoformat(),
        "model": args.model,
        "turns": len([m for m in messages if m.get("role") == "user"]),
        "coherence": coherence,
    }
    print(json.dumps(result, indent=2))
    client.close()
    sys.exit(0 if coherence.get("coherence", 0) >= 0.5 else 1)

if __name__ == "__main__":
    main()
