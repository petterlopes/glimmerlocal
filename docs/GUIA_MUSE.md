# Guia didático — Muse Glimmer local (somente o modelo)

Este guia cobre **apenas** o Muse Glimmer nesta workstation: como usar e operar o modelo **localmente**, com segurança.

Não trata de Radar, Teleport nem MCP. Para isso, veja a documentação da plataforma (`examples/radar/`).

---

## 1. O que é

**Muse Glimmer** é um LLM ~30B da Meta, rodando **localmente** via `llama.cpp` (`llama-server`), com API compatível com OpenAI.

```text
Browser / script / IDE  →  http://127.0.0.1:8080  →  llama-server  →  GPU + RAM
```

| Item | Valor nesta estação |
|---|---|
| UI + API | http://127.0.0.1:8080/ |
| Health | `GET /health` |
| Chat API | `POST /v1/chat/completions` |
| Alias do modelo | `muse-glimmer-30B` |
| Serviço | `systemctl --user muse-glimmer.service` |
| Código / IaC | `peritumct/glimmerlocal/` |
| Pesos (fora do Git) | `$IALOCAL_DATA/models/...` |

Dois perfis principais:

| Perfil | Quando usar |
|---|---|
| `perf-q3` (padrão atual) | Mais rápido (~6–7 t/s); quant Unsloth Q3 |
| `baseline` | Fidelidade ao pin oficial Meta (kquant-17gb); mais lento (~4 t/s) |

Detalhes de performance: [PERFORMANCE.md](PERFORMANCE.md).

---

## 2. Subir e verificar

```bash
# status
systemctl --user status muse-glimmer.service
curl -fsS http://127.0.0.1:8080/health

# se estiver parado
systemctl --user start muse-glimmer.service
# ou reinstalar a unit
cd /run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal
./scripts/install-systemd-user.sh
```

Trocar perfil:

```bash
cd /run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal
./scripts/restart-with-profile.sh perf-q3    # rápido
./scripts/restart-with-profile.sh baseline   # qualidade Meta
```

Abrir no browser: http://127.0.0.1:8080/

---

## 3. Usar no dia a dia

### 3.1 Interface web

1. Abra http://127.0.0.1:8080/  
2. Modelo: `muse-glimmer-30B`  
3. Para respostas mais rápidas, use raciocínio baixo (`reasoning_strength: low`)

### 3.2 API (curl)

```bash
curl -sS http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "muse-glimmer-30B",
    "messages": [{"role":"user","content":"Responda só: OK"}],
    "max_tokens": 64,
    "chat_template_kwargs": {"reasoning_strength": "low"}
  }'
```

### 3.3 Python

```python
from openai import OpenAI

client = OpenAI(base_url="http://127.0.0.1:8080/v1", api_key="local")
r = client.chat.completions.create(
    model="muse-glimmer-30B",
    messages=[{"role": "user", "content": "Olá"}],
    max_tokens=128,
)
print(r.choices[0].message.content)
```

### 3.4 Outros apps na mesma máquina

Qualquer cliente OpenAI-compatible:

- **Base URL:** `http://127.0.0.1:8080/v1`  
- **Model:** `muse-glimmer-30B`  
- **API key:** `local` (ou a key real, se você configurar uma)

Exemplos: Open WebUI, Continue, LiteLLM, scripts internos.

### 3.5 Parâmetros úteis

| Campo | Sugestão |
|---|---|
| `reasoning_strength` | `low` (rápido) · `medium`/`high` (melhor qualidade, mais tokens) |
| `max_tokens` | Limite a saída (ex.: 256–1024) |
| `temperature` | Default Meta: `1.0` |
| `top_p` / `top_k` | `0.95` / `64` |

Expectativa nesta GPU (RTX 4060 8 GB): cerca de **4–7 tokens/s** (hybrid GPU+RAM). Não é bug.

---

## 4. Compartilhar o acesso ao modelo

O Muse escuta só em **`127.0.0.1`**. **Não** abra `0.0.0.0:8080` / `wt0:8080` sem controlos e ADR.

Procedimentos de acesso remoto (NetBird, túneis, MCP, RBAC) são **internos PeritumCT** e vivem exclusivamente no repositório privado da plataforma (`peritumct-sec-platform`) — ADR de Muse/MCP via NetBird e guia operacional da workstation. Este repositório público **não** documenta FQDNs mesh, policies nem runbooks de partilha.

Uso local (dono da workstation): secções 1–3 e 5 deste guia.

---

## 5. Recriar o ambiente (resumo)

Documentação/IaC: repositório `peritumct/glimmerlocal`.

```bash
cd peritumct/glimmerlocal
cp config/muse-glimmer.env.example config/muse-glimmer.env
./scripts/bootstrap.sh
./scripts/build-llama-cpp.sh
./scripts/download-model.sh
./scripts/install-systemd-user.sh   # ou start-server.sh
./scripts/smoke-test.sh
```

Runbook completo: [RUNBOOK.md](RUNBOOK.md).

---

## 6. Troubleshooting (só Muse)

| Sintoma | Acção |
|---|---|
| `ERR_CONNECTION_REFUSED` | `systemctl --user restart muse-glimmer` ou `./scripts/install-systemd-user.sh` |
| Cai ao fechar o terminal | Use systemd user (não `nohup` no shell do Cursor) |
| Muito lento | Normal em 8 GB VRAM; use `perf-q3` e `reasoning_strength=low` |

---

## 7. Checklist rápido

- [ ] `muse-glimmer` active
- [ ] http://127.0.0.1:8080/health → ok
- [ ] Chat responde
- [ ] Sem porta 8080 aberta em `0.0.0.0` / LAN / overlay

---

## 8. Referências (Muse only)

| Doc | Assunto |
|---|---|
| [RUNBOOK.md](RUNBOOK.md) | Operação e perfis |
| [PERFORMANCE.md](PERFORMANCE.md) | Números tok/s |
| [SECURITY.md](SECURITY.md) | Controles de segurança |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Arquitetura técnica |
| [../README.md](../README.md) | Visão do repositório glimmerlocal |
| Plataforma (privado) | Acesso remoto NetBird / MCP — só `peritumct-sec-platform` |
