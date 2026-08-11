#!/usr/bin/env bash
set -euo pipefail
LOG=/run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal/docs/perf-results/reup.log
exec >"$LOG" 2>&1
REPO=/run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal
pkill -9 -f 'llama-server' 2>/dev/null || true
sleep 2
"$REPO/scripts/restart-with-profile.sh" perf-q3
curl -fsS http://127.0.0.1:8080/health
echo
nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader
echo OK
