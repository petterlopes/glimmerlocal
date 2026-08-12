# Folha rápida — Muse Glimmer (somente modelo)

Detalhes: [GUIA_MUSE.md](GUIA_MUSE.md) · On-demand: [REVISAO_ONDEMAND_RAG_PERF.md](REVISAO_ONDEMAND_RAG_PERF.md).

## Usar (on-demand — não arranca no login)

```bash
# Menu: Super → «Muse Glimmer — Administração»
./scripts/muse-adminctl.sh start
./scripts/muse-adminctl.sh status
curl -fsS http://100.74.1.232:8080/health   # host em muse-glimmer.env
./scripts/muse-adminctl.sh stop             # libertar VRAM
```

UI: conforme `MUSE_HOST` (NetBird `100.74.1.232:8080` neste host)  
API: `/v1` · model `muse-glimmer-30B`

```bash
./scripts/install-desktop-admin.sh --desktop   # uma vez
./scripts/restart-with-profile.sh desktop-ondemand  # se o script aceitar; senão muse-adminctl restart
```

## Compartilhar com colega

Procedimentos remotos (NetBird / túneis / MCP) estão **só** no repositório privado `peritumct-sec-platform`.

Neste host: **não** abrir `:8080` em `0.0.0.0` / LAN / overlay.
