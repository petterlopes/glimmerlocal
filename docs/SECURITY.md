# Segurança — glimmerlocal / Muse Glimmer

## Controles padrão deste stack

1. **Bind localhost** (`127.0.0.1`) — não escuta em `0.0.0.0`.
2. **CORS restrito** a `http://127.0.0.1:<port>` e `http://localhost:<port>`.
3. **Sem agent tools embutidos** no `llama-server` (`--no-agent` implícito ao não habilitar).
4. **Fonte única de pesos**: Hugging Face `meta-models/*` + verificação SHA-256.
5. **Segredos fora do Git**: `config/muse-glimmer.env`, `secrets/`, `HF_TOKEN`.

## Ameaças relevantes

| Risco | Mitigação |
|---|---|
| Exposição da API na LAN | Manter `MUSE_HOST=127.0.0.1`; firewall; se remoto, túnel + API key |
| Supply chain de pesos | Pins + `inventory/checksums.sha256` + download oficial |
| Prompt/tool injection em agentes | Não conectar shell/filesystem sem allowlist; revisar scaffolds |
| CORS `*` sem API key | Já restringido nos scripts; não remova sem autenticação |
| Vazamento de contexto pessoal | Tratar logs; não versionar transcripts |

## API key (opcional, recomendado se sair de localhost)

`llama-server` aceita `--api-key`. Gere fora do Git:

```bash
mkdir -p secrets && chmod 700 secrets
openssl rand -base64 32 > secrets/api-key
chmod 600 secrets/api-key
```

Passe via flag/env no unit systemd (não commitado). Clientes: header `Authorization: Bearer <key>`.

API key (opcional, recomendada se o serviço for consumido por mais do que o dono da máquina):

→ [GUIA_MUSE.md](GUIA_MUSE.md)

Partilha remota / NetBird / MCP: documentação **apenas** em `peritumct-sec-platform` (repositório privado).

## Memlock

`mmap+mlock` melhora residência, mas exige `ulimit -l` alto. Só altere limits do sistema com mudança explícita e revisada; o default seguro é `mmap`.

## Compliance de licença

- Muse Glimmer weights: **Apache 2.0** (Meta)
- llama.cpp: licença do upstream (MIT-style no projeto ggml)
- Este repositório glimmerlocal: documentação/scripts para uso interno PeritumCT — não redistribui pesos
