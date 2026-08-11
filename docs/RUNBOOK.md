# Runbook — recriar e operar

## Pré-requisitos

- RHEL/Fedora-like (validado: RHEL 10.2) com `sudo` para deps de build
- NVIDIA driver + CUDA toolkit (`nvcc`)
- ~20 GB livres para GGUF (+ espaço para build)
- Rede para clonar `llama.cpp` e baixar Hugging Face (uma vez)

## Recriação completa (scripts)

```bash
cd /caminho/para/peritumct/glimmerlocal
cp config/muse-glimmer.env.example config/muse-glimmer.env
# Ajuste IALOCAL_DATA se necessário

./scripts/bootstrap.sh
./scripts/build-llama-cpp.sh
./scripts/download-model.sh
./scripts/verify-checksums.sh
./scripts/start-server.sh
./scripts/smoke-test.sh
```

## Recriação via Ansible

```bash
cd ansible
# inventory/hosts.yml aponta para localhost por padrão
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

Tags úteis: `--tags deps,build,model,service,smoke`

## Operação diária

| Ação | Comando |
|---|---|
| Start | `./scripts/start-server.sh` |
| Stop | `./scripts/stop-server.sh` |
| Smoke | `./scripts/smoke-test.sh` |
| Logs | `tail -f ${IALOCAL_DATA}/tools/muse-glimmer/logs/llama-server.log` |
| Health | `curl -s http://127.0.0.1:8080/health` |

### Systemd (user)

```bash
mkdir -p ~/.config/systemd/user
cp systemd/muse-glimmer.service ~/.config/systemd/user/
# Edite EnvironmentFile= se o path do repo mudar
systemctl --user daemon-reload
systemctl --user enable --now muse-glimmer.service
journalctl --user -u muse-glimmer -f
```

Requer `loginctl enable-linger $USER` se precisar sobreviver ao logout.

## Tunáveis

Ver `config/muse-glimmer.env.example`. Principais:

- `MUSE_REASONING=low|medium|high|xhigh`
- `MUSE_VISION=1` — anexa mmproj (custa VRAM)
- `MUSE_CTX` / `MUSE_FIT_TARGET` — contexto vs margem VRAM
- `MUSE_THREADS` — default 24 (i9-14900K)

## Atualizar pins

1. Teste novo `llama_cpp.ref` ou novo GGUF.
2. Atualize `config/pins.yml` + `inventory/checksums.sha256`.
3. Bump `VERSION`.
4. Commit e tag (ex.: `v0.2.0`).

## Performance profiles

See [PERFORMANCE.md](PERFORMANCE.md) and `config/profiles/`.

```bash
./scripts/restart-with-profile.sh baseline   # Meta kquant fidelity
./scripts/restart-with-profile.sh perf       # kquant + ngram
./scripts/restart-with-profile.sh perf-q3    # Unsloth Q3 + ngram (default selected)
./scripts/bench-decode.py --label check --max-tokens 64
```

DFlash is downloaded but **not viable** on RTX 4060 8GB with a packed main model (OOM).

## MCP e compartilhar o modelo

**Somente Muse (recomendado para quem só precisa do LLM):**

- [GUIA_MUSE.md](GUIA_MUSE.md)
- [FOLHA_RAPIDA_MUSE.md](FOLHA_RAPIDA_MUSE.md)

Guia combinado (Radar MCP + Muse), se precisar dos dois:

- [GUIA_MCP_E_COMPARTILHAMENTO.md](GUIA_MCP_E_COMPARTILHAMENTO.md)
- [FOLHA_RAPIDA_MCP_MODELO.md](FOLHA_RAPIDA_MCP_MODELO.md)

## Troubleshooting

| Sintoma | Ação |
|---|---|
| `cicc` signal 11 no build | Reduza `LLAMA_BUILD_JOBS` (ex. 4–6) |
| `mlock` Cannot allocate memory | Use `MUSE_LOAD_MODE=mmap` ou suba `ulimit -l` |
| Porta ocupada | `./scripts/stop-server.sh` ou mude `MUSE_PORT` |
| Resposta vazia em eval | Aumente ctx efetivo por slot; use `-np 1` |
| Arch não reconhecida | Confirme `LLM_ARCH_MUSE_GLIMMER` e pin ≥ b10353 |
