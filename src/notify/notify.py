#!/usr/bin/env python3
"""
Webhook Notifications for deepiri-tombstone.
Send evaluation results to Slack, Discord, or generic webhooks.
"""
import json, sys, os, subprocess, argparse
from datetime import datetime

def send_slack(webhook_url, message):
    payload = json.dumps({"text": message})
    r = subprocess.run(["curl", "-sf", "-X", "POST", "-H", "Content-Type: application/json",
                       "-d", payload, webhook_url], capture_output=True, text=True, timeout=15)
    return r.returncode == 0, r.stderr[:200] if r.returncode != 0 else ""

def send_discord(webhook_url, message):
    payload = json.dumps({"content": message})
    r = subprocess.run(["curl", "-sf", "-X", "POST", "-H", "Content-Type: application/json",
                       "-d", payload, webhook_url], capture_output=True, text=True, timeout=15)
    return r.returncode == 0, r.stderr[:200] if r.returncode != 0 else ""

def send_generic(webhook_url, payload):
    r = subprocess.run(["curl", "-sf", "-X", "POST", "-H", "Content-Type: application/json",
                       "-d", json.dumps(payload), webhook_url], capture_output=True, text=True, timeout=15)
    return r.returncode == 0, r.stderr[:200] if r.returncode != 0 else ""

def build_message(results_file):
    if results_file and os.path.exists(results_file):
        with open(results_file) as f:
            data = json.load(f)
        passes = data.get("passes", data.get("pass_rate", 0))
        total = data.get("total", data.get("n", 0))
        rate = data.get("pass_rate", 0)
        model = data.get("model", "?")
        return f"deepiri-tombstone eval complete\nModel: {model}\nPass rate: {rate}% ({passes}/{total})"
    return "deepiri-tombstone evaluation complete"

def main():
    parser = argparse.ArgumentParser(description="Send webhook notifications")
    parser.add_argument("type", choices=["slack", "discord", "generic"], help="Webhook type")
    parser.add_argument("webhook_url", help="Webhook URL")
    parser.add_argument("-m", "--message", help="Custom message")
    parser.add_argument("-f", "--file", help="Results JSON file to summarize")
    parser.add_argument("--payload", help="Custom JSON payload (for generic)")
    args = parser.parse_args()
    message = args.message or build_message(args.file)
    success = False
    error = ""
    if args.type == "slack":
        success, error = send_slack(args.webhook_url, message)
    elif args.type == "discord":
        success, error = send_discord(args.webhook_url, message)
    elif args.type == "generic":
        payload = json.loads(args.payload) if args.payload else {"text": message}
        success, error = send_generic(args.webhook_url, payload)
    if success:
        print(f"Notification sent to {args.type} webhook")
        sys.exit(0)
    else:
        print(f"Failed to send notification: {error}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
