# Muse Glimmer A/B final summary — 2026-08-11

## Selected profile: `perf-q3`

- Model: Unsloth `Muse-Glimmer-30B-UD-Q3_K_XL.gguf` (~13 GB)
- Speculation: `ngram-mod` (draft n_max=8)
- Fit target: 256 MiB free · ctx 8192 · threads 16 · reasoning low · budget 256
- Applied to `config/muse-glimmer.env` and running on `127.0.0.1:8080`

## Results (decode tok/s)

| profile | runs | mean | best |
|---|---:|---:|---:|
| baseline | 2 | 4.010 | 4.016 |
| fit-only | 2 | 4.270 | 4.274 |
| perf (ngram + kquant-17gb) | 3* | ~5.2† | 6.866 |
| perf-q3 | 3 | **7.082** | **7.971** |
| perf-dflash | — | unsupported (OOM) | — |

\* one confirm run incomplete (hung generation); † approximate from available samples  
Post-apply confirm: 6.155 and **13.119** tok/s (`apply-perf-q3.log`).

## Delta vs user baseline (~4.49 t/s)

Interactive effective speed roughly **1.6–3×** depending on ngram acceptance; mean bench **~7.1 t/s** (+~58% vs 4.49, +76% vs fixed A/B baseline 4.01).

See [PERFORMANCE.md](../PERFORMANCE.md) for deep reviews.
