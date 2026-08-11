# Versionamento do repositório glimmerlocal

## O que entra no Git

- `docs/`, `config/pins.yml`, `config/*.example`, `inventory/`, `scripts/`, `ansible/`, `systemd/`
- `VERSION`, `CHANGELOG.md`, `README.md`, `Makefile`

## O que NÃO entra

- GGUFs / builds CUDA / logs (`IALOCAL_DATA`)
- `config/muse-glimmer.env` (local)
- `secrets/`, tokens HF

## Fluxo sugerido

```bash
cd peritumct/glimmerlocal
git init   # se ainda não for um repo
git add .
git status   # confirme ausência de *.gguf e .env
git commit -m "chore(glimmerlocal): Muse Glimmer local stack v$(cat VERSION)"
git tag "v$(cat VERSION)"
```

Ao mudar runtime ou pesos:

1. Atualize `config/pins.yml` + `inventory/checksums.sha256`
2. Bump `VERSION` + entrada em `CHANGELOG.md`
3. Revalide `./scripts/smoke-test.sh`
4. Commit + tag

Remote: use o remoto Git da PeritumCT (`origin`). Não usar remotes FarmLink.
