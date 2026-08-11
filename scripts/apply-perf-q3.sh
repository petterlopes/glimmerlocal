#!/usr/bin/env bash
set -euo pipefail
exec > /run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal/docs/perf-results/apply-perf-q3.log 2>&1
REPO=/run/media/petterlopes/SSD930/devsec/peritumct/glimmerlocal
echo "begin $(date -Is)"
# kill leftovers
pkill -9 -f 'llama-server' 2>/dev/null || true
sleep 2
cp "$REPO/config/profiles/perf-q3.env" "$REPO/config/muse-glimmer.env"
chmod 600 "$REPO/config/muse-glimmer.env"
echo perf-q3 > "$REPO/docs/perf-results/selected-profile.txt"
"$REPO/scripts/restart-with-profile.sh" perf-q3
python3 "$REPO/scripts/bench-decode.py" --label 'perf-q3/final1' --reasoning low --max-tokens 64
python3 "$REPO/scripts/bench-decode.py" --label 'perf-q3/final2' --reasoning low --max-tokens 64 --no-warmup
curl -fsS http://127.0.0.1:8080/health || true
echo
nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader || true
echo "done $(date -Is)"
