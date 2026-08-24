#!/usr/bin/env python3
"""
Shared Ollama HTTP client for deepiri-tombstone hot paths.

Uses keep-alive http.client (no per-call curl fork) and an optional
content-addressed response cache so re-runs / benches / juries skip
identical (model, prompt) pairs.
"""
from __future__ import annotations

import hashlib
import http.client
import json
import os
import threading
import time
from typing import Optional, Tuple
from urllib.parse import urlparse

DEFAULT_HOST = "127.0.0.1:11434"
DEFAULT_TIMEOUT = 120


def default_host() -> str:
    return os.environ.get("DEEPIRI_TOMBSTONE_HOST", DEFAULT_HOST)


def cache_dir() -> str:
    root = os.environ.get("DEEPIRI_TOMBSTONE_CACHE_DIR")
    if root:
        return root
    here = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(here, "..", "reports", "cache"),       # bin/ → ../reports
        os.path.join(here, "..", "..", "reports", "cache"), # src/common → ../../reports
        os.path.join("reports", "cache"),
    ]
    for cand in candidates:
        abs_cand = os.path.abspath(cand)
        parent = os.path.dirname(abs_cand)
        if os.path.isdir(parent):
            return abs_cand
    return os.path.abspath(os.path.join("reports", "cache"))


def cache_enabled() -> bool:
    return os.environ.get("DEEPIRI_TOMBSTONE_NO_CACHE", "") not in ("1", "true", "yes")


def cache_key(model: str, prompt: str, endpoint: str = "generate") -> str:
    raw = f"{endpoint}\0{model}\0{prompt}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def _cache_path(key: str) -> str:
    d = cache_dir()
    return os.path.join(d, key[:2], f"{key}.json")


def cache_get(model: str, prompt: str, endpoint: str = "generate") -> Optional[str]:
    if not cache_enabled():
        return None
    path = _cache_path(cache_key(model, prompt, endpoint))
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data.get("response")
    except (OSError, json.JSONDecodeError, TypeError):
        return None


def cache_put(model: str, prompt: str, response: str, endpoint: str = "generate") -> None:
    if not cache_enabled() or response is None:
        return
    path = _cache_path(cache_key(model, prompt, endpoint))
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "model": model,
                    "endpoint": endpoint,
                    "response": response,
                    "prompt_sha256": hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
                },
                f,
            )
        os.replace(tmp, path)
    except OSError:
        pass


def cache_stats() -> dict:
    root = cache_dir()
    files = 0
    bytes_ = 0
    if os.path.isdir(root):
        for dirpath, _, filenames in os.walk(root):
            for name in filenames:
                if not name.endswith(".json"):
                    continue
                files += 1
                try:
                    bytes_ += os.path.getsize(os.path.join(dirpath, name))
                except OSError:
                    pass
    return {"dir": root, "entries": files, "bytes": bytes_}


class OllamaClient:
    """Thread-safe keep-alive client. One TCP connection per worker thread."""

    def __init__(self, host: Optional[str] = None, timeout: int = DEFAULT_TIMEOUT):
        self.host = host or default_host()
        self.timeout = timeout
        self._local = threading.local()
        self._lock = threading.Lock()
        self.hits = 0
        self.misses = 0
        self.errors = 0

    def _conn(self) -> http.client.HTTPConnection:
        conn = getattr(self._local, "conn", None)
        if conn is None:
            # Accept host or host:port; strip accidental scheme.
            host = self.host
            if "://" in host:
                parsed = urlparse(host if "://" in host else f"http://{host}")
                host = parsed.netloc or parsed.path
            conn = http.client.HTTPConnection(host, timeout=self.timeout)
            self._local.conn = conn
        return conn

    def _reset(self) -> None:
        conn = getattr(self._local, "conn", None)
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass
            self._local.conn = None

    def request(self, method: str, path: str, body: Optional[bytes] = None) -> Tuple[int, bytes]:
        headers = {"Connection": "keep-alive"}
        if body is not None:
            headers["Content-Type"] = "application/json"
            headers["Content-Length"] = str(len(body))
        last_err: Optional[Exception] = None
        for attempt in range(3):
            try:
                conn = self._conn()
                conn.request(method, path, body=body, headers=headers)
                resp = conn.getresponse()
                data = resp.read()
                if resp.status >= 500:
                    self._reset()
                    time.sleep(0.25 * (attempt + 1))
                    continue
                return resp.status, data
            except (http.client.HTTPException, OSError, TimeoutError) as e:
                last_err = e
                self._reset()
                time.sleep(0.25 * (attempt + 1))
        self.errors += 1
        raise ConnectionError(str(last_err) if last_err else "ollama request failed")

    def ping(self) -> bool:
        try:
            status, _ = self.request("GET", "/api/tags")
            return status == 200
        except Exception:
            return False

    def generate(
        self,
        model: str,
        prompt: str,
        *,
        use_cache: bool = True,
        stream: bool = False,
    ) -> Tuple[Optional[str], int, Optional[str], bool]:
        """Return (response_text, latency_ms, error, cache_hit)."""
        if use_cache:
            cached = cache_get(model, prompt, "generate")
            if cached is not None:
                with self._lock:
                    self.hits += 1
                return cached, 0, None, True

        payload = json.dumps(
            {"model": model, "prompt": prompt, "stream": stream}
        ).encode("utf-8")
        start = time.monotonic()
        try:
            status, data = self.request("POST", "/api/generate", payload)
            elapsed_ms = int((time.monotonic() - start) * 1000)
            if status != 200:
                with self._lock:
                    self.misses += 1
                    self.errors += 1
                return None, elapsed_ms, f"http {status}", False
            parsed = json.loads(data.decode("utf-8"))
            response = parsed.get("response", "")
            if use_cache and response is not None:
                cache_put(model, prompt, response, "generate")
            with self._lock:
                self.misses += 1
            return response, elapsed_ms, None, False
        except Exception as e:
            elapsed_ms = int((time.monotonic() - start) * 1000)
            with self._lock:
                self.misses += 1
                self.errors += 1
            return None, elapsed_ms, str(e), False

    def chat(
        self,
        model: str,
        messages: list,
        *,
        use_cache: bool = False,
    ) -> Tuple[Optional[str], int, Optional[str]]:
        """Chat API. Returns (content, latency_ms, error)."""
        payload = json.dumps(
            {"model": model, "messages": messages, "stream": False}
        ).encode("utf-8")
        start = time.monotonic()
        try:
            status, data = self.request("POST", "/api/chat", payload)
            elapsed_ms = int((time.monotonic() - start) * 1000)
            if status != 200:
                return None, elapsed_ms, f"http {status}"
            parsed = json.loads(data.decode("utf-8"))
            content = (parsed.get("message") or {}).get("content", "")
            return content, elapsed_ms, None
        except Exception as e:
            elapsed_ms = int((time.monotonic() - start) * 1000)
            return None, elapsed_ms, str(e)

    def tags(self) -> Tuple[Optional[dict], Optional[str]]:
        """Return /api/tags JSON or (None, error)."""
        try:
            status, data = self.request("GET", "/api/tags")
            if status != 200:
                return None, f"http {status}"
            return json.loads(data.decode("utf-8")), None
        except Exception as e:
            return None, str(e)

    def close(self) -> None:
        self._reset()
