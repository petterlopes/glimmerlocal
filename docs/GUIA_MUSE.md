# Guia didático — Muse Glimmer local (somente o modelo)

Este guia cobre **apenas** o Muse Glimmer nesta workstation: como usar, operar e **compartilhar o acesso ao modelo** com segurança.

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

### 4.1 Regra de ouro

O Muse escuta só em **`127.0.0.1`**. Colegas na LAN **não** acessam por padrão.

Para compartilhar: **túnel SSH** (ou equivalente) até o localhost da workstation.  
**Não** abra `0.0.0.0:8080` sem API key e sem ADR.

```text
Laptop do colega                    Sua workstation
─────────────────                   ────────────────
browser → 127.0.0.1:8080  ──SSH─L──►  127.0.0.1:8080 (llama-server)
```

### 4.2 Passo a passo (1 colega)

**Na sua máquina**

1. Confirme o serviço:

   ```bash
   systemctl --user is-active muse-glimmer.service
   curl -fsS http://127.0.0.1:8080/health
   ```

2. (Recomendado) Crie uma API key:

   ```bash
   mkdir -p secrets && chmod 700 secrets
   openssl rand -base64 32 > secrets/api-key
   chmod 600 secrets/api-key
   ```

   Configure o `llama-server` com `--api-key "$(cat secrets/api-key)"` (drop-in systemd ou script) e reinicie.  
   Envie a key por canal seguro (nunca Git/chat público).

3. Garanta que o colega tem login SSH (chave) na workstation.

**No laptop do colega**

```bash
ssh -N -L 8080:127.0.0.1:8080 USUARIO@IP_OU_HOSTNAME_DA_WORKSTATION
```

Deixe o comando rodando. Depois:

- UI: http://127.0.0.1:8080/  
- API: http://127.0.0.1:8080/v1  

Se houver API key:

```bash
curl -sS http://127.0.0.1:8080/v1/models \
  -H "Authorization: Bearer COLE_A_KEY_AQUI"
```

### 4.3 Via NetBird / overlay

Mesmo comando SSH, usando o nome/IP NetBird da workstation:

```bash
ssh -N -L 8080:127.0.0.1:8080 USUARIO@nome-netbird
```

Continua **sem** expor a porta 8080 no overlay.

### 4.4 Vários colegas (sala / horário)

1. Agende um horário (uma GPU).  
2. Cada um abre seu próprio túnel SSH.  
3. Avisem que a velocidade cai com sessões simultâneas.  
4. No fim do dia: fechem túneis e **rotem** a API key.  
5. Opcional: `systemctl --user stop muse-glimmer` fora do expediente.

### 4.5 O que não fazer

| Não faça | Motivo |
|---|---|
| `MUSE_HOST=0.0.0.0` sem autenticação | Qualquer um na rede usa seu GPU |
| Liberar 8080 no firewall “só um pouco” | Exposição acidental |
| Commitar `secrets/api-key` | Vazamento |
| Prometer velocidade de cloud | Hardware local é hybrid ~4–7 t/s |

### 4.6 Encerrar o compartilhamento

1. Colegas fecham o `ssh -N -L ...`  
2. Você rotaciona a API key (se usou)  
3. Opcional: para o serviço

   ```bash
   systemctl --user stop muse-glimmer.service
   ```

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

| Sintoma | Ação |
|---|---|
| `ERR_CONNECTION_REFUSED` | `systemctl --user restart muse-glimmer` ou `./scripts/install-systemd-user.sh` |
| Cai ao fechar o terminal | Use systemd user (não `nohup` no shell do Cursor) |
| Muito lento | Normal em 8 GB VRAM; use `perf-q3` e `reasoning_strength=low` |
| Colega não abre | Túnel SSH ativo? Health no **127.0.0.1:8080 dele**? Key correta? |
| CORS / UI estranha remoto | Sempre abra a UI via o túnel (`127.0.0.1`), não pelo IP da workstation |

---

## 7. Checklist rápido

**Só você**

- [ ] `muse-glimmer` active  
- [ ] http://127.0.0.1:8080/health → ok  
- [ ] Chat responde  

**Compartilhar**

- [ ] Serviço ativo  
- [ ] SSH do colega ok  
- [ ] `ssh -N -L 8080:127.0.0.1:8080 ...`  
- [ ] API key (recomendado)  
- [ ] Sem porta 8080 aberta na LAN  

**Encerrar**

- [ ] Túnel fechado  
- [ ] Key rotacionada  
- [ ] Serviço parado se não for usar  

---

## 8. Referências (Muse only)

| Doc | Assunto |
|---|---|
| [RUNBOOK.md](RUNBOOK.md) | Operação e perfis |
| [PERFORMANCE.md](PERFORMANCE.md) | Números tok/s |
| [SECURITY.md](SECURITY.md) | Controles de segurança |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Arquitetura técnica |
| [../README.md](../README.md) | Visão do repositório glimmerlocal |
