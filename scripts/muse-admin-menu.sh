#!/usr/bin/env bash
# Menu gráfico de administração Muse Glimmer (zenity / notify-send).
# Arranque on-demand: Iniciar só quando for usar chat.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CTL="${REPO}/scripts/muse-adminctl.sh"
TITLE="Muse Glimmer — Administração"

[[ -x "$CTL" ]] || chmod +x "$CTL" "${REPO}/scripts/muse-adminctl.sh" 2>/dev/null || true

notify() {
  local msg=$1
  notify-send "$TITLE" "$msg" 2>/dev/null || true
  printf '%s\n' "$msg"
}

if ! command -v zenity >/dev/null; then
  echo "zenity em falta — use: $CTL {start|stop|restart|status}" >&2
  exec "$CTL" status
fi

choice="$(zenity --list \
  --title="$TITLE" \
  --text="Serviço de chat on-demand (não arranca no login).\nEscolha uma acção:" \
  --column="Acção" --column="Descrição" \
  --width=520 --height=360 \
  "status" "Estado + health + VRAM" \
  "start" "Iniciar Muse (carrega modelo ~GPU)" \
  "stop" "Parar Muse (liberta VRAM)" \
  "restart" "Reiniciar Muse" \
  "logs" "Últimos logs do serviço" \
  "vram" "Só nvidia-smi" \
  "rag-status" "Estado RAG (Postgres) + Muse" \
  "rag-mcp-start" "Iniciar MCP RAG (UI Muse tools)" \
  "rag-mcp-stop" "Parar MCP RAG" \
  "disable-boot" "Garantir: sem autostart no login" \
  2>/dev/null || true)"

[[ -n "${choice:-}" ]] || exit 0

case "$choice" in
  start|restart)
    notify "A ${choice}… aguarde o load do modelo."
    if out="$("$CTL" "$choice" 2>&1)"; then
      zenity --info --title="$TITLE" --width=480 --text="$(printf '%s' "$out" | sed 's/&/\&amp;/g' | head -40)" 2>/dev/null || printf '%s\n' "$out"
      notify "Muse pronto para chat."
    else
      zenity --error --title="$TITLE" --width=480 --text="$(printf '%s' "$out" | sed 's/&/\&amp;/g' | tail -30)" 2>/dev/null || printf '%s\n' "$out" >&2
      notify "Falha ao ${choice}."
      exit 1
    fi
    ;;
  stop|disable-boot)
    out="$("$CTL" "$choice" 2>&1)" || true
    zenity --info --title="$TITLE" --width=420 --text="$(printf '%s' "$out" | sed 's/&/\&amp;/g')" 2>/dev/null || printf '%s\n' "$out"
    notify "Muse parado / sem autostart."
    ;;
  status|vram|logs)
    out="$("$CTL" "$choice" 2>&1)" || true
    # logs podem ser longos
    zenity --text-info --title="$TITLE — $choice" --width=700 --height=500 \
      --filename=<(printf '%s\n' "$out") 2>/dev/null || printf '%s\n' "$out"
    ;;
  rag-status)
    out="$(bash "${REPO}/scripts/rag-status.sh" 2>&1)" || true
    zenity --text-info --title="$TITLE — RAG" --width=700 --height=500 \
      --filename=<(printf '%s\n' "$out") 2>/dev/null || printf '%s\n' "$out"
    ;;
  rag-mcp-start)
    out="$(bash "${REPO}/scripts/rag-mcpctl.sh" start 2>&1)" || true
    zenity --info --title="$TITLE" --width=480 --text="$(printf '%s' "$out" | sed 's/&/\&amp;/g')" 2>/dev/null || printf '%s\n' "$out"
    notify "MCP RAG em http://127.0.0.1:8091/mcp — na UI Muse: MCP Servers → peritumct-rag (useProxy)."
    ;;
  rag-mcp-stop)
    out="$(bash "${REPO}/scripts/rag-mcpctl.sh" stop 2>&1)" || true
    zenity --info --title="$TITLE" --width=420 --text="$(printf '%s' "$out" | sed 's/&/\&amp;/g')" 2>/dev/null || printf '%s\n' "$out"
    ;;
  *)
    exit 0
    ;;
esac
