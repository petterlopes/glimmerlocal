#!/usr/bin/env bash
# Controlo do MCP RAG (loopback) via systemd --user — estável fora do shell.
# Uso: ./scripts/rag-mcpctl.sh {status|start|stop|restart|logs|install}
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT=rag-mcp.service
UNIT_SRC="${REPO}/systemd/rag-mcp.service"
UNIT_DST="${HOME}/.config/systemd/user/${UNIT}"
HOST="${RAG_MCP_HOST:-127.0.0.1}"
PORT="${RAG_MCP_PORT:-8091}"

log() { printf '[rag-mcp] %s\n' "$*"; }
die() { log "FALHA: $*"; exit 1; }

[[ "$HOST" == "127.0.0.1" || "$HOST" == "localhost" || "$HOST" == "::1" ]] \
  || die "só loopback permitido (RAG_MCP_HOST=$HOST)"

cmd_install() {
  mkdir -p "${HOME}/.config/systemd/user"
  install -m 0644 "$UNIT_SRC" "$UNIT_DST"
  systemctl --user daemon-reload
  systemctl --user disable "$UNIT" 2>/dev/null || true
  log "unit instalada (boot=disabled): $UNIT_DST"
}

cmd_status() {
  systemctl --user --no-pager status "$UNIT" 2>/dev/null | head -16 || log "unit não instalada"
  if curl -fsS --max-time 2 -X POST "http://${HOST}:${PORT}/mcp" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"rag-mcpctl","version":"0"}}}' \
    >/dev/null 2>&1; then
    log "endpoint http://${HOST}:${PORT}/mcp OK"
  else
    log "endpoint http://${HOST}:${PORT}/mcp DOWN"
  fi
}

cmd_start() {
  [[ -f "$UNIT_DST" ]] || cmd_install
  # shellcheck source=lib/rag-bridge.sh
  source "${REPO}/scripts/lib/rag-bridge.sh"
  rag_bridge_load
  systemctl --user start "$UNIT"
  sleep 1
  cmd_status
}

cmd_stop() {
  systemctl --user stop "$UNIT" 2>/dev/null || true
  pkill -f 'scripts/rag_mcp_server.py' 2>/dev/null || true
  log "parado"
}

cmd_logs() {
  journalctl --user -u "$UNIT" -n 80 --no-pager
}

cmd="${1:-status}"
case "$cmd" in
  status) cmd_status ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  restart) cmd_stop; cmd_start ;;
  logs) cmd_logs ;;
  install) cmd_install ;;
  -h|--help) sed -n '2,4p' "$0" ;;
  *) echo "uso: $0 {status|start|stop|restart|logs|install}"; exit 2 ;;
esac
