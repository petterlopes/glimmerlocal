# MCP Radar e partilha Muse — redireccionamento

Este repositório (`glimmerlocal`) é **público** e documenta apenas o **runtime local** do Muse Glimmer (build, pins, start/stop, perfis).

Procedimentos de:

- MCP Radar no Cursor
- partilha remota do modelo via NetBird / SSH
- políticas ACL e RBAC associados

vivem **exclusivamente** no repositório privado `peritumct-sec-platform`:

| Documento (plataforma) | Papel |
|------------------------|-------|
| `docs/governanca/ADR_ACESSO_MUSE_MCP_VIA_NETBIRD.md` | Norma |
| `docs/implementacao/netbird/ACESSO_MUSE_MCP_WORKSTATION.md` | Runbook |
| `examples/radar/FOLHA_RAPIDA_MUSE_MCP_NETBIRD.md` | Folha rápida |
| `examples/radar/muse-netbird-tunnel.sh` | Túnel Muse (8080 only) |

Uso local do modelo nesta máquina: [GUIA_MUSE.md](GUIA_MUSE.md) · [FOLHA_RAPIDA_MUSE.md](FOLHA_RAPIDA_MUSE.md).
