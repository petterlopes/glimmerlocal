#!/usr/bin/env bash
# Download official Muse Glimmer GGUF artifacts and verify checksums
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
ialocal_load_env

export PATH="${HOME}/.local/bin:${PATH}"
HUB_REPO="meta-models/Muse-Glimmer-30B-GGUF"
INCLUDE_DFLASH="${INCLUDE_DFLASH:-1}"

echo "==> download ${HUB_REPO} → ${MODEL_DIR}"
mkdir -p "${MODEL_DIR}"
ARGS=(
  download "${HUB_REPO}"
  --local-dir "${MODEL_DIR}"
  --include "muse-glimmer-30B-kquant-17gb.gguf"
  --include "mmproj-kquant.gguf"
  --include "README.md"
)
if [[ "${INCLUDE_DFLASH}" == "1" ]]; then
  ARGS+=(--include "dflash-kquant.gguf")
fi
hf "${ARGS[@]}"

"${SCRIPT_DIR}/verify-checksums.sh"
echo "download OK"
ls -lh "${MODEL_DIR}"
