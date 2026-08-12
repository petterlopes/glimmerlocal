#!/usr/bin/env bash
# Retrieve RAG + chat Muse (on-demand). Garante Muse UP se --ensure-muse.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/rag-bridge.sh
source "${REPO}/scripts/lib/rag-bridge.sh"
rag_bridge_load

ENSURE=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --ensure-muse) ENSURE=1 ;;
    *) ARGS+=("$a") ;;
  esac
done

if [[ "$ENSURE" == "1" ]]; then
  if ! curl -fsS --max-time 2 "http://${MUSE_HOST}:${MUSE_PORT}/health" >/dev/null 2>&1; then
    echo "[rag-chat] Muse DOWN — a iniciar…"
    bash "${REPO}/scripts/muse-adminctl.sh" start
  fi
fi

exec python3 "${REPO}/scripts/rag-chat.py" "${ARGS[@]}"
