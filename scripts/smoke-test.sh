#!/usr/bin/env bash
# Smoke test against local OpenAI-compatible endpoint
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
ialocal_load_env

URL="http://${MUSE_HOST}:${MUSE_PORT}/v1/chat/completions"

echo "waiting for ${URL} ..."
for i in $(seq 1 180); do
  if curl -fsS "http://${MUSE_HOST}:${MUSE_PORT}/health" >/dev/null 2>&1 \
     || curl -fsS "http://${MUSE_HOST}:${MUSE_PORT}/v1/models" >/dev/null 2>&1; then
    echo "ready after ${i}s"
    break
  fi
  if [[ "${i}" -eq 180 ]]; then
    echo "timeout waiting for server" >&2
    exit 1
  fi
  sleep 1
done

echo "=== /v1/models ==="
curl -fsS "http://${MUSE_HOST}:${MUSE_PORT}/v1/models" | python3 -m json.tool | head -40

echo "=== chat completion ==="
START=$(date +%s.%N)
RESP=$(curl -fsS "${URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "muse-glimmer-30B",
    "messages": [{"role":"user","content":"What is 17 * 23? Reply with just the number."}],
    "temperature": 1.0,
    "top_p": 0.95,
    "max_tokens": 256,
    "chat_template_kwargs": {"reasoning_strength": "low"}
  }')
END=$(date +%s.%N)
python3 -c '
import json,sys
raw, start, end = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
m = json.loads(raw)
msg = m["choices"][0]["message"]
content = (msg.get("content") or "").strip()
usage = m.get("usage") or {}
print("content  :", content)
print("reasoning:", len(msg.get("reasoning_content") or ""), "chars")
print("usage    :", usage)
print(f"wall_s   : {end-start:.2f}")
if content != "391":
    raise SystemExit(f"FAIL: expected 391, got {content!r}")
print("PASS")
' "${RESP}" "${START}" "${END}"
