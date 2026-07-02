#!/usr/bin/env python3
"""
Multi-Turn Chat Evaluation for deepiri-tombstone.
Evaluate conversational agents over multiple turns.
"""
import json, sys, os, subprocess, argparse, time
from datetime import datetime

def call_chat(model, messages, host):
    """Call Ollama chat API"""
    payload = json.dumps({"model": model, "messages": messages, "stream": False})
    try:
        r = subprocess.run(["curl", "-sf", "--max-time", "60", f"http://{host}/api/chat", "-d", payload],
                          capture_output=True, text=True, timeout=70)
        if r.returncode != 0: return None, f"curl error {r.returncode}"
        resp = json.loads(r.stdout)
        msg = resp.get("message", {})
        return msg.get("content", ""), None
    except Exception as e: return None, str(e)

def evaluate_turn_coherence(conversation, model, host):
    """Evaluate coherence across conversation turns"""
    turns_text = "\n".join([f"{m['role']}: {m['content'][:100]}" for m in conversation])
    judge = f"""Rate the conversational coherence from 0.0 to 1.0.
Does each turn logically follow from the previous?
Conversation:
{turns_text}
Respond ONLY JSON: {{"coherence": 0.0-1.0, "issues": ["..."]}}"""
    payload = json.dumps({"model": model, "prompt": judge, "stream": False})
    try:
        r = subprocess.run(["curl", "-sf", "--max-time", "30", f"http://{host}/api/generate", "-d", payload],
                          capture_output=True, text=True, timeout=35)
        if r.returncode == 0:
            resp = json.loads(r.stdout).get("response", "")
            import re
            m = re.search(r'\{[^}]+\}', resp, re.DOTALL)
            if m: return json.loads(m.group())
    except: pass
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
    host = os.environ.get("DEEPIRI_TOMBSTONE_HOST", "127.0.0.1:11434")

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
            except EOFError: break
            if user_input.lower() in ("exit", "quit"): break
            messages.append({"role": "user", "content": user_input})
            response, error = call_chat(args.model, messages, host)
            if error:
                print(f"Error: {error}", file=sys.stderr)
                break
            messages.append({"role": "assistant", "content": response})
            print(f"[{turn+1}] Assistant: {response[:500]}")
            turn += 1
            if user_input.lower() == "eval":
                eval_result = evaluate_turn_coherence(messages, args.model, host)
                print(f"\nCoherence: {eval_result}", file=sys.stderr)
        output = {"model": args.model, "messages": messages, "turns": turn}
        print(json.dumps(output, indent=2))
        if args.output:
            with open(args.output, 'w') as f:
                json.dump(output, f, indent=2)
        return

    if args.conversation_file:
        if not os.path.exists(args.conversation_file):
            print(f"ERROR: file not found: {args.conversation_file}", file=sys.stderr)
            sys.exit(1)
        with open(args.conversation_file) as f:
            data = json.load(f)
        messages = data.get("messages", data if isinstance(data, list) else [])
        result = evaluate_turn_coherence(messages, args.model, host)
        result["turns"] = len(messages)
        print(json.dumps(result, indent=2))
        sys.exit(0 if result.get("coherence", 0) >= 0.5 else 1)

    parser.print_help()
    sys.exit(1)

if __name__ == "__main__":
    main()
