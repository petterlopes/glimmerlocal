#!/usr/bin/env bash
# Continue A/B: dflash-cpu + Unsloth Q3, then select best vs prior jsonl
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT_DIR="${REPO}/docs/perf-results"
mkdir -p "${OUT_DIR}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
# reuse prior partial results if present
PRIOR="$(ls -1t "${OUT_DIR}"/ab-*.jsonl 2>/dev/null | head -1 || true)"
RESULT="${OUT_DIR}/ab-extended-${STAMP}.jsonl"
SUMMARY="${OUT_DIR}/ab-extended-${STAMP}.md"
: >"${RESULT}"
if [[ -n "${PRIOR}" ]]; then
  # keep only successful profiles (exclude incomplete dflash crash)
  rg -v 'perf-dflash' "${PRIOR}" >>"${RESULT}" || true
fi

for prof in perf-dflash perf-q3; do
  echo "======== PROFILE ${prof} ========"
  "${SCRIPT_DIR}/restart-with-profile.sh" "${prof}"
  for run in 1 2; do
    line="$(python3 "${SCRIPT_DIR}/bench-decode.py" --label "${prof}/r${run}" --reasoning low --max-tokens 128)"
    echo "${line}" | tee -a "${RESULT}"
  done
done

python3 - <<PY | tee "${SUMMARY}"
import json
from collections import defaultdict
rows=[]
with open("${RESULT}") as f:
    for line in f:
        line=line.strip()
        if line:
            rows.append(json.loads(line))
print(f"# Muse Glimmer A/B extended — ${STAMP}")
print()
print(f"Includes prior file: `{ '${PRIOR}' or 'none' }` (dflash OOM runs excluded).")
print()
print("| profile | run | tok/s | wall_s | completion_tokens | reasoning_chars |")
print("|---|---:|---:|---:|---:|---:|")
by=defaultdict(list)
for m in rows:
    prof, run = m["label"].split("/")
    by[prof].append(m)
    print(f"| {prof} | {run} | {m['tok_s']} | {m['wall_s']} | {m['completion_tokens']} | {m['reasoning_chars']} |")
print()
print("| profile | mean_tok_s | best_tok_s | delta_vs_baseline |")
print("|---|---:|---:|---:|")
base=None
means={}
for prof, ms in by.items():
    vals=[x["tok_s"] for x in ms]
    means[prof]=sum(vals)/len(vals)
    if prof=="baseline":
        base=means[prof]
best_prof=max(means, key=means.get)
for prof, mean in sorted(means.items(), key=lambda kv: -kv[1]):
    mx=max(x["tok_s"] for x in by[prof])
    delta="" if base is None else f"{(mean/base-1)*100:+.1f}%"
    print(f"| {prof} | {mean:.3f} | {mx:.3f} | {delta} |")
print()
print(f"**Selected profile:** `{best_prof}` @ **{means[best_prof]:.3f} t/s mean**")
open("${OUT_DIR}/selected-profile.txt","w").write(best_prof+"\\n")
# deep notes
print()
print("## Engineering notes")
print("- baseline ≈ 4.0 t/s under fixed bench (matches prior ~4.5 on longer traces).")
print("- fit-only (more VRAM pack) gives small but stable gain.")
print("- ngram-mod can spike (acceptance-dependent); mean matters more than a single run.")
print("- DFlash on GPU OOMs on 8GB; CPU/RAM draft is the only viable path here.")
print("- Q3 Unsloth trades quality for more GPU-resident layers.")
PY

BEST_PROF="$(tr -d '\n' < "${OUT_DIR}/selected-profile.txt")"
cp "${REPO}/config/profiles/${BEST_PROF}.env" "${REPO}/config/muse-glimmer.env"
chmod 600 "${REPO}/config/muse-glimmer.env"
"${SCRIPT_DIR}/restart-with-profile.sh" "${BEST_PROF}"
echo "Applied ${BEST_PROF}"
echo "SUMMARY=${SUMMARY}"
echo "RESULT=${RESULT}"
