#!/usr/bin/env python3
"""
Synthetic Dataset Generator for deepiri-tombstone.
Expands seed prompts into larger test sets using Ollama.
"""
import json, sys, os, random, argparse, re
from datetime import datetime

_HERE = os.path.dirname(os.path.abspath(__file__))
for _cand in (_HERE, os.path.join(_HERE, "..", "common"), os.path.join(_HERE, "..", "..", "src", "common")):
    if os.path.exists(os.path.join(_cand, "ollama_client.py")):
        sys.path.insert(0, _cand)
        break
from ollama_client import OllamaClient  # noqa: E402

random.seed(42)

def load_seeds(path):
    seeds = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '|' in line:
                prompt, keyword = line.split('|', 1)
                seeds.append((prompt.strip(), keyword.strip()))
            else:
                seeds.append((line.strip(), ''))
    return seeds

def generate_variants(seed_prompt, seed_keyword, count, model, host):
    """Use Ollama to generate semantic variants of a seed prompt."""
    system_prompt = f"""You are a test data generator. Given a prompt, generate {count} semantically similar but distinct variants.
Each variant should test the same capability but use different wording, structure, or framing.

Original prompt: "{seed_prompt}"

Generate {count} variants. For each variant, also provide an expected keyword to check in the response.
Output format (one per line):
VARIANT: <variant prompt> | KEYWORD: <expected keyword>

Make variants diverse: change the question format, add context, rephrase, or adjust difficulty."""

    try:
        raw, _, err, _ = OllamaClient(host=host).generate(model, system_prompt, use_cache=True)
        if err or not raw:
            return []

        variants = []
        for line in raw.split('\n'):
            line = line.strip()
            m = re.search(r'VARIANT:\s*(.+?)(?:\s*\|\s*KEYWORD:\s*(.+))?$', line, re.IGNORECASE)
            if m:
                variant_prompt = m.group(1).strip().strip('"\'')
                variant_keyword = m.group(2).strip().strip('"\'') if m.group(2) else seed_keyword
                if variant_prompt and len(variant_prompt) > 5:
                    variants.append((variant_prompt, variant_keyword))
            # Also try simpler format: just lines with pipes
            elif '|' in line and not line.startswith('#'):
                parts = line.split('|', 1)
                p = parts[0].strip().strip('"\'')
                k = parts[1].strip().strip('"\'') if len(parts) > 1 else seed_keyword
                if p and p != seed_prompt and len(p) > 5:
                    variants.append((p, k))

        return variants[:count]
    except Exception:
        return []

def generate_rule_based(seed_prompt, seed_keyword, count):
    """Generate rule-based variants without calling an LLM."""
    variants = []
    templates = [
        "What is {}?",
        "Tell me about {}",
        "Define: {}",
        "Explain {}",
        "I need to know about {}",
        "Can you tell me {}?",
        "Respond with: {}",
        "Answer the following: {}",
        "Question: {}",
        "{} - respond now",
    ]

    for i in range(min(count, len(templates))):
        variant = templates[i].format(seed_prompt.lower().rstrip('?.').strip())
        variants.append((variant, seed_keyword))

    return variants

def main():
    parser = argparse.ArgumentParser(description="Generate synthetic evaluation datasets")
    parser.add_argument("seed_file", help="Seed fixture file (PROMPT|KEYWORD format)")
    parser.add_argument("-n", "--count", type=int, default=5, help="Variants per seed prompt")
    parser.add_argument("-m", "--model", default=os.environ.get("DEEPIRI_TOMBSTONE_MODEL", "llama3.2"),
                        help="Model for generation")
    parser.add_argument("-o", "--output", help="Output fixture file")
    parser.add_argument("--rule-based", action="store_true",
                        help="Use rule-based generation instead of LLM")
    args = parser.parse_args()

    if not os.path.exists(args.seed_file):
        print(f"ERROR: seed file not found: {args.seed_file}", file=sys.stderr)
        sys.exit(1)

    seeds = load_seeds(args.seed_file)
    if not seeds:
        print("ERROR: no seeds found", file=sys.stderr)
        sys.exit(1)

    host = os.environ.get("DEEPIRI_TOMBSTONE_HOST", "127.0.0.1:11434")
    all_variants = []
    errors = 0

    for i, (prompt, keyword) in enumerate(seeds):
        print(f"Processing seed {i+1}/{len(seeds)}: {prompt[:50]}...", file=sys.stderr)

        if args.rule_based:
            variants = generate_rule_based(prompt, keyword, args.count)
        else:
            variants = generate_variants(prompt, keyword, args.count, args.model, host)

        if not variants:
            variants = generate_rule_based(prompt, keyword, max(1, args.count // 2))
            errors += 1

        for v_prompt, v_keyword in variants:
            all_variants.append((v_prompt, v_keyword))

    output_lines = [
        f"# Synthetic dataset generated by synth.py",
        f"# Source: {args.seed_file}",
        f"# Generated: {datetime.now().isoformat()}",
        f"# Seeds: {len(seeds)}, Variants: {len(all_variants)}",
        f"# Model: {args.model}",
        "",
    ]

    for prompt, keyword in seeds:
        if keyword:
            output_lines.append(f"{prompt}|{keyword}")
        else:
            output_lines.append(prompt)
    output_lines.append("")
    output_lines.append(f"# --- Synthetic variants ({len(all_variants)} total) ---")
    output_lines.append("")
    for prompt, keyword in all_variants:
        if keyword:
            output_lines.append(f"{prompt}|{keyword}")
        else:
            output_lines.append(prompt)

    result = '\n'.join(output_lines)
    print(result)

    if args.output:
        with open(args.output, 'w') as f:
            f.write(result + '\n')
        print(f"Wrote {len(seeds) + len(all_variants)} prompts to {args.output}", file=sys.stderr)

    if errors > 0:
        print(f"Warning: {errors} seed(s) used rule-based fallback", file=sys.stderr)

if __name__ == "__main__":
    main()
