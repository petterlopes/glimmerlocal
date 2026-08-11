#!/usr/bin/env bash
# Foreground launcher (systemd / debugging / A/B profiles)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
ialocal_load_env
ialocal_build_extra_args

exec "${LLAMA_BIN}" \
  -m "${MODEL_GGUF}" \
  -a muse-glimmer-30B \
  --host "${MUSE_HOST}" \
  --port "${MUSE_PORT}" \
  --jinja \
  --fit on \
  --fit-target "${MUSE_FIT_TARGET}" \
  --fit-ctx "${MUSE_FIT_CTX}" \
  -c "${MUSE_CTX}" \
  -np 1 \
  -fa on \
  -ctk q8_0 \
  -ctv q8_0 \
  -t "${MUSE_THREADS}" \
  -tb "${MUSE_THREADS}" \
  -b 512 \
  -ub 256 \
  --load-mode "${MUSE_LOAD_MODE}" \
  --cors-origins "http://127.0.0.1:${MUSE_PORT},http://localhost:${MUSE_PORT}" \
  --no-cors-credentials \
  --reasoning-preserve \
  --temp 1.0 \
  --top-p 0.95 \
  --top-k 64 \
  --chat-template-kwargs "{\"reasoning_strength\":\"${MUSE_REASONING}\"}" \
  "${EXTRA_ARGS[@]}"
