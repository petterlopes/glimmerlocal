#!/usr/bin/env bash
# Restart llama-server under a named profile and wait for health.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROFILE="${1:-}"
if [[ -z "${PROFILE}" ]]; then
  echo "usage: $0 <profile-name|path-to.env>" >&2
  exit 2
fi

if [[ -f "${PROFILE}" ]]; then
  ENV_FILE="${PROFILE}"
elif [[ -f "${REPO}/config/profiles/${PROFILE}.env" ]]; then
  ENV_FILE="${REPO}/config/profiles/${PROFILE}.env"
elif [[ -f "${REPO}/config/profiles/${PROFILE}" ]]; then
  ENV_FILE="${REPO}/config/profiles/${PROFILE}"
else
  echo "error: profile not found: ${PROFILE}" >&2
  exit 1
fi

export IALOCAL_ENV_FILE="${ENV_FILE}"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
ialocal_load_env

echo "==> stopping previous server (if any)"
"${SCRIPT_DIR}/stop-server.sh" || true
# also kill orphan llama-server on our port
if ss -ltnp 2>/dev/null | rg -q ":${MUSE_PORT}\\b"; then
  pkill -f "${LLAMA_BIN}" 2>/dev/null || true
  sleep 1
fi

: > "${LOGFILE}"
mkdir -p "$(dirname "${LOGFILE}")"
echo "==> starting with profile ${ENV_FILE}"
nohup env IALOCAL_ENV_FILE="${ENV_FILE}" "${SCRIPT_DIR}/start-server-fg.sh" \
  >>"${LOGFILE}" 2>&1 &
echo $! >"${PIDFILE}"
disown || true

echo "pid=$(cat "${PIDFILE}") waiting for health..."
for i in $(seq 1 180); do
  if ! kill -0 "$(cat "${PIDFILE}")" 2>/dev/null; then
    echo "process died; last log:" >&2
    tail -40 "${LOGFILE}" >&2
    exit 1
  fi
  if curl -fsS "http://${MUSE_HOST}:${MUSE_PORT}/health" >/dev/null 2>&1; then
    echo "ready after ${i}s"
    # show key cmdline
    tr '\0' ' ' <"/proc/$(cat "${PIDFILE}")/cmdline"; echo
    nvidia-smi --query-gpu=memory.used,memory.free,utilization.gpu --format=csv,noheader || true
    exit 0
  fi
  sleep 1
done
echo "timeout; log:" >&2
tail -60 "${LOGFILE}" >&2
exit 1
