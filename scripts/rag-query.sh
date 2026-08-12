#!/usr/bin/env bash
# Proxy fino para agents.run_query da plataforma (só retrieve/prompt).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/rag-bridge.sh
source "${REPO}/scripts/lib/rag-bridge.sh"
rag_bridge_load
cd "$RAG_ROOT"
exec python3 -m agents.run_query "$@"
