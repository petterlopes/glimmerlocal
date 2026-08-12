# Performance engineering — Muse Glimmer on RTX 4060 8GB

Date: 2026-08-11 · Host: RHEL 10.2 · i9-14900K · 125 GiB RAM · RTX 4060 8 GB

## Executive verdict

| Metric | Baseline (kquant-17gb) | Selected (`perf-q3`) | Delta |
|---|---:|---:|---:|
| Mean decode tok/s (bench) | **4.01** | **7.08** | **+76%** |
| Best single run | 4.02 | **7.97** (A/B) / **13.1** (ngram spike) | — |
| Active profile | `baseline` | **`perf-q3`** | applied |
| Endpoint | `127.0.0.1:8080` | same | localhost |

**Hard ceiling without more VRAM remains:** no Muse Glimmer 30B GGUF fits fully in 8 GB. Gains come from more GPU-resident layers (smaller quant) + ngram speculation + lean reasoning — not from “full GPU magic.”

---

## Review 1 — Symptom and measurement hygiene

User observation: `652 tokens / 2m25s ≈ 4.49 t/s`.

Server logs reproduced **~4.49–4.50 t/s** with `eval ≈ 223 ms/token` on the official kquant-17gb hybrid stack. Prompt eval was healthy (~40 t/s). GPU util during decode peaked ~31% (CPU/PCIe bound).

Fixed A/B harness (`scripts/bench-decode.py`): warm-up + identical prompt + `reasoning=low` + capped `max_tokens`, so profiles are comparable.

---

## Review 2 — Bottleneck anatomy

1. Weights ≈ **16.8 GB** vs VRAM **8 GB** → ~17–19/52 layers on GPU under baseline fit.
2. Each decode step crosses GPU→CPU→GPU over PCIe → GPU under-utilized.
3. Muse SWA keeps KV cheap; cutting ctx alone barely frees layers.
4. Long reasoning multiplies **wall time** even when tok/s is unchanged.

---

## Review 3 — Experiment matrix (measured)

| Profile | Config gist | Mean tok/s | Notes |
|---|---|---:|---|
| `baseline` | fit=768, ctx=32k, no spec, reasoning medium defaults in server | **4.01** | Official pin |
| `fit-only` | fit=256, ctx=8k, prio=2, budget=256 | **4.27** | +6.5% stable |
| `perf` | fit-only + `ngram-mod` | **5.60** (high variance: 4.3–6.9) | Acceptance-dependent |
| `perf-dflash` | + Meta DFlash | **FAIL** | GPU OOM; CPU-draft still OOM compute buffers on packed 8 GB |
| `perf-q3` | Unsloth `UD-Q3_K_XL` (~13 GB) + ngram + fit-only | **7.08** | **Winner** |

Raw JSONL: `docs/perf-results/ab-*.jsonl`  
Confirm after apply: `docs/perf-results/apply-perf-q3.log` → 6.16 and **13.12** tok/s (ngram spike).

### DFlash deep-dive (why it failed)

1. `-ngld 99` with packed main → `cudaMalloc` OOM loading draft (~1.5 GB).
2. `-ngld 0` (draft in RAM) loads, then **compute buffer** `cudaMalloc` fails (~232 MiB) because main already holds ~7.5 GB.
3. Conclusion: DFlash needs headroom that this card does not have while keeping competitive `-ngl`. Marked **unsupported** on this host until ≥24 GB VRAM.

---

## Review 4 — Why Q3+ngram wins here

1. **Smaller weights** → more layers in the 7.5 GB VRAM envelope → less PCIe thrash.
2. **ngram-mod** proposes tokens from prompt/history; when acceptance is high, effective tok/s jumps (observed **14 t/s** in server timing on a short run).
3. **reasoning_strength=low** + `--reasoning-budget 256` cuts token bloat for interactive use.
4. Tradeoff: Q3 Unsloth is **not** the Meta-reviewed kquant pin — expect some quality loss on hard agentic tasks. Keep `baseline`/`perf` profiles for fidelity.

---

## Active runtime (applied)

```bash
# config/muse-glimmer.env ← copy of config/profiles/perf-q3.env
MODEL_GGUF=.../Muse-Glimmer-30B-UD-Q3_K_XL.gguf
MUSE_SPEC_TYPE=ngram-mod
MUSE_FIT_TARGET=256
# Em desktop partilhado (GNOME+Brave/Radar), preferir ≥1536 para evitar blocos pretos por VRAM esgotada.
# Ver: peritumct-sec-platform/docs/implementacao/radar/REVISAO_RENDER_LOCAL_VRAM.md

MUSE_CTX=8192
MUSE_REASONING=low
MUSE_REASONING_BUDGET=256
```

Switch back to official quality pin:

```bash
./scripts/restart-with-profile.sh baseline   # or: perf
```

---

## Further upside (ordered)

1. GPU ≥24 GB → full offload + DFlash (order-of-magnitude).
2. Close desktop GPU consumers (Cursor/Brave) before heavy jobs.
3. Workload-specific ngram tuning (`MUSE_DRAFT_N_MAX`).
4. Optional IQ2 Unsloth for more speed / more quality loss (not applied).

---

## Safety / ops

- Bind remains `127.0.0.1`; CORS localhost-only.
- Checksums: Meta GGUFs in `inventory/checksums.sha256`; Unsloth Q3 sidecar under models dir (`820d18e0…`).
- Do not expose the OpenAI port without an API key.
