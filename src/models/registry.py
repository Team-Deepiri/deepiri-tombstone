#!/usr/bin/env python3
"""
Model Registry for deepiri-tombstone.
Manage model configurations, parameters, and metadata.
"""
import json, sys, os, argparse

DEFAULT_CONFIG = {
    "models": {
        "llama3.2": {
            "provider": "ollama",
            "parameters": {"temperature": 0.7, "top_p": 0.9, "max_tokens": 2048},
            "cost_per_1k_tokens": 0.0,
            "tags": ["general", "fast"],
        },
        "llama3.1": {
            "provider": "ollama",
            "parameters": {"temperature": 0.7, "top_p": 0.9, "max_tokens": 2048},
            "cost_per_1k_tokens": 0.0,
            "tags": ["general"],
        },
        "mistral": {
            "provider": "ollama",
            "parameters": {"temperature": 0.7, "top_p": 0.9, "max_tokens": 2048},
            "cost_per_1k_tokens": 0.0,
            "tags": ["general", "fast"],
        },
        "phi3": {
            "provider": "ollama",
            "parameters": {"temperature": 0.7, "top_p": 0.9, "max_tokens": 2048},
            "cost_per_1k_tokens": 0.0,
            "tags": ["small", "fast"],
        },
        "codellama": {
            "provider": "ollama",
            "parameters": {"temperature": 0.2, "top_p": 0.95, "max_tokens": 4096},
            "cost_per_1k_tokens": 0.0,
            "tags": ["code"],
        },
    },
    "default_model": "llama3.2",
    "judge_model": "llama3.2",
    "eval_defaults": {
        "temperature": 0.7,
        "max_tokens": 2048,
    },
}

class ModelRegistry:
    def __init__(self, config_path=None):
        self.config_path = config_path or os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "..", "config", "models.json")
        self.config = dict(DEFAULT_CONFIG)
        self.load()

    def load(self):
        if os.path.exists(self.config_path):
            try:
                with open(self.config_path) as f:
                    loaded = json.load(f)
                    if "models" in loaded:
                        self.config["models"].update(loaded["models"])
                    for k in ["default_model", "judge_model", "eval_defaults"]:
                        if k in loaded:
                            self.config[k] = loaded[k]
            except (json.JSONDecodeError, Exception) as e:
                print(f"Warning: could not load {self.config_path}: {e}", file=sys.stderr)

    def save(self):
        os.makedirs(os.path.dirname(self.config_path) or ".", exist_ok=True)
        with open(self.config_path, 'w') as f:
            json.dump(self.config, f, indent=2)

    def list_models(self, tag=None):
        models = self.config.get("models", {})
        if tag:
            return {k: v for k, v in models.items() if tag in v.get("tags", [])}
        return models

    def get_model(self, name):
        models = self.config.get("models", {})
        return models.get(name, models.get(self.config.get("default_model", "llama3.2")))

    def add_model(self, name, provider="ollama", tags=None, params=None):
        self.config.setdefault("models", {})[name] = {
            "provider": provider,
            "parameters": params or {"temperature": 0.7, "top_p": 0.9, "max_tokens": 2048},
            "cost_per_1k_tokens": 0.0,
            "tags": tags or ["general"],
        }
        self.save()

def main():
    parser = argparse.ArgumentParser(description="Model registry management")
    parser.add_argument("action", choices=["list", "get", "add", "init", "path"], help="Action")
    parser.add_argument("model_name", nargs="?", help="Model name (for get/add)")
    parser.add_argument("--tag", help="Filter by tag")
    parser.add_argument("--provider", default="ollama", help="Model provider")
    parser.add_argument("--params", help="Model parameters JSON")
    parser.add_argument("--tags", nargs="+", help="Model tags")
    parser.add_argument("-c", "--config", help="Config path")
    args = parser.parse_args()
    registry = ModelRegistry(args.config)
    if args.action == "list":
        models = registry.list_models(args.tag)
        print(json.dumps(models, indent=2))
        print(f"\nTotal: {len(models)} models", file=sys.stderr)
    elif args.action == "get":
        if not args.model_name:
            print("ERROR: model_name required", file=sys.stderr)
            sys.exit(1)
        model = registry.get_model(args.model_name)
        print(json.dumps(model, indent=2))
    elif args.action == "add":
        if not args.model_name:
            print("ERROR: model_name required", file=sys.stderr)
            sys.exit(1)
        params = json.loads(args.params) if args.params else None
        registry.add_model(args.model_name, args.provider, args.tags, params)
        print(f"Added model: {args.model_name}", file=sys.stderr)
        print(json.dumps(registry.get_model(args.model_name), indent=2))
    elif args.action == "init":
        registry.save()
        print(f"Config initialized: {registry.config_path}", file=sys.stderr)
        print(json.dumps(registry.config, indent=2))
    elif args.action == "path":
        print(registry.config_path)

if __name__ == "__main__":
    main()
