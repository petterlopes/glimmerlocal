#!/usr/bin/env bash
# A/B performance matrix for Muse Glimmer on this host.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${REPO}/docs/perf-results"
mkdir -p "${OUT_DIR}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RESULT="${OUT_DIR}/ab-${STAMP}.jsonl"
SUMMARY="${OUT_DIR}/ab-${STAMP}.md"
PROFILES=(baseline fit-only perf perf-dflash)

{
  echo "# Muse Glimmer A/B — ${STAMP}"
  echo
  echo "Fixed workload: reasoning=low, max_tokens=128, warm-up enabled."
  echo "Host: RTX 4060 8GB hybrid offload."
  echo
} >"${SUMMARY}"

: >"${RESULT}"
for prof in "${PROFILES[@]}"; do
  echo "======== PROFILE ${prof} ========"
  "${SCRIPT_DIR}/restart-with-profile.sh" "${prof}"
  for run in 1 2; do
    line="$(python3 "${SCRIPT_DIR}/bench-decode.py" --label "${prof}/r${run}" --reasoning low --max-tokens 128)"
    echo "${line}" | tee -a "${RESULT}"
  done
done

python3 - <<PY | tee -a "${SUMMARY}"
import json
from collections import defaultdict
rows=[]
with open("${RESULT}") as f:
    for line in f:
        rows.append(json.loads(line))
print("| profile | run | tok/s | wall_s | completion_tokens | reasoning_chars |")
print("|---|---:|---:|---:|---:|---:|")
by=defaultdict(list)
for m in rows:
    prof, run = m["label"].split("/")
    by[prof].append(m)
    print(f"| {prof} | {run} | {m['tok_s']} | {m['wall_s']} | {m['completion_tokens']} | {m['reasoning_chars']} |")
print()
print("| profile | mean_tok_s | best_tok_s |")
print("|---|---:|---:|")
best_prof=None
best_mean=-1
for prof, ms in by.items():
    vals=[x["tok_s"] for x in ms]
    mean=sum(vals)/len(vals)
    mx=max(vals)
    print(f"| {prof} | {mean:.3f} | {mx:.3f} |")
    if mean>best_mean:
        best_mean=mean
        best_prof=prof
print()
print(f"**Selected profile (highest mean tok/s):** `{best_prof}` @ **{best_mean:.3f} t/s**")
open("${OUT_DIR}/selected-profile.txt","w").write(best_prof+"\\n")
PY

BEST_PROF="$(cat "${OUT_DIR}/selected-profile.txt")"
cp "${REPO}/config/profiles/${BEST_PROF}.env" "${REPO}/config/muse-glimmer.env"
chmod 600 "${REPO}/config/muse-glimmer.env"
"${SCRIPT_DIR}/restart-with-profile.sh" "${BEST_PROF}"
echo "Applied ${BEST_PROF}"
echo "SUMMARY=${SUMMARY}"
echo "RESULT=${RESULT}"
