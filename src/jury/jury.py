#!/usr/bin/env python3
"""
Multi-Juror Consensus Panel for deepiri-tombstone.
Deploys multiple judge models, collects scores, reaches consensus.
"""
import json, sys, os, subprocess, argparse, re
from concurrent.futures import ThreadPoolExecutor, as_completed

JUROR_CRITERIA = {
    "relevance": "How relevant and on-topic is the response?",
    "coherence": "How coherent and well-structured?",
    "accuracy": "How factually accurate?",
    "completeness": "How complete and thorough?",
}

def call_judge(juror_model, prompt, response, host):
    judge_prompt = f"""You are juror '{juror_model}'. Score this response 1-5.
Prompt: {prompt}
Response: {response}
Criteria:
"""
    for k, v in JUROR_CRITERIA.items():
        judge_prompt += f"- {k}: {v}\n"
    judge_prompt += "\nReturn ONLY JSON: {\"relevance\":N,\"coherence\":N,\"accuracy\":N,\"completeness\":N,\"rationale\":\"...\"}"
    payload = json.dumps({"model": juror_model, "prompt": judge_prompt, "stream": False})
    try:
        r = subprocess.run(["curl", "-sf", "--max-time", "60", f"http://{host}/api/generate", "-d", payload],
                          capture_output=True, text=True, timeout=70)
        if r.returncode != 0: return None
        resp = json.loads(r.stdout).get("response", "")
        m = re.search(r'\{[^}]+\}', resp, re.DOTALL)
        if m: return json.loads(m.group())
    except: pass
    return None

def compute_consensus(scores_list):
    if not scores_list: return {}
    criteria_keys = list(JUROR_CRITERIA.keys())
    result = {}
    for k in criteria_keys:
        vals = [s.get(k, 0) for s in scores_list if s and isinstance(s.get(k), (int, float))]
        if vals:
            result[k] = round(sum(vals) / len(vals), 2)
            result[f"{k}_min"] = min(vals)
            result[f"{k}_max"] = max(vals)
            result[f"{k}_std"] = round((sum((v - sum(vals)/len(vals))**2 for v in vals) / len(vals))**0.5, 2)
    overalls = [result[k] for k in criteria_keys if k in result]
    if overalls:
        result["overall"] = round(sum(overalls) / len(overalls), 2)
    result["jurors"] = len(scores_list)
    result["consensus"] = "high" if result.get("overall", 0) >= 4.0 else "medium" if result.get("overall", 0) >= 3.0 else "low"
    return result

def main():
    parser = argparse.ArgumentParser(description="Multi-juror consensus panel")
    parser.add_argument("prompt", help="User prompt")
    parser.add_argument("response", help="Model response to evaluate")
    parser.add_argument("-j", "--jurors", nargs="+", default=["llama3.2"],
                        help="Juror models (space-separated)")
    args = parser.parse_args()
    host = os.environ.get("DEEPIRI_TOMBSTONE_HOST", "127.0.0.1:11434")
    scores_list = []
    with ThreadPoolExecutor(max_workers=len(args.jurors)) as ex:
        futures = {ex.submit(call_judge, m, args.prompt, args.response, host): m for m in args.jurors}
        for f in as_completed(futures):
            m = futures[f]
            try:
                s = f.result()
                if s:
                    scores_list.append(s)
                    print(f"  {m}: overall={s.get('relevance',0)}", file=sys.stderr)
                else:
                    print(f"  {m}: FAILED", file=sys.stderr)
            except Exception as e:
                print(f"  {m}: error={e}", file=sys.stderr)
    result = compute_consensus(scores_list)
    print(json.dumps(result, indent=2))
    sys.exit(0 if result.get("overall", 0) >= 3.0 else 1)

if __name__ == "__main__":
    main()
