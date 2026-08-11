#!/usr/bin/env bash
# Install host dependencies and prepare directories / Python HF CLI
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
ialocal_load_env

echo "==> glimmerlocal bootstrap (data=${IALOCAL_DATA})"
mkdir -p "${IALOCAL_TOOLS}" "${IALOCAL_MODELS}" "${MUSE_RUNTIME}/logs"

need_sudo=0
for pkg in cmake gcc-c++ make git libcurl-devel python3-pip; do
  if ! rpm -q "${pkg}" >/dev/null 2>&1 && ! rpm -q "${pkg%%-*}" >/dev/null 2>&1; then
    need_sudo=1
    break
  fi
done

if [[ "${need_sudo}" -eq 1 ]] || ! command -v cmake >/dev/null || ! command -v nvcc >/dev/null; then
  echo "==> Installing build packages (sudo)"
  sudo dnf install -y cmake gcc-c++ make git libcurl-devel python3-pip
fi

if ! command -v nvcc >/dev/null; then
  echo "error: nvcc not found. Install CUDA toolkit and ensure /usr/local/cuda/bin is on PATH." >&2
  exit 1
fi

export PATH="${HOME}/.local/bin:/usr/local/cuda/bin:${PATH}"
python3 -m pip install --user -U 'huggingface_hub[cli]'
command -v hf >/dev/null

if [[ ! -f "${IALOCAL_REPO_ROOT}/config/muse-glimmer.env" ]]; then
  cp "${IALOCAL_REPO_ROOT}/config/muse-glimmer.env.example" \
     "${IALOCAL_REPO_ROOT}/config/muse-glimmer.env"
  echo "created config/muse-glimmer.env from example"
fi

echo "bootstrap OK"
echo "  nvcc: $(nvcc --version | tail -1)"
echo "  cmake: $(cmake --version | head -1)"
echo "  hf: $(command -v hf)"
