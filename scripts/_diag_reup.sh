#!/usr/bin/env bash
set -euo pipefail
OUT=/run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal/docs/perf-results/diag-reup-$(date +%H%M%S).txt
{
  echo "=== $(date -Is) ==="
  pgrep -a llama-server || echo NO_SERVER
  ss -ltn | awk '/8080/' || true
  echo "pidfile=$(cat /run/media/petterlopes/SSD930/tools/muse-glimmer/logs/llama-server.pid 2>/dev/null || echo none)"
  echo "--- dmesg OOM (if any) ---"
  dmesg -T 2>/dev/null | awk '/llama|Out of memory|Killed process/ {print}' | tail -20 || true
  echo "--- log tail ---"
  tail -50 /run/media/petterlopes/SSD930/tools/muse-glimmer/logs/llama-server.log 2>/dev/null || true
} >"$OUT" 2>&1
echo "$OUT"
