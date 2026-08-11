#!/usr/bin/env bash
set -euo pipefail
OUT=/run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal/docs/perf-results/diag-8080.txt
{
  echo "=== $(date -Is) ==="
  pgrep -a llama-server || echo NO_SERVER
  ss -ltn | awk '/8080/ {print}' || true
  echo "pidfile=$(cat /run/media/petterlopes/SSD930/tools/muse-glimmer/logs/llama-server.pid 2>/dev/null || echo none)"
  echo "--- log tail ---"
  tail -40 /run/media/petterlopes/SSD930/tools/muse-glimmer/logs/llama-server.log 2>/dev/null || echo no_log
} >"$OUT" 2>&1
