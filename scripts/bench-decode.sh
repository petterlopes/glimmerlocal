#!/usr/bin/env bash
# Deterministic decode benchmark against local Muse Glimmer (OpenAI-compatible).
# Prints JSON line with wall time, completion tokens, and derived tok/s.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
ialocal_load_env

LABEL="${1:-run}"
MAX_TOKENS="${BENCH_MAX_TOKENS:-128}"
REASONING="${BENCH_REASONING:-low}"
PROMPT="${BENCH_PROMPT:-Count from 1 to 40 as digits separated by commas. No other text.}"

URL="http://${MUSE_HOST}:${MUSE_PORT}/v1/chat/completions"

for i in $(seq 1 120); do
  if curl -fsS "http://${MUSE_HOST}:${MUSE_PORT}/health" >/dev/null 2>&1; then
    break
  fi
  if [[ "${i}" -eq 120 ]]; then
    echo "timeout waiting for health" >&2
    exit 1
  fi
  sleep 1
done

# warm-up (not measured)
curl -fsS "${URL}" -H 'Content-Type: application/json' -d "{
  \"model\": \"muse-glimmer-30B\",
  \"messages\": [{\"role\":\"user\",\"content\":\"Reply with exactly: WARM\"}],
  \"max_tokens\": 32,
  \"chat_template_kwargs\": {\"reasoning_strength\": \"${REASONING}\"}
}" >/dev/null

START=$(date +%s.%N)
RESP=$(curl -fsS "${URL}" -H 'Content-Type: application/json' -d "{
  \"model\": \"muse-glimmer-30B\",
  \"messages\": [{\"role\":\"user\",\"content\": $(python3 -c 'import json,os; print(json.dumps(os.environ["PROMPT"]))' ) }],
  \"max_tokens\": ${MAX_TOKENS},
  \"temperature\": 1.0,
  \"top_p\": 0.95,
  \"chat_template_kwargs\": {\"reasoning_strength\": \"${REASONING}\"}
}")
END=$(date +%s.%N)

PROMPT="${PROMPT}" LABEL="${LABEL}" START="${START}" END="${END}" RESP="${RESP}" python3 - <<'PY'
import json, os, time
m = json.loads(os.environ["RESP"])
msg = m["choices"][0]["message"]
u = m.get("usage") or {}
ct = int(u.get("completion_tokens") or 0)
pt = int(u.get("prompt_tokens") or 0)
wall = float(os.environ["END"]) - float(os.environ["START"])
tps = (ct / wall) if wall > 0 and ct else 0.0
out = {
  "label": os.environ["LABEL"],
  "wall_s": round(wall, 3),
  "completion_tokens": ct,
  "prompt_tokens": pt,
  "tok_s": round(tps, 3),
  "content_preview": (msg.get("content") or "")[:80],
  "reasoning_chars": len(msg.get("reasoning_content") or ""),
}
print(json.dumps(out, ensure_ascii=False))
PY
