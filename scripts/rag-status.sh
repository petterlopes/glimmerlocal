#!/usr/bin/env bash
# Estado do bridge RAG (plataforma) + Muse (glimmerlocal).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/rag-bridge.sh
source "${REPO}/scripts/lib/rag-bridge.sh"
rag_bridge_load

echo "== RAG (plataforma) =="
echo "RAG_ROOT=$RAG_ROOT"
echo "Bind: ${RAG_PG_HOST}:${RAG_PG_PORT} user=${RAG_PG_USER} sslmode=${PGSSLMODE}"
if command -v podman >/dev/null && podman inspect rag-pg --format '{{.State.Status}}' >/dev/null 2>&1; then
  echo -n "Container rag-pg: "
  podman inspect rag-pg --format 'status={{.State.Status}} memory={{.HostConfig.Memory}}' 2>/dev/null || true
  podman exec rag-pg pg_isready -U rag -d rag 2>/dev/null || echo "pg_isready FAIL"
else
  echo "Container rag-pg: (indisponível via podman neste host — use tsh db / túnel)"
fi

if [[ -n "${RAG_QUERY_PASSWORD:-}" ]]; then
  export PGPASSWORD="$RAG_QUERY_PASSWORD"
  if command -v psql >/dev/null; then
    psql -h "$RAG_PG_HOST" -p "$RAG_PG_PORT" -U rag_query -d "${POSTGRES_DB:-rag}" -c \
      "SELECT slug FROM domains ORDER BY 1;" 2>&1 | head -20 || true
  else
    # fallback via podman
    podman exec -e PGPASSWORD="$RAG_QUERY_PASSWORD" -e PGSSLMODE=disable rag-pg \
      psql -U rag_query -d "${POSTGRES_DB:-rag}" -c "SELECT slug FROM domains ORDER BY 1;" 2>&1 | head -20 || true
  fi
fi

echo
echo "== Muse (glimmerlocal) =="
echo "MUSE: ${MUSE_BASE_URL} model=${MUSE_MODEL}"
if curl -fsS --max-time 2 "http://${MUSE_HOST}:${MUSE_PORT}/health" >/dev/null 2>&1; then
  echo "Health: OK"
  curl -fsS --max-time 2 "http://${MUSE_HOST}:${MUSE_PORT}/health"; echo
else
  echo "Health: DOWN — ./scripts/muse-adminctl.sh start"
fi

echo
echo "== Contrato =="
echo "Retrieve: role rag_query · corpus literatura apenas · LLM só Muse"
echo "Docs: docs/INTEGRACAO_RAG.md"
