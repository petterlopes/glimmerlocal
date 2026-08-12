#!/usr/bin/env bash
# Instala atalho de administração Muse no menu GNOME (on-demand).
#
# Uso:
#   ./scripts/install-desktop-admin.sh
#   ./scripts/install-desktop-admin.sh --desktop
#   ./scripts/install-desktop-admin.sh --uninstall
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="peritumct-muse-glimmer-admin"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP_FILE="${APP_DIR}/${APP_ID}.desktop"
MENU="${REPO}/scripts/muse-admin-menu.sh"
CTL="${REPO}/scripts/muse-adminctl.sh"
COPY_DESKTOP=0
UNINSTALL=0

log() { printf '[muse-desktop-admin] %s\n' "$*"; }
die() { log "FALHA: $*"; exit 1; }

for arg in "$@"; do
  case "$arg" in
    --desktop) COPY_DESKTOP=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) die "argumento desconhecido: $arg" ;;
  esac
done

chmod +x "$MENU" "$CTL" 2>/dev/null || true

if [[ "$UNINSTALL" == "1" ]]; then
  rm -f "$DESKTOP_FILE"
  rm -f "${XDG_DESKTOP_DIR:-$HOME/Desktop}/${APP_ID}.desktop"
  rm -f "${HOME}/Área de Trabalho/${APP_ID}.desktop" 2>/dev/null || true
  command -v update-desktop-database >/dev/null && update-desktop-database "$APP_DIR" 2>/dev/null || true
  log "atalho removido"
  exit 0
fi

[[ -f "$MENU" ]] || die "menu em falta: $MENU"
mkdir -p "$APP_DIR"

cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Muse Glimmer Admin
Name[pt_BR]=Muse Glimmer — Administração
GenericName=Chat LLM local (on-demand)
Comment=Iniciar / parar / reiniciar Muse Glimmer (não consome GPU no login)
Comment[pt_BR]=Iniciar, parar e reiniciar o serviço de chat Muse (on-demand)
Exec=${MENU}
TryExec=${MENU}
Icon=utilities-terminal
Terminal=false
Categories=System;Settings;
Keywords=muse;glimmer;llm;chat;peritumct;admin;
StartupNotify=true
Actions=Start;Stop;Restart;Status;

[Desktop Action Start]
Name=Iniciar Muse
Name[pt_BR]=Iniciar Muse
Exec=${CTL} start

[Desktop Action Stop]
Name=Parar Muse
Name[pt_BR]=Parar Muse
Exec=${CTL} stop

[Desktop Action Restart]
Name=Reiniciar Muse
Name[pt_BR]=Reiniciar Muse
Exec=${CTL} restart

[Desktop Action Status]
Name=Estado / VRAM
Name[pt_BR]=Estado / VRAM
Exec=${CTL} status
EOF
chmod 644 "$DESKTOP_FILE"

if [[ "$COPY_DESKTOP" == "1" ]]; then
  for desk in "$(xdg-user-dir DESKTOP 2>/dev/null || true)" "$HOME/Desktop" "$HOME/Área de Trabalho"; do
    [[ -n "$desk" && -d "$desk" ]] || continue
    install -m 755 "$DESKTOP_FILE" "${desk}/${APP_ID}.desktop"
    command -v gio >/dev/null && gio set "${desk}/${APP_ID}.desktop" metadata::trusted true 2>/dev/null || true
    log "copiado para ${desk}/${APP_ID}.desktop"
    break
  done
fi

command -v update-desktop-database >/dev/null && update-desktop-database "$APP_DIR" 2>/dev/null || true
log "instalado: $DESKTOP_FILE"
log "menu:      Super → «Muse Glimmer Admin»"
log "CLI:       $CTL {start|stop|restart|status}"
