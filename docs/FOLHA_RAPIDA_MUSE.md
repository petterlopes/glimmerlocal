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

No laptop dele:

```bash
ssh -N -L 8080:127.0.0.1:8080 USUARIO@SUA_WORKSTATION
# abrir http://127.0.0.1:8080/
```

- Preferir API key se sair de localhost.  
- **Não** abrir `:8080` na LAN / `0.0.0.0`.  
- Uma GPU ≈ poucas sessões; ~4–7 t/s nesta máquina.
