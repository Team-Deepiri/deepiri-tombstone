#!/usr/bin/env python3
"""
RAG Evaluation Suite for deepiri-tombstone.
Measures faithfulness, answer relevance, context recall, and context precision.
"""
import json, sys, os, subprocess, re, argparse

def call_ollama(model, prompt, host):
    payload = json.dumps({"model": model, "prompt": prompt, "stream": False})
    try:
        result = subprocess.run(
            ["curl", "-sf", "--max-time", "60", f"http://{host}/api/generate", "-d", payload],
            capture_output=True, text=True, timeout=70
        )
        if result.returncode != 0:
            return None
        resp = json.loads(result.stdout)
        return resp.get("response", "")
    except Exception:
        return None

def score_faithfulness(question, answer, context, model, host):
    """Check if answer is faithful to context (no hallucination)"""
    prompt = f"""Given the context and answer, rate faithfulness from 0.0 to 1.0.
Context: {context}
Question: {question}
Answer: {answer}

Does the answer contain claims NOT supported by the context?
Respond with ONLY a JSON: {{"faithfulness": 0.0-1.0, "unsupported_claims": ["..."]}}"""
    resp = call_ollama(model, prompt, host)
    if not resp:
        return {"faithfulness": 0.0, "unsupported_claims": ["error"]}
    m = re.search(r'\{[^}]+\}', resp, re.DOTALL)
    if m:
        try: return json.loads(m.group())
        except: pass
    return {"faithfulness": 0.0, "unsupported_claims": ["parse_error"]}

def score_answer_relevance(question, answer, model, host):
    """How relevant is the answer to the question?"""
    prompt = f"""Rate how relevant this answer is to the question from 0.0 to 1.0.
Question: {question}
Answer: {answer}
Respond with ONLY: {{"relevance": 0.0-1.0}}"""
    resp = call_ollama(model, prompt, host)
    if not resp:
        return {"relevance": 0.0}
    m = re.search(r'\{[^}]+\}', resp, re.DOTALL)
    if m:
        try: return json.loads(m.group())
        except: pass
    return {"relevance": 0.0}

def score_context_recall(question, context, model, host):
    """Does the context contain information needed to answer?"""
    prompt = f"""Rate how completely the context covers the information needed to answer from 0.0 to 1.0.
Question: {question}
Context: {context}
Respond with ONLY: {{"context_recall": 0.0-1.0, "missing_info": ["..."]}}"""
    resp = call_ollama(model, prompt, host)
    if not resp:
        return {"context_recall": 0.0, "missing_info": ["error"]}
    m = re.search(r'\{[^}]+\}', resp, re.DOTALL)
    if m:
        try: return json.loads(m.group())
        except: pass
    return {"context_recall": 0.0, "missing_info": ["parse_error"]}

def main():
    parser = argparse.ArgumentParser(description="RAG evaluation metrics")
    parser.add_argument("metric", choices=["faithfulness", "relevance", "recall", "all"])
    parser.add_argument("question", help="User question")
    parser.add_argument("answer", help="Model answer")
    parser.add_argument("context", nargs="?", default="", help="Retrieved context")
    parser.add_argument("-m", "--model", default=os.environ.get("DEEPIRI_TOMBSTONE_MODEL", "llama3.2"))
    args = parser.parse_args()
    host = os.environ.get("DEEPIRI_TOMBSTONE_HOST", "127.0.0.1:11434")
    results = {}
    if args.metric in ("faithfulness", "all"):
        results.update(score_faithfulness(args.question, args.answer, args.context, args.model, host))
    if args.metric in ("relevance", "all"):
        results.update(score_answer_relevance(args.question, args.answer, args.model, host))
    if args.metric in ("recall", "all"):
        results.update(score_context_recall(args.question, args.context, args.model, host))
    print(json.dumps(results, indent=2))
    if "faithfulness" in results and results.get("faithfulness", 1) < 0.5: sys.exit(1)
    if "relevance" in results and results.get("relevance", 1) < 0.3: sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
