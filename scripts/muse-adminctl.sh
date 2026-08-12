#!/usr/bin/env bash
# Controlo administrativo Muse Glimmer (systemd --user) — on-demand.
# Não arranca no login; use start/menu antes do chat.
#
# Uso:
#   ./scripts/muse-adminctl.sh status|start|stop|restart|logs|vram|menu|rag-status|rag-mcp
#   ./scripts/muse-adminctl.sh install-unit   # instala unit sem enable
#   ./scripts/muse-adminctl.sh disable-boot   # remove autostart no login
#
# Menu gráfico: ./scripts/muse-admin-menu.sh  (ou acção "menu")
# RAG chat CLI: ./scripts/rag-chat.sh --ensure-muse -q "…"
# RAG MCP UI:   ./scripts/rag-mcpctl.sh start  → Muse «MCP Servers» → peritumct-rag
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT=muse-glimmer.service
UNIT_SRC="${REPO}/systemd/muse-glimmer.service"
UNIT_DST="${HOME}/.config/systemd/user/${UNIT}"
ENV_FILE="${REPO}/config/muse-glimmer.env"

log() { printf '[muse-admin] %s\n' "$*"; }
die() { log "FALHA: $*"; exit 1; }

load_muse_endpoints() {
  MUSE_HOST=127.0.0.1
  MUSE_PORT=8080
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
  fi
  : "${MUSE_HOST:=127.0.0.1}"
  : "${MUSE_PORT:=8080}"
}

health_ok() {
  load_muse_endpoints
  local url
  for url in "http://${MUSE_HOST}:${MUSE_PORT}/health" "http://127.0.0.1:${MUSE_PORT}/health"; do
    if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
      printf '%s' "$url"
      return 0
    fi
  done
  return 1
}

wait_health() {
  local i url
  log "Aguardando health (modelo a carregar na GPU)…"
  for i in $(seq 1 120); do
    if url="$(health_ok)"; then
      log "health OK (${url}) após ${i}s"
      return 0
    fi
    if ! systemctl --user is-active --quiet "$UNIT" 2>/dev/null; then
      log "serviço inactivo durante wait"
      systemctl --user --no-pager status "$UNIT" || true
      return 1
    fi
    sleep 1
  done
  die "timeout health — ver: $0 logs"
}

cmd_status() {
  load_muse_endpoints
  local st enabled health vram
  st="$(systemctl --user is-active "$UNIT" 2>/dev/null || echo inactive)"
  enabled="$(systemctl --user is-enabled "$UNIT" 2>/dev/null || echo disabled)"
  if health="$(health_ok)"; then
    health="OK ($health)"
  else
    health="DOWN"
  fi
  vram="$(nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader 2>/dev/null || echo 'n/a')"
  cat <<EOF
Unit:     ${UNIT}
Active:   ${st}
Boot:     ${enabled}  (deve ser disabled = on-demand)
Health:   ${health}
Bind:     ${MUSE_HOST}:${MUSE_PORT}
VRAM:     ${vram}
EOF
  systemctl --user --no-pager status "$UNIT" 2>/dev/null | head -18 || true
}

cmd_install_unit() {
  mkdir -p "${HOME}/.config/systemd/user"
  install -m 0644 "$UNIT_SRC" "$UNIT_DST"
  systemctl --user daemon-reload
  # On-demand: unit instalada mas NÃO enabled
  systemctl --user disable "$UNIT" 2>/dev/null || true
  log "unit instalada: $UNIT_DST (boot=disabled)"
}

cmd_disable_boot() {
  systemctl --user disable "$UNIT" 2>/dev/null || true
  log "autostart removido (WantedBy offline)"
}

cmd_start() {
  [[ -f "$UNIT_DST" ]] || cmd_install_unit
  # Garantir SSD montado (path no ExecStart)
  [[ -x "${REPO}/scripts/start-server-fg.sh" ]] || die "repo/SSD inacessível: ${REPO}"
  # MCP RAG (loopback) — necessário para a UI Muse consumir retrieve
  if [[ "${MUSE_RAG_MCP_AUTOSTART:-1}" == "1" ]]; then
    bash "${REPO}/scripts/rag-mcpctl.sh" start || log "aviso: rag-mcp não arrancou (UI sem tools RAG)"
  fi
  systemctl --user start "$UNIT"
  wait_health
  cmd_vram
}

cmd_stop() {
  systemctl --user stop "$UNIT" 2>/dev/null || true
  # limpar órfãos se Restart deixou residual
  pkill -f '/tools/llama.cpp/build/bin/llama-server' 2>/dev/null || true
  sleep 1
  if [[ "${MUSE_RAG_MCP_STOP_WITH_MUSE:-1}" == "1" ]]; then
    bash "${REPO}/scripts/rag-mcpctl.sh" stop 2>/dev/null || true
  fi
  log "parado"
  cmd_vram
}

cmd_restart() {
  cmd_stop
  cmd_start
}

cmd_logs() {
  journalctl --user -u "$UNIT" -n 80 --no-pager
}

cmd_vram() {
  if command -v nvidia-smi >/dev/null; then
    nvidia-smi --query-gpu=name,memory.used,memory.free,utilization.gpu --format=csv
    nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv 2>/dev/null || true
  else
    log "nvidia-smi indisponível"
  fi
}

usage() {
  sed -n '2,12p' "$0"
}

cmd="${1:-status}"
case "$cmd" in
  status) cmd_status ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  restart) cmd_restart ;;
  logs) cmd_logs ;;
  vram) cmd_vram ;;
  install-unit) cmd_install_unit ;;
  disable-boot) cmd_disable_boot ;;
  menu) exec bash "${REPO}/scripts/muse-admin-menu.sh" ;;
  rag-status) exec bash "${REPO}/scripts/rag-status.sh" ;;
  rag-mcp) shift; exec bash "${REPO}/scripts/rag-mcpctl.sh" "${1:-status}" ;;
  -h|--help) usage ;;
  *) usage; exit 2 ;;
esac
