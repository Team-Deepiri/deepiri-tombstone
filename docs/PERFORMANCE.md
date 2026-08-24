# Harness performance model

What is actually true about an eval run, independent of language or stage:

1. Almost all wall time is **waiting for the model** (or skipping that wait via cache).
2. HTTP setup, JSON parse, and ledger I/O are a smaller tax — the **overhead**.
3. Parallel workers cannot beat the slowest in-flight prompt; they only divide the *sum* of model waits.

## State variables we measure

| Symbol | Meaning | How we measure |
|--------|---------|----------------|
| \(T_\mathrm{wall}\) | Suite wall-clock | Runner monotonic clock |
| \(t_i\) | Miss latency for prompt \(i\) | Per-call `latency_ms` (0 on cache hit) |
| \(h\) | Cache hit rate | `cache_hits / completed` |
| \(P\) | Worker count | `-j` / `DEEPIRI_TOMBSTONE_JOBS` / adaptive default |
| \(\eta\) | Overhead fraction | \(T_\mathrm{overhead} / T_\mathrm{wall}\) |
| \(\mathrm{pps}\) | Prompts per second | `completed / T_wall` |

## Invariant we optimize

\[
\eta = \frac{T_\mathrm{overhead}}{T_\mathrm{wall}} \to 0
\]

After warm + keep-alive, overhead should be milliseconds, not seconds. Raising \(h\) raises \(\mathrm{pps}\) without more GPU.

## Amdahl-ish wall bound

Let \(S = \sum t_i\) over cache misses. With \(P\) workers:

\[
T_\mathrm{wall} \gtrsim \max\!\left(\frac{S}{P},\; \max_i t_i\right) + O
\]

where \(O\) is connection/parse/ledger overhead. The runner reports:

- `slo.eta_overhead` — \(\eta\)
- `slo.cache_hit_rate` — \(h\)
- `slo.prompts_per_sec` — \(\mathrm{pps}\)
- `slo.production_fast` — gates: \(\eta < 0.25\) (or \(h \ge 0.95\)), and parallel or cache in use

## System fix (why this is “fast as fuck”)

| Lever | Effect |
|-------|--------|
| **Cache-first** | Hits resolve before warm/GPU; full-cache suite wall ≈ disk I/O |
| Keep-alive HTTP + `keep_alive` | Collapse TCP tax; pin model in VRAM |
| Shared SHA-256 cache (B ↔ Python) | Same key → same file; classic and hot path share hits |
| **Stream early-stop** | Keyword evals abort mid-generation (first-run wall cut) |
| Warm only on misses | Cold-load never paid when cache covers the suite |
| Adaptive \(P \in [4,16]\) + fail-fast | Saturate Ollama; abort burning budget on broken runs |
| Batched ledger | One flush, not N appends |

## Commands

```bash
./deepiri-tombstone eval llama3.2 -j 8
./deepiri-tombstone eval llama3.2 --fail-fast 3
./deepiri-tombstone eval --classic llama3.2
./deepiri-tombstone doctor
```

Re-run the same fixture: \(h \to 1\), warm skipped, \(\mathrm{pps}\) spikes — that is the intended production loop.
