#!/usr/bin/env bash
# Shared helpers for glimmerlocal scripts
# shellcheck shell=bash

# This file lives at scripts/lib/common.sh → repo root is ../..
IALOCAL_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

ialocal_load_env() {
  local env_file="${IALOCAL_ENV_FILE:-${IALOCAL_REPO_ROOT}/config/muse-glimmer.env}"
  local example="${IALOCAL_REPO_ROOT}/config/muse-glimmer.env.example"
  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    set -a
    source "${env_file}"
    set +a
  elif [[ -f "${example}" ]]; then
    echo "warn: ${env_file} missing; loading example defaults" >&2
    set -a
    # shellcheck disable=SC1090
    source "${example}"
    set +a
  fi

  export IALOCAL_DATA="${IALOCAL_DATA:-/run/media/petterlopes/SSD930}"
  export MUSE_HOST="${MUSE_HOST:-127.0.0.1}"
  export MUSE_PORT="${MUSE_PORT:-8080}"
  export MUSE_REASONING="${MUSE_REASONING:-medium}"
  export MUSE_VISION="${MUSE_VISION:-0}"
  export MUSE_CTX="${MUSE_CTX:-32768}"
  export MUSE_FIT_TARGET="${MUSE_FIT_TARGET:-768}"
  export MUSE_FIT_CTX="${MUSE_FIT_CTX:-8192}"
  export MUSE_THREADS="${MUSE_THREADS:-24}"
  export MUSE_LOAD_MODE="${MUSE_LOAD_MODE:-mmap}"
  export MUSE_SPEC_TYPE="${MUSE_SPEC_TYPE:-none}"
  export MUSE_DFLASH="${MUSE_DFLASH:-0}"
  export MUSE_DRAFT_N_MAX="${MUSE_DRAFT_N_MAX:-5}"
  export MUSE_DRAFT_NGL="${MUSE_DRAFT_NGL:-0}"
  export MUSE_REASONING_BUDGET="${MUSE_REASONING_BUDGET:--1}"
  export MUSE_PRIO="${MUSE_PRIO:-0}"
  export LLAMA_BUILD_JOBS="${LLAMA_BUILD_JOBS:-6}"
  # MCP RAG (UI): proxy CORS + config com peritumct-rag em 127.0.0.1:8091
  export MUSE_UI_MCP_PROXY="${MUSE_UI_MCP_PROXY:-1}"
  export MUSE_UI_CONFIG_FILE="${MUSE_UI_CONFIG_FILE:-${IALOCAL_REPO_ROOT}/config/muse-ui.json}"
  export MUSE_RAG_MCP_AUTOSTART="${MUSE_RAG_MCP_AUTOSTART:-1}"

  export IALOCAL_TOOLS="${IALOCAL_DATA}/tools"
  export IALOCAL_MODELS="${IALOCAL_DATA}/models"
  export LLAMA_DIR="${IALOCAL_TOOLS}/llama.cpp"
  export LLAMA_BIN="${LLAMA_DIR}/build/bin/llama-server"
  export MUSE_RUNTIME="${IALOCAL_TOOLS}/muse-glimmer"
  export MODEL_DIR="${IALOCAL_MODELS}/Muse-Glimmer-30B-GGUF"
  export MODEL_GGUF="${MODEL_GGUF:-${MODEL_DIR}/muse-glimmer-30B-kquant-17gb.gguf}"
  export MMPROJ_GGUF="${MODEL_DIR}/mmproj-kquant.gguf"
  export DFLASH_GGUF="${MODEL_DIR}/dflash-kquant.gguf"
  export PIDFILE="${MUSE_RUNTIME}/logs/llama-server.pid"
  export LOGFILE="${MUSE_RUNTIME}/logs/llama-server.log"
}

# Build llama-server argv extras for speculation / budget / prio
ialocal_build_extra_args() {
  EXTRA_ARGS=()
  if [[ "${MUSE_VISION}" == "1" ]]; then
    EXTRA_ARGS+=(--mmproj "${MMPROJ_GGUF}")
  fi
  if [[ "${MUSE_PRIO}" != "0" ]]; then
    EXTRA_ARGS+=(--prio "${MUSE_PRIO}")
  fi
  if [[ "${MUSE_REASONING_BUDGET}" != "-1" ]]; then
    EXTRA_ARGS+=(--reasoning-budget "${MUSE_REASONING_BUDGET}")
  fi

  case "${MUSE_SPEC_TYPE}" in
    none|"")
      ;;
    ngram-mod|ngram-simple|ngram-map-k|ngram-map-k4v|ngram-cache)
      EXTRA_ARGS+=(--spec-type "${MUSE_SPEC_TYPE}")
      EXTRA_ARGS+=(--spec-ngram-mod-n-max "${MUSE_DRAFT_N_MAX}")
      ;;
    draft-dflash)
      if [[ ! -f "${DFLASH_GGUF}" ]]; then
        echo "error: DFlash missing at ${DFLASH_GGUF}" >&2
        return 1
      fi
      EXTRA_ARGS+=(--spec-type draft-dflash)
      EXTRA_ARGS+=(--model-draft "${DFLASH_GGUF}")
      EXTRA_ARGS+=(--spec-draft-n-max "${MUSE_DRAFT_N_MAX}")
      # On 8GB cards, packing the main model already saturates VRAM.
      # Keep DFlash on CPU/RAM (MUSE_DRAFT_NGL, default 0) to avoid cudaMalloc OOM.
      EXTRA_ARGS+=(-ngld "${MUSE_DRAFT_NGL:-0}")
      ;;
    *)
      EXTRA_ARGS+=(--spec-type "${MUSE_SPEC_TYPE}")
      ;;
  esac

  # Legacy toggle: MUSE_DFLASH=1 implies draft-dflash if SPEC not set to ngram
  if [[ "${MUSE_DFLASH}" == "1" && "${MUSE_SPEC_TYPE}" == "none" ]]; then
    if [[ ! -f "${DFLASH_GGUF}" ]]; then
      echo "error: DFlash missing at ${DFLASH_GGUF}" >&2
      return 1
    fi
    EXTRA_ARGS+=(--spec-type draft-dflash)
    EXTRA_ARGS+=(--model-draft "${DFLASH_GGUF}")
    EXTRA_ARGS+=(--spec-draft-n-max "${MUSE_DRAFT_N_MAX}")
    EXTRA_ARGS+=(-ngld "${MUSE_DRAFT_NGL:-0}")
  fi

  # UI MCP (RAG local) — só loopback; proxy no llama-server para CORS do browser
  if [[ "${MUSE_UI_MCP_PROXY:-1}" == "1" ]]; then
    EXTRA_ARGS+=(--ui-mcp-proxy)
  fi
  if [[ -n "${MUSE_UI_CONFIG_FILE:-}" && -f "${MUSE_UI_CONFIG_FILE}" ]]; then
    EXTRA_ARGS+=(--ui-config-file "${MUSE_UI_CONFIG_FILE}")
  fi
}

ialocal_pins_ref() {
  python3 - <<'PY' "${IALOCAL_REPO_ROOT}/config/pins.yml"
import sys
path = sys.argv[1]
ref = None
in_llama = False
with open(path, encoding="utf-8") as f:
    for line in f:
        if line.startswith("llama_cpp:"):
            in_llama = True
            continue
        if in_llama and line and not line.startswith(" ") and not line.startswith("\t"):
            break
        if in_llama and line.strip().startswith("ref:"):
            ref = line.split(":", 1)[1].strip().strip('"').strip("'")
            break
if not ref:
    raise SystemExit("pins.yml: llama_cpp.ref not found")
print(ref)
PY
}
