#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
ialocal_load_env

SUMS="${IALOCAL_REPO_ROOT}/inventory/checksums.sha256"
echo "==> verifying against ${SUMS}"
(
  cd "${MODEL_DIR}"
  sha256sum -c "${SUMS}"
)
# refresh sidecars next to weights for ops convenience
(
  cd "${MODEL_DIR}"
  while read -r hash name; do
    [[ -z "${hash}" || "${hash}" =~ ^# ]] && continue
    echo "${hash}  ${MODEL_DIR}/${name}" > "${MODEL_DIR}/${name}.sha256"
  done < "${SUMS}"
)
echo "checksums OK"
