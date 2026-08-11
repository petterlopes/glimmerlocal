# Changelog — glimmerlocal

## 0.3.1 — 2026-08-11

- Guia didático **somente Muse**: `GUIA_MUSE.md` + `FOLHA_RAPIDA_MUSE.md` (uso + compartilhar, sem MCP/Radar)
- README/índice apontam o guia Muse como entrada principal para o LLM

## 0.3.0 — 2026-08-11

- Documentação didática ampla: MCP Radar + compartilhamento seguro do Muse Glimmer
- Novos docs: `GUIA_MCP_E_COMPARTILHAMENTO.md`, `FOLHA_RAPIDA_MCP_MODELO.md`, `INDICE.md`
- Cross-link no `examples/radar/README.md` (plataforma) para o guia MCP

## 0.2.0 — 2026-08-11

- Performance campaign on RTX 4060 8GB: A/B profiles + measured results
- Added DFlash artifact + checksum (unsupported on 8GB when main is packed)
- Added Unsloth `UD-Q3_K_XL` optional path; **selected profile `perf-q3`** (~7.1 t/s mean)
- Speculation hooks: `MUSE_SPEC_TYPE`, ngram-mod, draft-dflash (`MUSE_DRAFT_NGL`)
- Scripts: `bench-decode.py`, `restart-with-profile.sh`, `run-ab-matrix.sh`, `apply-perf-q3.sh`
- Docs: `docs/PERFORMANCE.md`, `docs/perf-results/`

## 0.1.0 — 2026-08-11

- Initial IaC + docs for Muse Glimmer 30B local stack
- Pinned `llama.cpp` @ `5d16e81dd9896355d36b363bbf786abaa8f6995f`
- Pinned GGUF SHA-256 for `kquant-17gb` + `mmproj-kquant`
- Scripts: bootstrap, build, download, verify, start/stop, smoke
- Ansible role `muse_glimmer` + systemd user unit template
- Validated on RHEL 10.2 / i9-14900K / RTX 4060 8GB / 125 GiB RAM
