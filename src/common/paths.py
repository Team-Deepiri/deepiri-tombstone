#!/usr/bin/env python3
"""
Shared path / version helpers for deepiri-tombstone Python stages.

Installed to bin/paths.py beside the stage scripts so imports resolve both
in-tree (src/common/) and after `make` (bin/).
"""
from __future__ import annotations

import os
import sys
from typing import Optional


def common_search_dirs(start_file: Optional[str] = None):
    """Candidate directories that may contain paths.py / ollama_client.py / ledger.py."""
    if start_file:
        here = os.path.dirname(os.path.abspath(start_file))
    else:
        here = os.path.dirname(os.path.abspath(__file__))
    return (
        here,
        os.path.join(here, "..", "common"),
        os.path.join(here, "..", "..", "src", "common"),
        os.path.join(here, ".."),  # bin/ when start is bin/foo
    )


def ensure_common_path(start_file: Optional[str] = None) -> Optional[str]:
    """Insert the shared helpers directory onto sys.path. Returns the dir used."""
    for cand in common_search_dirs(start_file):
        abs_cand = os.path.abspath(cand)
        if os.path.isfile(os.path.join(abs_cand, "paths.py")) or os.path.isfile(
            os.path.join(abs_cand, "ollama_client.py")
        ) or os.path.isfile(os.path.join(abs_cand, "ledger.py")):
            if abs_cand not in sys.path:
                sys.path.insert(0, abs_cand)
            return abs_cand
    return None


def repo_root(start_file: Optional[str] = None) -> str:
    """Walk up from start_file (or this module) until VERSION is found."""
    if start_file:
        cur = os.path.dirname(os.path.abspath(start_file))
    else:
        cur = os.path.dirname(os.path.abspath(__file__))
    for _ in range(8):
        if os.path.isfile(os.path.join(cur, "VERSION")):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            break
        cur = parent
    # Fallbacks: cwd, then parent of common/
    if os.path.isfile(os.path.join(os.getcwd(), "VERSION")):
        return os.getcwd()
    return os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def read_version(start_file: Optional[str] = None) -> str:
    """Return harness version string from the VERSION file."""
    root = repo_root(start_file)
    path = os.path.join(root, "VERSION")
    if os.path.isfile(path):
        try:
            return open(path, encoding="utf-8").read().strip() or "unknown"
        except OSError:
            return "unknown"
    if os.path.isfile("VERSION"):
        try:
            return open("VERSION", encoding="utf-8").read().strip() or "unknown"
        except OSError:
            return "unknown"
    return "unknown"


def boot(start_file: Optional[str] = None):
    """
    One-call bootstrap for stage scripts.
    Usage at top of a stage (after `import os, sys` is fine but not required):

        import paths_boot  # not used

    Prefer:

        from paths import boot
        boot(__file__)
    """
    return ensure_common_path(start_file)
