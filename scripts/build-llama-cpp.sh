#!/usr/bin/env bash
# Clone/checkout pinned llama.cpp and build CUDA binaries
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
ialocal_load_env

export PATH="/usr/local/cuda/bin:${HOME}/.local/bin:${PATH}"
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"

REF="$(ialocal_pins_ref)"
REPO_URL="https://github.com/ggml-org/llama.cpp.git"
JOBS="${LLAMA_BUILD_JOBS:-6}"

echo "==> llama.cpp ref=${REF} dir=${LLAMA_DIR} jobs=${JOBS}"
mkdir -p "${IALOCAL_TOOLS}"
if [[ -d "${LLAMA_DIR}/.git" ]]; then
  git -C "${LLAMA_DIR}" fetch --tags --force
  git -C "${LLAMA_DIR}" checkout "${REF}"
else
  git clone "${REPO_URL}" "${LLAMA_DIR}"
  git -C "${LLAMA_DIR}" checkout "${REF}"
fi

if ! grep -q LLM_ARCH_MUSE_GLIMMER "${LLAMA_DIR}/src/llama-arch.cpp"; then
  echo "error: checkout lacks Muse Glimmer arch (need >= b10353)" >&2
  exit 1
fi

cmake -S "${LLAMA_DIR}" -B "${LLAMA_DIR}/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DGGML_CUDA=ON \
  -DGGML_CUDA_F16=ON \
  -DGGML_NATIVE=ON

cmake --build "${LLAMA_DIR}/build" --config Release -j"${JOBS}" \
  --target llama-cli llama-server llama-mtmd-cli

test -x "${LLAMA_DIR}/build/bin/llama-server"
"${LLAMA_DIR}/build/bin/llama-cli" --version | head -5
echo "build OK → ${LLAMA_BIN}"
