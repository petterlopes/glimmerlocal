# glimmerlocal — Muse Glimmer (PeritumCT)

Infraestrutura-as-Code e documentação para **recriar** o ambiente local do [Muse Glimmer 30B](https://research.meta.ai/blog/introducing-muse-glimmer-open-agentic-model) validado em workstation NVIDIA.

Repositório: [github.com/petterlopes/glimmerlocal](https://github.com/petterlopes/glimmerlocal)

Este diretório é o artefato versionável. Pesos GGUF e o build de `llama.cpp` ficam **fora** do Git (paths configuráveis).

## Escopo

| Camada | Conteúdo |
|---|---|
| Docs | Arquitetura, runbook, segurança, perfil de hardware |
| Pins | Commit `llama.cpp`, artefatos HF, SHA-256 |
| Scripts | Bootstrap, build CUDA, download, **admin on-demand**, smoke |
| Ansible | Playbook idempotente de deps + runtime + modelo + systemd |
| Systemd | Unidade user-level **on-demand** (sem enable no login) |

## Quick start

```bash
cd peritumct/glimmerlocal
cp config/muse-glimmer.env.example config/muse-glimmer.env
# edite IALOCAL_DATA / threads / etc.

./scripts/bootstrap.sh          # deps + venv hf + dirs
./scripts/build-llama-cpp.sh    # llama.cpp CUDA (pin em config/pins.yml)
./scripts/download-model.sh     # GGUF oficial + verify SHA-256
./scripts/install-systemd-user.sh       # unit sem autostart
./scripts/install-desktop-admin.sh --desktop
./scripts/muse-adminctl.sh start        # só ao usar chat
./scripts/smoke-test.sh
./scripts/muse-adminctl.sh stop         # libertar VRAM

## RAG → Muse (plataforma)

Postgres RAG permanece em `peritumct-sec-platform/rag/` (cgroup 8 GiB). O glimmerlocal só faz bridge:

```bash
./scripts/rag-status.sh
./scripts/rag-chat.sh --ensure-muse -q "What are Privacy by Design foundational principles?"
# UI Muse: ./scripts/muse-adminctl.sh start → MCP Servers → peritumct-rag
# Detalhe: docs/REVISAO_MCP_RAG_UI.md
```

Doc: [docs/INTEGRACAO_RAG.md](docs/INTEGRACAO_RAG.md).
```

Ou via Ansible (mesmo host):

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

## Layout de dados (default neste host)

```
${IALOCAL_DATA}/
  tools/llama.cpp/          # clone + build
  tools/muse-glimmer/       # logs/pid (runtime)
  models/Muse-Glimmer-30B-GGUF/
```

Default validado: `IALOCAL_DATA=/run/media/petterlopes/SSD930`

## Status validado (2026-08-11)

- Host: RHEL 10.2 · i9-14900K · 125 GiB RAM · RTX 4060 8 GB
- Endpoint: `http://127.0.0.1:8080` · health OK · smoke `17*23=391`
- VRAM ~6.8–7.5 GB com `--fit on` (offload híbrido GPU+RAM)
- **Perf (v0.2.0):** profile `perf-q3` ~**7.1 t/s** mean vs ~4.0 baseline — [docs/PERFORMANCE.md](docs/PERFORMANCE.md)
- **Guia Muse (uso + compartilhar):** [docs/GUIA_MUSE.md](docs/GUIA_MUSE.md) · [docs/FOLHA_RAPIDA_MUSE.md](docs/FOLHA_RAPIDA_MUSE.md)

## Documentação

Índice: [docs/INDICE.md](docs/INDICE.md)

| Doc | Para quê |
|---|---|
| [Guia Muse](docs/GUIA_MUSE.md) | Didático completo — **somente o modelo** |
| [Folha rápida Muse](docs/FOLHA_RAPIDA_MUSE.md) | Checklist do dia a dia |
| [RUNBOOK](docs/RUNBOOK.md) | Start/stop/perfis |
| [SECURITY](docs/SECURITY.md) | Controles e ameaças |

Detalhes técnicos: [docs/RUNBOOK.md](docs/RUNBOOK.md) · [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · [docs/SECURITY.md](docs/SECURITY.md)

## Versionamento

1. Altere `config/pins.yml` e `inventory/checksums.sha256` ao subir runtime/modelo.
2. Bump em `VERSION`.
3. Commit **apenas** este repositório (`glimmerlocal`) — nunca os GGUFs.
