#!/bin/zsh
emulate -L zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PACKAGE_ROOT=${SCRIPT_DIR}
: ${SPLATVIZ_EXPORT_ROOT:=$HOME/Desktop/SplatViz_Exports}
: ${SPLATVIZ_LAYOUT:="Frame-Safe 36-Camera Multi-Tier"}
: ${SPLATVIZ_RENDER_W:=1920}
: ${SPLATVIZ_RENDER_H:=1080}
: ${SPLATVIZ_ITERS:=10000}
HISTORY_PATH="$HOME/Desktop/SplatViz/splatviz_project_history.json"

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

latest_result() {
  python3 - <<'PY' "${SPLATVIZ_EXPORT_ROOT}"
from pathlib import Path
import sys
root = Path(sys.argv[1]).expanduser()
candidates = sorted(
    [p for p in root.glob("splatviz_msplat_result_m68a_1080p_10k_*") if p.is_dir()],
    key=lambda p: p.stat().st_mtime,
    reverse=True,
)
print(candidates[0] if candidates else "")
PY
}

DATASET_PATH=${DATASET:-$(latest_dataset)}
RESULT_PATH=${OUT:-$(latest_result)}

if [[ -z "${RESULT_PATH}" || ! -d "${RESULT_PATH}" ]]; then
  print -u2 "No result folder found. Pass OUT or run the 10K script first."
  exit 1
fi

parse_json=$(python3 "${PACKAGE_ROOT}/tools/m68a_parse_train_log.py" "${RESULT_PATH}")

python3 - <<'PY' "${HISTORY_PATH}" "${DATASET_PATH}" "${RESULT_PATH}" "${SPLATVIZ_LAYOUT}" "${SPLATVIZ_RENDER_W}" "${SPLATVIZ_RENDER_H}" "${SPLATVIZ_ITERS}" "${parse_json}"
import json, os, sys
from datetime import datetime

history_path, dataset_path, result_path, layout, w, h, iters, parse_json = sys.argv[1:]
summary = json.loads(parse_json)

dataset_summary = {}
if dataset_path and os.path.isdir(dataset_path):
    for candidate in (
        os.path.join(dataset_path, "m68a_qc_summary.json"),
        os.path.join(dataset_path, "splatviz_msplat_manifest.json"),
    ):
        if os.path.exists(candidate):
            try:
                dataset_summary = json.load(open(candidate))
                break
            except Exception:
                pass

if os.path.exists(history_path):
    history = json.load(open(history_path))
else:
    history = {
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "runs": [],
        "latest": {},
        "updated_at": "",
        "schema": "splatviz_history_v1",
    }

runs = history.get("runs", [])
entry = {
    "timestamp": datetime.now().isoformat(timespec="seconds"),
    "layout_profile": layout,
    "camera_count": dataset_summary.get("camera_count_total", dataset_summary.get("camera_count_exported")),
    "subject_qc_counts": dataset_summary.get("subject_qc_counts", dataset_summary.get("frame_qc_counts", {})),
    "volume_qc_counts": dataset_summary.get("volume_qc_counts", {}),
    "dataset_path": dataset_path,
    "result_path": result_path,
    "render_resolution": [int(w), int(h)],
    "iteration_count": int(iters),
    "msplat_args": summary.get("preflight", {}).get("msplat_args", []),
    "final_metrics": summary.get("metrics", {}),
    "notes": "M68A local snapshot recorded without storing bulky dataset contents."
}
runs.append(entry)
history["runs"] = runs
history["latest"] = entry
history["updated_at"] = entry["timestamp"]
os.makedirs(os.path.dirname(history_path), exist_ok=True)
with open(history_path, "w") as f:
    json.dump(history, f, indent=2)
print(history_path)
PY

print "Snapshot appended to ${HISTORY_PATH}"
