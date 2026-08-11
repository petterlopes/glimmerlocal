#!/usr/bin/env bash
# Install + start Muse Glimmer as a systemd --user service (survives Cursor shell teardown).
set -euo pipefail
LOG=/run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal/docs/perf-results/systemd-install.log
exec >"$LOG" 2>&1
REPO=/run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal
UNIT_DIR="${HOME}/.config/systemd/user"
UNIT="${UNIT_DIR}/muse-glimmer.service"

echo "=== $(date -Is) ==="
mkdir -p "${UNIT_DIR}"

# Ensure active env is perf-q3
cp "${REPO}/config/profiles/perf-q3.env" "${REPO}/config/muse-glimmer.env"
chmod 600 "${REPO}/config/muse-glimmer.env"

# Stop any orphan server first
pkill -9 -f '/tools/llama.cpp/build/bin/llama-server' 2>/dev/null || true
sleep 2
rm -f /run/media/petterlopes/SSD930/tools/muse-glimmer/logs/llama-server.pid

install -m 0644 "${REPO}/systemd/muse-glimmer.service" "${UNIT}"
# Prefer EnvironmentFile from repo (already in unit)
systemctl --user daemon-reload
systemctl --user enable muse-glimmer.service
systemctl --user restart muse-glimmer.service

# linger so it survives logout (best-effort)
loginctl enable-linger "$(whoami)" 2>/dev/null || true

for i in $(seq 1 90); do
  if curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1; then
    echo "health ok after ${i}s"
    systemctl --user --no-pager status muse-glimmer.service | head -20
    curl -fsS http://127.0.0.1:8080/health; echo
    nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader || true
    echo SUCCESS
    exit 0
  fi
  if ! systemctl --user is-active --quiet muse-glimmer.service; then
    echo "service not active"
    systemctl --user --no-pager status muse-glimmer.service || true
    journalctl --user -u muse-glimmer -n 40 --no-pager || true
    exit 1
  fi
  sleep 1
done
echo TIMEOUT
systemctl --user --no-pager status muse-glimmer.service || true
journalctl --user -u muse-glimmer -n 40 --no-pager || true
exit 1
