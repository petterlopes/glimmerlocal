#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
ialocal_load_env

if [[ ! -f "${PIDFILE}" ]]; then
  echo "not running (no pidfile)"
  exit 0
fi
PID="$(cat "${PIDFILE}")"
if kill -0 "${PID}" 2>/dev/null; then
  kill "${PID}"
  for _ in $(seq 1 30); do
    kill -0 "${PID}" 2>/dev/null || break
    sleep 0.5
  done
  if kill -0 "${PID}" 2>/dev/null; then
    kill -9 "${PID}" || true
  fi
  echo "stopped pid=${PID}"
else
  echo "stale pidfile (pid=${PID} not alive)"
fi
rm -f "${PIDFILE}"
