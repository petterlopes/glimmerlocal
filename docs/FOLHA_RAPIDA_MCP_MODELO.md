# Folha rápida — MCP + compartilhar Muse

One-pager. Detalhes: [GUIA_MCP_E_COMPARTILHAMENTO.md](GUIA_MCP_E_COMPARTILHAMENTO.md).

## Portas

| Serviço | URL |
|---|---|
| Radar UI | http://127.0.0.1:9280/ |
| Radar MCP | http://127.0.0.1:9280/mcp |
| Muse UI / API | http://127.0.0.1:8080/ · `/v1/` |

## MCP no Cursor

`~/.cursor/mcp.json`:

```json
{ "mcpServers": { "radar": { "url": "http://localhost:9280/mcp" } } }
```

1. `./scripts/connect-teleport-kube-radar.sh all`  
2. Cursor → MCP → autenticar se pedido → status **ready**  
3. No Agent: peça explicitamente para usar tools do Radar  

## Muse local

```bash
systemctl --user status muse-glimmer
curl -fsS http://127.0.0.1:8080/health
```

## Compartilhar o modelo (colega)

No laptop dele:

```bash
ssh -N -L 8080:127.0.0.1:8080 usuario@sua-workstation
# abrir http://127.0.0.1:8080/
```

- Preferir API key se for além de localhost.  
- **Não** abrir `:8080` / `:9280` na LAN.  
- **Não** compartilhar MCP Radar sem acordo (é acesso ao cluster).  

## Trocar perfil Muse

```bash
cd .../glimmerlocal
./scripts/restart-with-profile.sh perf-q3   # rápido
./scripts/restart-with-profile.sh baseline  # qualidade Meta
```
