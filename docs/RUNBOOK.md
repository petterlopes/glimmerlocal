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

## Operação diária (on-demand)

Por omissão o Muse **não** arranca no login (liberta a RTX 4060 para o desktop).  
Revisão: [REVISAO_ONDEMAND_RAG_PERF.md](REVISAO_ONDEMAND_RAG_PERF.md).

| Ação | Comando |
|---|---|
| Menu Admin | Super → **Muse Glimmer — Administração** |
| Start / Stop / Restart | `./scripts/muse-adminctl.sh start\|stop\|restart` |
| Status + VRAM | `./scripts/muse-adminctl.sh status` |
| Instalar atalho | `./scripts/install-desktop-admin.sh --desktop` |
| Instalar unit (sem boot) | `./scripts/install-systemd-user.sh` |
| Start legado (pidfile) | `./scripts/start-server.sh` |
| Stop legado | `./scripts/stop-server.sh` |
| Smoke | `./scripts/smoke-test.sh` |
| Logs systemd | `./scripts/muse-adminctl.sh logs` |
| Health | `curl -s http://100.74.1.232:8080/health` (ou host em `muse-glimmer.env`) |

### Systemd (user) — on-demand

```bash
./scripts/install-systemd-user.sh          # instala unit, disable boot
./scripts/muse-adminctl.sh start           # só quando for usar chat
./scripts/muse-adminctl.sh stop            # libertar VRAM
# Evitar: systemctl --user enable --now muse-glimmer  (consome GPU no login)
journalctl --user -u muse-glimmer -f
```

`loginctl enable-linger $USER` só se precisar de start remoto sem sessão gráfica.

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

Uso local do Muse: [GUIA_MUSE.md](GUIA_MUSE.md) · [FOLHA_RAPIDA_MUSE.md](FOLHA_RAPIDA_MUSE.md).

MCP Radar e partilha remota (NetBird): **só** no repositório privado `peritumct-sec-platform` — stub [GUIA_MCP_E_COMPARTILHAMENTO.md](GUIA_MCP_E_COMPARTILHAMENTO.md).

## Troubleshooting

| Sintoma | Ação |
|---|---|
| `cicc` signal 11 no build | Reduza `LLAMA_BUILD_JOBS` (ex. 4–6) |
| `mlock` Cannot allocate memory | Use `MUSE_LOAD_MODE=mmap` ou suba `ulimit -l` |
| Porta ocupada | `./scripts/stop-server.sh` ou mude `MUSE_PORT` |
| Resposta vazia em eval | Aumente ctx efetivo por slot; use `-np 1` |
| Arch não reconhecida | Confirme `LLM_ARCH_MUSE_GLIMMER` e pin ≥ b10353 |
