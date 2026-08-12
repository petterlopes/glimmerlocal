#!/usr/bin/env python3
"""Retrieve híbrido (RAG plataforma) → resposta via Muse /v1/chat/completions.

Não duplica Postgres. Não escreve casos no corpus. Role rag_query apenas.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


def _ensure_rag_path() -> Path:
    root = os.environ.get("RAG_ROOT")
    if not root:
        raise SystemExit("RAG_ROOT não definido — use scripts/rag-chat.sh")
    p = Path(root)
    if not p.is_dir():
        raise SystemExit(f"RAG_ROOT inválido: {root}")
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))
    return p


def muse_chat(prompt: str) -> str:
    base = os.environ.get("MUSE_BASE_URL", "http://127.0.0.1:8080/v1").rstrip("/")
    model = os.environ.get("MUSE_MODEL", "muse-glimmer-30B")
    max_tokens = int(os.environ.get("MUSE_MAX_TOKENS", "1024"))
    strength = os.environ.get("MUSE_REASONING_STRENGTH", "low")
    url = f"{base}/chat/completions"
    body = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "És um assistente técnico. Responde com base nos trechos RAG fornecidos. "
                    "Cita páginas/documentos. Não inventes factos fora dos trechos. "
                    "Não trates depoimentos ou PII processual — só literatura/protocolo."
                ),
            },
            {"role": "user", "content": prompt},
        ],
        "max_tokens": max_tokens,
        "temperature": 1.0,
        "chat_template_kwargs": {"reasoning_strength": strength},
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Authorization": "Bearer local"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            data = json.loads(resp.read().decode())
    except urllib.error.URLError as exc:
        raise SystemExit(
            f"Muse indisponível em {url}: {exc}\n→ ./scripts/muse-adminctl.sh start"
        ) from exc
    try:
        return data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise SystemExit(f"Resposta Muse inesperada: {data!r}") from exc


def main() -> int:
    ap = argparse.ArgumentParser(description="RAG retrieve → Muse chat (glimmerlocal)")
    ap.add_argument("-q", "--question", required=True)
    ap.add_argument("--max-agents", type=int, default=1)
    ap.add_argument("--dry-retrieve", action="store_true", help="Só retrieve, sem Muse")
    ap.add_argument("--no-log", action="store_true", help="Não gravar agent_runs")
    args = ap.parse_args()

    _ensure_rag_path()
    from agents.retrieve import dsn, hybrid_search, list_agents, log_run
    from agents.router import route_question
    from agents.run_query import build_prompt, embed

    import psycopg

    t0 = time.perf_counter()
    routes_meta: list
    agent_slug: str
    retrieved_meta: list
    prompt: str

    with psycopg.connect(dsn()) as conn:
        agents = list_agents(conn)
        if not agents:
            print("Nenhum agente enabled no RAG.", file=sys.stderr)
            return 1
        agent_rows = [
            {
                "slug": a["slug"],
                "domain_slug": a["domain_slug"],
                "display_name": a["display_name"],
                "title": a["title"],
                "description": a["description"],
            }
            for a in agents
        ]
        routes = route_question(args.question, agent_rows, max_agents=args.max_agents)
        print("## Router")
        for r in routes:
            print(f"- {r.agent_slug} ({r.domain_slug}) score={r.score} [{r.reason}]")
        if not routes:
            return 1

        emb = embed(args.question)
        if emb is None:
            print("Sem embedding (RAG_EMBED_BACKEND=fastembed?).", file=sys.stderr)
            return 1

        by_slug = {a["slug"]: a for a in agents}
        r0 = routes[0]
        agent = by_slug[r0.agent_slug]
        chunks = hybrid_search(
            conn,
            domain_id=int(agent["domain_id"]),
            query_embedding=emb,
            query_text=args.question,
            ef_search=int(agent["ef_search"]),
            limit=int(agent["top_k"]),
        )
        print(f"\n## Retrieve — {agent['display_name']}: {len(chunks)} chunks")
        prompt = build_prompt(agent, args.question, chunks)
        routes_meta = [x.__dict__ for x in routes]
        agent_slug = r0.agent_slug
        retrieved_meta = [
            {
                "chunk_id": c["chunk_id"],
                "rrf": float(c["rrf_score"]) if c.get("rrf_score") is not None else None,
                "page_from": c.get("page_from"),
            }
            for c in chunks
        ]
        # Commit/fecha antes do Muse (evita idle_in_transaction_session_timeout)
        conn.commit()

    if args.dry_retrieve:
        print(prompt[:6000] + ("…" if len(prompt) > 6000 else ""))
        return 0

    print("\n## Muse…")
    answer = muse_chat(prompt)
    print(answer)
    latency = int((time.perf_counter() - t0) * 1000)
    print(f"\n## latency_ms={latency}")
    if not args.no_log:
        with psycopg.connect(dsn()) as conn:
            log_run(
                conn,
                question=args.question,
                router_choice=routes_meta,
                agent_slug=agent_slug,
                retrieved=retrieved_meta,
                answer=answer[:8000],
                latency_ms=latency,
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
