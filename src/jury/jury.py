#!/usr/bin/env python3
"""
Multi-Juror Consensus Panel for deepiri-tombstone.
Deploys multiple judge models, collects scores, reaches consensus.
"""
import json
import sys
import os
import argparse
import re
from concurrent.futures import ThreadPoolExecutor, as_completed

_HERE = os.path.dirname(os.path.abspath(__file__))
for _cand in (_HERE, os.path.join(_HERE, "..", "common"), os.path.join(_HERE, "..", "..", "src", "common")):
    if os.path.exists(os.path.join(_cand, "ollama_client.py")):
        sys.path.insert(0, _cand)
        break

from ollama_client import OllamaClient  # noqa: E402

JUROR_CRITERIA = {
    "relevance": "How relevant and on-topic is the response?",
    "coherence": "How coherent and well-structured?",
    "accuracy": "How factually accurate?",
    "completeness": "How complete and thorough?",
}


def call_judge(client, juror_model, prompt, response, use_cache):
    judge_prompt = f"""You are juror '{juror_model}'. Score this response 1-5.
Prompt: {prompt}
Response: {response}
Criteria:
"""
    for k, v in JUROR_CRITERIA.items():
        judge_prompt += f"- {k}: {v}\n"
    judge_prompt += (
        '\nReturn ONLY JSON: '
        '{"relevance":N,"coherence":N,"accuracy":N,"completeness":N,"rationale":"..."}'
    )
    text, _, err, _ = client.generate(juror_model, judge_prompt, use_cache=use_cache)
    if err or not text:
        return None
    m = re.search(r"\{[^}]+\}", text, re.DOTALL)
    if m:
        try:
            return json.loads(m.group())
        except json.JSONDecodeError:
            return None
    return None


def compute_consensus(scores_list):
    if not scores_list:
        return {}
    criteria_keys = list(JUROR_CRITERIA.keys())
    result = {}
    for k in criteria_keys:
        vals = [s.get(k, 0) for s in scores_list if s and isinstance(s.get(k), (int, float))]
        if vals:
            mean = sum(vals) / len(vals)
            result[k] = round(mean, 2)
            result[f"{k}_min"] = min(vals)
            result[f"{k}_max"] = max(vals)
            result[f"{k}_std"] = round((sum((v - mean) ** 2 for v in vals) / len(vals)) ** 0.5, 2)
    overalls = [result[k] for k in criteria_keys if k in result]
    if overalls:
        result["overall"] = round(sum(overalls) / len(overalls), 2)
    result["jurors"] = len(scores_list)
    result["consensus"] = (
        "high" if result.get("overall", 0) >= 4.0
        else "medium" if result.get("overall", 0) >= 3.0
        else "low"
    )
    return result


def main():
    parser = argparse.ArgumentParser(description="Multi-juror consensus panel")
    parser.add_argument("prompt", help="User prompt")
    parser.add_argument("response", help="Model response to evaluate")
    parser.add_argument("-j", "--jurors", nargs="+", default=["llama3.2"],
                        help="Juror models (space-separated)")
    parser.add_argument("--no-cache", action="store_true")
    args = parser.parse_args()
    if args.no_cache:
        os.environ["DEEPIRI_TOMBSTONE_NO_CACHE"] = "1"

    client = OllamaClient()
    scores_list = []
    with ThreadPoolExecutor(max_workers=len(args.jurors)) as ex:
        futures = {
            ex.submit(call_judge, client, m, args.prompt, args.response, not args.no_cache): m
            for m in args.jurors
        }
        for f in as_completed(futures):
            m = futures[f]
            try:
                s = f.result()
                if s:
                    scores_list.append(s)
                    print(f"  {m}: overall={s.get('relevance', 0)}", file=sys.stderr)
                else:
                    print(f"  {m}: FAILED", file=sys.stderr)
            except Exception as e:
                print(f"  {m}: error={e}", file=sys.stderr)
    client.close()
    result = compute_consensus(scores_list)
    print(json.dumps(result, indent=2))
    sys.exit(0 if result.get("overall", 0) >= 3.0 else 1)


if __name__ == "__main__":
    main()
