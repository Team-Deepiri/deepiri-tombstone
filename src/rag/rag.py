#!/usr/bin/env python3
"""
RAG Evaluation Suite for deepiri-tombstone.
Measures faithfulness, answer relevance, context recall, and context precision.
"""
import json, sys, os, re, argparse

_HERE = os.path.dirname(os.path.abspath(__file__))
for _cand in (_HERE, os.path.join(_HERE, "..", "common"), os.path.join(_HERE, "..", "..", "src", "common")):
    if os.path.exists(os.path.join(_cand, "ollama_client.py")):
        sys.path.insert(0, _cand)
        break
from ollama_client import OllamaClient  # noqa: E402

_CLIENT = None

def _client(host=None):
    global _CLIENT
    if _CLIENT is None:
        _CLIENT = OllamaClient(host=host) if host else OllamaClient()
    return _CLIENT

def call_ollama(model, prompt, host):
    text, _, err, _ = _client(host).generate(model, prompt, use_cache=True)
    return None if err else text

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
