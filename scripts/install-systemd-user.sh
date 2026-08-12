#!/usr/bin/env bash
# Instala a unit systemd --user do Muse Glimmer (on-demand por omissão).
#
# Uso:
#   ./scripts/install-systemd-user.sh              # instala unit, SEM enable, SEM start
#   ./scripts/install-systemd-user.sh --start      # instala + start agora (chat)
#   ./scripts/install-systemd-user.sh --enable-boot  # NÃO recomendado em desktop partilhado
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_DIR="${HOME}/.config/systemd/user"
UNIT="${UNIT_DIR}/muse-glimmer.service"
DO_START=0
ENABLE_BOOT=0

for arg in "$@"; do
  case "$arg" in
    --start) DO_START=1 ;;
    --enable-boot) ENABLE_BOOT=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "argumento desconhecido: $arg" >&2; exit 2 ;;
  esac
done

echo "=== $(date -Is) install-systemd-user (on-demand) ==="
mkdir -p "${UNIT_DIR}"

# Preservar muse-glimmer.env se já existir (NetBird host + FIT_TARGET desktop).
# Só criar a partir do perfil se em falta.
if [[ ! -f "${REPO}/config/muse-glimmer.env" ]]; then
  if [[ -f "${REPO}/config/profiles/desktop-ondemand.env" ]]; then
    cp "${REPO}/config/profiles/desktop-ondemand.env" "${REPO}/config/muse-glimmer.env"
  else
    cp "${REPO}/config/profiles/perf-q3.env" "${REPO}/config/muse-glimmer.env"
  fi
  chmod 600 "${REPO}/config/muse-glimmer.env"
  echo "criado config/muse-glimmer.env"
else
  echo "mantido config/muse-glimmer.env existente (não sobrescrito)"
fi

install -m 0644 "${REPO}/systemd/muse-glimmer.service" "${UNIT}"
systemctl --user daemon-reload

if [[ "$ENABLE_BOOT" == "1" ]]; then
  systemctl --user enable muse-glimmer.service
  echo "AVISO: autostart no login ACTIVADO — consome VRAM ao arrancar a sessão"
else
  systemctl --user disable muse-glimmer.service 2>/dev/null || true
  echo "boot: disabled (on-demand — use muse-adminctl / menu Admin)"
fi

if [[ "$DO_START" == "1" ]]; then
  exec bash "${REPO}/scripts/muse-adminctl.sh" start
fi

echo "OK: unit em ${UNIT}"
echo "Chat: ./scripts/muse-adminctl.sh start   |   menu: ./scripts/install-desktop-admin.sh"
