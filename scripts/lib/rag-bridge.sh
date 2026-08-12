#!/usr/bin/env bash
# Carrega bridge RAG + Muse para scripts glimmerlocal (não executar sozinho).
# shellcheck shell=bash

# Este ficheiro vive em scripts/lib/ → repo = ../..
_RAG_BRIDGE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_RAG_BRIDGE_REPO="$(cd "${_RAG_BRIDGE_LIB_DIR}/../.." && pwd)"

rag_bridge_repo() {
  printf '%s\n' "${_RAG_BRIDGE_REPO}"
}

rag_bridge_load() {
  local repo bridge muse_env
  repo="${_RAG_BRIDGE_REPO}"
  bridge="${RAG_BRIDGE_ENV:-$repo/config/rag-bridge.env}"
  if [[ ! -f "$bridge" ]]; then
    if [[ -f "$repo/config/rag-bridge.env.example" ]]; then
      cp "$repo/config/rag-bridge.env.example" "$bridge"
      chmod 600 "$bridge"
      echo "[rag-bridge] criado $bridge a partir do example" >&2
    else
      echo "[rag-bridge] FALHA: falta $bridge" >&2
      return 1
    fi
  fi
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1090
  source "$bridge"
  set +a

  : "${RAG_ROOT:?defina RAG_ROOT em rag-bridge.env}"
  RAG_ENV_FILE="${RAG_ENV_FILE:-$RAG_ROOT/secrets/rag.env}"
  if [[ ! -f "$RAG_ENV_FILE" ]]; then
    echo "[rag-bridge] FALHA: falta $RAG_ENV_FILE (gere secrets no rag da plataforma)" >&2
    return 1
  fi
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1090
  source "$RAG_ENV_FILE"
  set +a

  muse_env="${repo}/config/muse-glimmer.env"
  if [[ -f "$muse_env" ]]; then
    # Prefer Muse host/port do perfil activo se bridge não os fixou
    # shellcheck disable=SC1090
    set -a
    # shellcheck disable=SC1090
    source "$muse_env"
    set +a
  fi

  : "${RAG_PG_HOST:=127.0.0.1}"
  : "${RAG_PG_PORT:=5433}"
  : "${RAG_PG_USER:=rag_query}"
  : "${PGSSLMODE:=disable}"
  : "${RAG_EMBED_BACKEND:=fastembed}"
  : "${FASTEMBED_CACHE_PATH:=$HOME/.cache/peritumct/fastembed}"
  : "${MUSE_HOST:=127.0.0.1}"
  : "${MUSE_PORT:=8080}"
  : "${MUSE_MODEL:=muse-glimmer-30B}"
  : "${MUSE_MAX_TOKENS:=1024}"
  : "${MUSE_REASONING_STRENGTH:=low}"

  export RAG_ROOT RAG_ENV_FILE RAG_PG_HOST RAG_PG_PORT RAG_PG_USER PGSSLMODE
  export RAG_EMBED_BACKEND FASTEMBED_CACHE_PATH
  export RAG_QUERY_PASSWORD POSTGRES_DB
  export MUSE_HOST MUSE_PORT MUSE_MODEL MUSE_MAX_TOKENS MUSE_REASONING_STRENGTH
  export MUSE_BASE_URL="${MUSE_BASE_URL:-http://${MUSE_HOST}:${MUSE_PORT}/v1}"
  export PYTHONPATH="${RAG_ROOT}${PYTHONPATH:+:$PYTHONPATH}"
}
