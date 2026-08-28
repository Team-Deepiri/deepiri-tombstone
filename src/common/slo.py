#!/usr/bin/env python3
"""
Harness speed model — dimensionless SLOs for deepiri-tombstone.

Observation (plain language):
  Eval wall time is almost entirely "waiting for the model," plus a smaller
  tax for HTTP setup, parsing, and ledger I/O. Cache hits remove model wait.

Invariant we optimize:
  η = T_overhead / T_wall  →  0     (overhead fraction)
  Cache-hit rate h ∈ [0,1] raises prompts/sec without more GPU.

Amdahl-ish wall bound (P workers, serial model sum S, overhead O):
  T_wall ≳ max(S/P, max_i t_i) + O
  After warm + keep-alive, O should be milliseconds, not seconds.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional


def compute_slo(
    *,
    completed: int,
    cache_hits: int,
    wall_seconds: float,
    latencies_ms: List[int],
    jobs: int,
) -> Dict[str, Any]:
    """Return production SLO dict from one eval run."""
    wall_ms = max(int(wall_seconds * 1000), 1)
    hits = max(cache_hits, 0)
    n = max(completed, 1)
    miss_lats = [int(x) for x in latencies_ms if int(x) > 0]
    hit_rate = round(hits / n, 4)
    sum_miss = sum(miss_lats)
    mean_miss = round(sum_miss / max(len(miss_lats), 1)) if miss_lats else 0
    # Ideal parallel model time if work divided evenly across jobs
    p = max(int(jobs), 1)
    t_model_parallel = sum_miss / p if miss_lats else 0
    # Overhead proxy: wall beyond the parallel model estimate (clamped)
    overhead_ms = max(0.0, wall_ms - t_model_parallel)
    eta = round(min(1.0, overhead_ms / wall_ms), 4)
    pps = round(completed / max(wall_seconds, 0.001), 2)
    # Production gates (measurable, not vibes)
    gates = {
        "eta_lt_0.25": eta < 0.25 or hit_rate >= 0.95,
        "cache_or_parallel": hit_rate > 0 or p >= 2,
        "completed_gt_0": completed > 0,
    }
    return {
        "eta_overhead": eta,
        "cache_hit_rate": hit_rate,
        "prompts_per_sec": pps,
        "wall_ms": wall_ms,
        "sum_miss_latency_ms": sum_miss,
        "mean_miss_latency_ms": mean_miss,
        "jobs": p,
        "t_model_parallel_ms": round(t_model_parallel),
        "overhead_ms": round(overhead_ms),
        "gates": gates,
        "production_fast": all(gates.values()),
    }


def default_jobs(explicit: Optional[int] = None) -> int:
    """Adaptive worker count: env wins, else clamp(cpu, 4..16)."""
    import os
    if explicit is not None and explicit > 0:
        return explicit
    env = os.environ.get("DEEPIRI_TOMBSTONE_JOBS")
    if env:
        try:
            return max(1, int(env))
        except ValueError:
            pass
    n = os.cpu_count() or 4
    return max(4, min(16, n))
