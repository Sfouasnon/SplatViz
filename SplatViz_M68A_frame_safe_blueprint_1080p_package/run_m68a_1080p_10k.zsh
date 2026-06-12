#!/bin/zsh
emulate -L zsh
set -euo pipefail

: ${SPLATVIZ_EXPORT_ROOT:=$HOME/Desktop/SplatViz_Exports}
: ${SPLATVIZ_LAYOUT:="Frame-Safe 36-Camera Multi-Tier"}
: ${SPLATVIZ_RENDER_W:=1920}
: ${SPLATVIZ_RENDER_H:=1080}
: ${SPLATVIZ_ITERS:=10000}
: ${SPLATVIZ_SAVE_EVERY:=500}
: ${SPLATVIZ_DENSIFY_GRAD_THRESH:=0.0005}

detect_msplat() {
  if [[ -n "${MSPLAT_BIN:-}" && -x "${MSPLAT_BIN}" ]]; then
    print -- "${MSPLAT_BIN}"
    return 0
  fi
  if [[ -x "$HOME/msplat-env/bin/msplat-train" ]]; then
    print -- "$HOME/msplat-env/bin/msplat-train"
    return 0
  fi
  if command -v msplat-train >/dev/null 2>&1; then
    command -v msplat-train
    return 0
  fi
  return 1
}

latest_dataset() {
  python3 - <<'PY' "${SPLATVIZ_EXPORT_ROOT}"
from pathlib import Path
import sys
root = Path(sys.argv[1]).expanduser()
candidates = sorted(
    [p for p in root.glob("splatviz_msplat_dataset_m68a_1080p_frame_safe36_*") if p.is_dir()],
    key=lambda p: p.stat().st_mtime,
    reverse=True,
)
print(candidates[0] if candidates else "")
PY
}

MSPLAT=$(detect_msplat) || {
  print -u2 "Could not find msplat-train. Set MSPLAT_BIN or install it into ~/msplat-env/bin."
  exit 1
}

DATASET_PATH=${DATASET:-$(latest_dataset)}
if [[ -z "${DATASET_PATH}" || ! -d "${DATASET_PATH}" ]]; then
  print -u2 "No dataset found. Build a dataset first or set DATASET."
  exit 1
fi

timestamp=$(date +"%Y%m%d_%H%M%S")
OUT_DIR=${OUT:-"${SPLATVIZ_EXPORT_ROOT}/splatviz_msplat_result_m68a_1080p_10k_${timestamp}"}
mkdir -p "${OUT_DIR}"

LOG_PATH="${OUT_DIR}/train.log"
PID_PATH="${OUT_DIR}/train.pid"
PRELIGHT_PATH="${OUT_DIR}/preflight_summary.json"
COMMAND_PATH="${OUT_DIR}/run_command.txt"
PLY_PATH="${OUT_DIR}/splat.ply"

python3 - <<'PY' "${PRELIGHT_PATH}" "${DATASET_PATH}" "${OUT_DIR}" "${SPLATVIZ_LAYOUT}" "${SPLATVIZ_RENDER_W}" "${SPLATVIZ_RENDER_H}" "${SPLATVIZ_ITERS}" "${SPLATVIZ_SAVE_EVERY}" "${SPLATVIZ_DENSIFY_GRAD_THRESH}" "${MSPLAT}"
import json, os, sys
preflight_path, dataset_path, out_dir, layout, w, h, iters, save_every, thresh, msplat = sys.argv[1:]
summary = {
    "timestamp": __import__("datetime").datetime.now().isoformat(timespec="seconds"),
    "dataset_path": dataset_path,
    "result_path": out_dir,
    "layout_profile": layout,
    "render_resolution": [int(w), int(h)],
    "iteration_count": int(iters),
    "save_every": int(save_every),
    "densify_grad_thresh": float(thresh),
    "msplat_bin": msplat,
    "msplat_args": [
        "--input", os.path.join(dataset_path, "sparse/0"),
        "--output", os.path.join(out_dir, "splat.ply"),
        "--num-iters", iters,
        "--save-every", save_every,
        "--densify-grad-thresh", thresh,
        "--eval",
        "--test-every", "8",
    ],
}
manifest = os.path.join(dataset_path, "splatviz_msplat_manifest.json")
qc_summary = os.path.join(dataset_path, "m68a_qc_summary.json")
for candidate in (qc_summary, manifest):
    if os.path.exists(candidate):
        try:
            summary["dataset_summary"] = json.load(open(candidate))
            break
        except Exception:
            pass
with open(preflight_path, "w") as f:
    json.dump(summary, f, indent=2)
PY

cat > "${COMMAND_PATH}" <<EOF
${MSPLAT} --input ${DATASET_PATH}/sparse/0 --output ${PLY_PATH} --num-iters ${SPLATVIZ_ITERS} --save-every ${SPLATVIZ_SAVE_EVERY} --densify-grad-thresh ${SPLATVIZ_DENSIFY_GRAD_THRESH} --eval --test-every 8
EOF

{
  print "SplatViz M68A msplat run"
  date
  print ""
  print "Dataset: ${DATASET_PATH}"
  print "Output: ${OUT_DIR}"
  print "Layout: ${SPLATVIZ_LAYOUT}"
  print "Resolution: ${SPLATVIZ_RENDER_W}x${SPLATVIZ_RENDER_H}"
  print "Iterations: ${SPLATVIZ_ITERS}"
  print "Command:"
  cat "${COMMAND_PATH}"
  print ""
} > "${LOG_PATH}"

nohup "${MSPLAT}" \
  --input "${DATASET_PATH}/sparse/0" \
  --output "${PLY_PATH}" \
  --num-iters "${SPLATVIZ_ITERS}" \
  --save-every "${SPLATVIZ_SAVE_EVERY}" \
  --densify-grad-thresh "${SPLATVIZ_DENSIFY_GRAD_THRESH}" \
  --eval \
  --test-every 8 >> "${LOG_PATH}" 2>&1 &

print $! > "${PID_PATH}"

print "Started msplat-train"
print "PID: $(cat "${PID_PATH}")"
print "Result folder: ${OUT_DIR}"
print "Log: ${LOG_PATH}"
