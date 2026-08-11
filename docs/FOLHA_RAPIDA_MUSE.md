# Folha rápida — Muse Glimmer (somente modelo)

Detalhes: [GUIA_MUSE.md](GUIA_MUSE.md).

## Usar

```bash
systemctl --user status muse-glimmer
curl -fsS http://127.0.0.1:8080/health
```

UI: http://127.0.0.1:8080/  
API: `http://127.0.0.1:8080/v1` · model `muse-glimmer-30B`

```bash
./scripts/restart-with-profile.sh perf-q3    # rápido
./scripts/restart-with-profile.sh baseline   # qualidade Meta
```

## Compartilhar com colega

Procedimentos remotos (NetBird / túneis / MCP) estão **só** no repositório privado `peritumct-sec-platform`.

Neste host público: **não** abrir `:8080` em `0.0.0.0` / LAN / overlay.

