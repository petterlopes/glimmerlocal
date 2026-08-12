#!/usr/bin/env python3
"""MCP Streamable-HTTP — retrieve RAG (plataforma) para a UI Muse / agentes.

Bind default: 127.0.0.1:8091/mcp  (nunca 0.0.0.0)
Role: rag_query · corpus literatura · sem PII processual
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def _bootstrap_env() -> None:
    """Load rag-bridge + platform secrets if present (CLI / systemd)."""
    repo = Path(__file__).resolve().parents[1]
    bridge = Path(os.environ.get("RAG_BRIDGE_ENV", repo / "config/rag-bridge.env"))
    if bridge.is_file():
        for line in bridge.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            k, v = k.strip(), v.strip().strip("'\"")
            # expand ${HOME} etc. lightly
            v = os.path.expandvars(v)
            os.environ.setdefault(k, v)
    rag_root = os.environ.get("RAG_ROOT")
    if not rag_root:
        raise SystemExit("RAG_ROOT em falta — configure config/rag-bridge.env")
    rag_env = Path(os.environ.get("RAG_ENV_FILE", f"{rag_root}/secrets/rag.env"))
    if rag_env.is_file():
        for line in rag_env.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            os.environ.setdefault(k.strip(), v.strip().strip("'\""))
    os.environ.setdefault("RAG_PG_HOST", "127.0.0.1")
    os.environ.setdefault("RAG_PG_PORT", "5433")
    os.environ.setdefault("RAG_PG_USER", "rag_query")
    os.environ.setdefault("PGSSLMODE", "disable")
    os.environ.setdefault("RAG_EMBED_BACKEND", "fastembed")
    os.environ.setdefault(
        "FASTEMBED_CACHE_PATH",
        str(Path.home() / ".cache/peritumct/fastembed"),
    )
    if rag_root not in sys.path:
        sys.path.insert(0, rag_root)


def _retrieve(question: str, max_agents: int = 1, limit: int | None = None) -> str:
    from agents.retrieve import dsn, hybrid_search, list_agents
    from agents.router import route_question
    from agents.run_query import build_prompt, embed

    import psycopg

    with psycopg.connect(dsn()) as conn:
        agents = list_agents(conn)
        if not agents:
            return "ERRO: nenhum agente RAG enabled."
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
        routes = route_question(question, agent_rows, max_agents=max_agents)
        if not routes:
            return "ERRO: router sem agente para a pergunta."
        emb = embed(question)
        if emb is None:
            return "ERRO: embedding indisponível (RAG_EMBED_BACKEND=fastembed?)."
        by_slug = {a["slug"]: a for a in agents}
        r0 = routes[0]
        agent = by_slug[r0.agent_slug]
        top_k = int(limit) if limit else int(agent["top_k"])
        chunks = hybrid_search(
            conn,
            domain_id=int(agent["domain_id"]),
            query_embedding=emb,
            query_text=question,
            ef_search=int(agent["ef_search"]),
            limit=top_k,
        )
        conn.commit()
        meta = {
            "agent": agent["slug"],
            "domain": agent["domain_slug"],
            "chunks": len(chunks),
            "routes": [x.__dict__ for x in routes],
        }
        body = build_prompt(agent, question, chunks)
        return json.dumps(meta, ensure_ascii=False) + "\n\n" + body


def build_server() -> object:
    from mcp.server.mcpserver import MCPServer

    server = MCPServer(
        name="peritumct-rag",
        title="Peritumct RAG (Postgres+pgvector)",
        instructions=(
            "Ferramenta de retrieve documental Peritumct. "
            "Usa rag_search antes de responder perguntas sobre literatura, "
            "privacy engineering, psicologia, neurociências ou protocolo. "
            "Cita páginas dos trechos. Não inventes cláusulas. "
            "Proibido: depoimentos, PII processual ou mutação do corpus."
        ),
    )

    @server.tool()
    def rag_search(question: str, max_agents: int = 1, limit: int = 8) -> str:
        """Pesquisa híbrida no RAG local (pgvector) e devolve trechos citados.

        Args:
            question: Pergunta em linguagem natural (literatura/protocolo apenas).
            max_agents: Nº máximo de agentes/domínios a considerar (default 1).
            limit: Máximo de chunks a devolver (default 8).
        """
        return _retrieve(question, max_agents=max_agents, limit=limit)

    @server.tool()
    def rag_domains() -> str:
        """Lista domínios e agentes RAG enabled (metadados, sem conteúdo)."""
        from agents.retrieve import dsn, list_agents

        import psycopg

        with psycopg.connect(dsn()) as conn:
            agents = list_agents(conn)
        rows = [
            {
                "agent": a["slug"],
                "domain": a["domain_slug"],
                "name": a["display_name"],
                "title": a["title"],
            }
            for a in agents
        ]
        return json.dumps(rows, ensure_ascii=False, indent=2)

    return server


def main() -> int:
    ap = argparse.ArgumentParser(description="MCP RAG Peritumct (streamable-http|stdio)")
    ap.add_argument("--host", default=os.environ.get("RAG_MCP_HOST", "127.0.0.1"))
    ap.add_argument("--port", type=int, default=int(os.environ.get("RAG_MCP_PORT", "8091")))
    ap.add_argument(
        "--transport",
        choices=("streamable-http", "stdio"),
        default=os.environ.get("RAG_MCP_TRANSPORT", "streamable-http"),
    )
    args = ap.parse_args()

    if args.host not in ("127.0.0.1", "localhost", "::1"):
        print(
            "RECUSADO: RAG MCP só em loopback (127.0.0.1). "
            f"Pedido: {args.host}",
            file=sys.stderr,
        )
        return 2

    _bootstrap_env()
    server = build_server()
    if args.transport == "stdio":
        server.run(transport="stdio")
    else:
        print(
            f"[rag-mcp] streamable-http http://{args.host}:{args.port}/mcp",
            file=sys.stderr,
        )
        server.run(
            transport="streamable-http",
            host=args.host,
            port=args.port,
            streamable_http_path="/mcp",
            stateless_http=True,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
