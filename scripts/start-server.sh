#!/usr/bin/env bash
# Background launcher for Muse Glimmer llama-server
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
ialocal_load_env
ialocal_build_extra_args

if [[ ! -x "${LLAMA_BIN}" ]]; then
  echo "error: llama-server missing at ${LLAMA_BIN} — run ./scripts/build-llama-cpp.sh" >&2
  exit 1
fi
if [[ ! -f "${MODEL_GGUF}" ]]; then
  echo "error: model missing at ${MODEL_GGUF} — run ./scripts/download-model.sh" >&2
  exit 1
fi
if [[ -f "${PIDFILE}" ]] && kill -0 "$(cat "${PIDFILE}")" 2>/dev/null; then
  echo "already running pid=$(cat "${PIDFILE}") on ${MUSE_HOST}:${MUSE_PORT}"
  exit 0
fi

mkdir -p "${MUSE_RUNTIME}/logs"

LOAD_MODE="${MUSE_LOAD_MODE}"
if [[ -z "${LOAD_MODE}" ]]; then
  MEMLOCK_KB="$(ulimit -l 2>/dev/null || echo 0)"
  if [[ "${MEMLOCK_KB}" == "unlimited" ]] || { [[ "${MEMLOCK_KB}" =~ ^[0-9]+$ ]] && (( MEMLOCK_KB >= 20000000 )); }; then
    LOAD_MODE="mmap+mlock"
  else
    LOAD_MODE="mmap"
  fi
fi

ARGS=(
  -m "${MODEL_GGUF}"
  -a muse-glimmer-30B
  --host "${MUSE_HOST}"
  --port "${MUSE_PORT}"
  --jinja
  --fit on
  --fit-target "${MUSE_FIT_TARGET}"
  --fit-ctx "${MUSE_FIT_CTX}"
  -c "${MUSE_CTX}"
  -np 1
  -fa on
  -ctk q8_0
  -ctv q8_0
  -t "${MUSE_THREADS}"
  -tb "${MUSE_THREADS}"
  -b 512
  -ub 256
  --load-mode "${LOAD_MODE}"
  --cors-origins "${MUSE_CORS_ORIGINS:-http://127.0.0.1:${MUSE_PORT},http://localhost:${MUSE_PORT}}"
  --no-cors-credentials
  --reasoning-preserve
  --temp 1.0
  --top-p 0.95
  --top-k 64
  --chat-template-kwargs "{\"reasoning_strength\":\"${MUSE_REASONING}\"}"
  "${EXTRA_ARGS[@]}"
)

echo "starting Muse Glimmer on http://${MUSE_HOST}:${MUSE_PORT} (reasoning=${MUSE_REASONING}, vision=${MUSE_VISION}, load=${LOAD_MODE}, spec=${MUSE_SPEC_TYPE}, dflash=${MUSE_DFLASH}, fit=${MUSE_FIT_TARGET})"
nohup "${LLAMA_BIN}" "${ARGS[@]}" >"${LOGFILE}" 2>&1 &
echo $! >"${PIDFILE}"
disown || true
echo "pid=$(cat "${PIDFILE}") log=${LOGFILE}"
