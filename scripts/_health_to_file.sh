#!/usr/bin/env bash
set -euo pipefail
OUT=/run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal/docs/perf-results/health-check.txt
{
  date -Is
  curl -fsS --max-time 2 http://127.0.0.1:8080/health || echo HEALTH_FAIL
  echo
  pgrep -a llama-server | head -1 || echo NO_SERVER
  nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader || true
  cat /run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal/docs/perf-results/selected-profile.txt 2>/dev/null || true
} >"$OUT"
