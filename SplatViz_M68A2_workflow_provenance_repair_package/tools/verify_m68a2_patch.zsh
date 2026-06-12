#!/bin/zsh
emulate -L zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PACKAGE_ROOT=${SCRIPT_DIR:h}
: ${SPLATVIZ_PROJECT:=$HOME/Desktop/SplatViz/splatviz_godot}

MAIN_GD="${SPLATVIZ_PROJECT}/scripts/Main.gd"
SCENE_PATH="${SPLATVIZ_PROJECT}/scenes/Main.tscn"

detect_godot() {
	if [[ -n "${GODOT_BIN:-}" && -x "${GODOT_BIN}" ]]; then
		print -- "${GODOT_BIN}"
		return 0
	fi
	local candidate
	for candidate in \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"$(command -v godot 2>/dev/null || true)"
	do
		if [[ -n "${candidate}" && -x "${candidate}" ]]; then
			print -- "${candidate}"
			return 0
		fi
	done
	return 1
}

GODOT=$(detect_godot) || {
	print -u2 "Could not find Godot. Set GODOT_BIN or install Godot."
	exit 1
}

failures=()
warnings=()

if [[ ! -f "${MAIN_GD}" ]]; then
	failures+=("Missing ${MAIN_GD}")
fi

if [[ ! -f "${SCENE_PATH}" ]]; then
	failures+=("Missing ${SCENE_PATH}")
fi

print "Headless launch check"
if ! "${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" --quit >/dev/null; then
	failures+=("Godot headless launch failed")
fi

print "Duplicate function check"
dup_output=$(python3 - <<'PY' "${MAIN_GD}"
from pathlib import Path
import re
import sys
p = Path(sys.argv[1])
seen = {}
dups = []
for i, line in enumerate(p.read_text().splitlines(), start=1):
    m = re.match(r'^func\s+([A-Za-z0-9_]+)\s*\(', line)
    if not m:
        continue
    name = m.group(1)
    if name in seen:
        dups.append((name, seen[name], i))
    else:
        seen[name] = i
print(f"DUPLICATE_FUNC_COUNT={len(dups)}")
for name, first, second in dups:
    print(f"{name} first={first} second={second}")
sys.exit(1 if dups else 0)
PY
) || failures+=("Duplicate top-level function definitions found")
print "${dup_output}"

print "Active patch marker check"
for needle in \
	'SPLATVIZ_RELEASE_LABEL = "SplatViz M68A2"' \
	'SPLATVIZ_EXPORT_TAG = "m68a2"' \
	'func _stills_collect_images_recursive' \
	'camera_pov_prev_button' \
	'latest_ply_bounds_full'
do
	if ! /usr/bin/grep -Fq -- "${needle}" "${MAIN_GD}"; then
		failures+=("Active Main.gd missing marker: ${needle}")
	fi
done

for stale in 'SplatViz M6.7' 'splatviz_clean_m63' 'splatviz_msplat_dataset_m63' 'splatviz_m65a_' ; do
	if /usr/bin/grep -Fq -- "${stale}" "${MAIN_GD}"; then
		warnings+=("Active Main.gd still contains stale user-facing text: ${stale}")
	fi
done

print "Frame-safe layout + parity smoke"
layout_smoke_json=$(/usr/bin/mktemp /tmp/m68a2_layout_smoke.XXXXXX)
parity_dir=$(/usr/bin/mktemp -d /tmp/m68a2_parity.XXXXXX)
if ! M68A2_LAYOUT_SMOKE_JSON="${layout_smoke_json}" \
	M68A2_PARITY_SMOKE_DIR="${parity_dir}" \
	"${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" -s "${PACKAGE_ROOT}/tools/m68a2_frame_safe_layout_smoke.gd" >/dev/null
then
	failures+=("Layout smoke script failed")
fi
if [[ -f "${layout_smoke_json}" ]]; then
	cat "${layout_smoke_json}"
	if ! /usr/bin/python3 - "${layout_smoke_json}" <<'PY'
import json, re, sys
data = json.load(open(sys.argv[1]))
expected = {
    "Frame-Safe 12-Camera Multi-Tier": 12,
    "Frame-Safe 24-Camera Multi-Tier": 24,
    "Frame-Safe 36-Camera Multi-Tier": 36,
}
assert data["release_label"] == "SplatViz M68A2"
assert data["inspector_collapsed"] is True
assert data["selected_only_default"] is True
assert data["startup_frustum_count"] == 1
assert data["camera_pov_prev_x"] < data["camera_pov_next_x"]
assert data["camera_pov_parity_ok"] is True
assert re.fullmatch(r"\d{8}_\d{6}", data["timestamp"])
assert data["sample_render_root"].endswith("splatviz_render_selected_m68a2_" + data["timestamp"])
assert data["sample_report_root"] == "SplatViz_Layout_Report_M68A2_" + data["timestamp"]
for row in data.get("presets", []):
    if expected[row["preset"]] != row["camera_count"]:
        raise SystemExit(f"camera count mismatch for {row['preset']}: {row['camera_count']}")
    if not bool(row["ALL_PARITY_OK"]):
        raise SystemExit(f"ALL_PARITY_OK false for {row['preset']}")
PY
	then
		failures+=("Layout smoke JSON validation failed")
	fi
else
	failures+=("Layout smoke JSON was not written")
fi

print "Blueprint report smoke"
report_smoke_root=$(/usr/bin/mktemp -d /tmp/m68a2_report_smoke.XXXXXX)
report_smoke_json=$(/usr/bin/mktemp /tmp/m68a2_report_payload.XXXXXX)
if ! M68A2_REPORT_SMOKE_ROOT="${report_smoke_root}" \
	M68A2_REPORT_SMOKE_JSON="${report_smoke_json}" \
	SPLATVIZ_LAYOUT="Frame-Safe 36-Camera Multi-Tier" \
	"${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" -s "${PACKAGE_ROOT}/tools/m68a2_report_smoke.gd" >/dev/null
then
	failures+=("Report smoke script failed")
fi
for path in \
	"${report_smoke_root}/index.html" \
	"${report_smoke_root}/sheet_01_overview.html" \
	"${report_smoke_root}/sheet_02_top_plan.html" \
	"${report_smoke_root}/sheet_03_front_elevation.html" \
	"${report_smoke_root}/sheet_04_side_elevation.html" \
	"${report_smoke_root}/sheet_05_camera_schedule.html" \
	"${report_smoke_root}/assets/report.css" \
	"${report_smoke_root}/assets/top_plan.svg" \
	"${report_smoke_root}/assets/front_elevation.svg" \
	"${report_smoke_root}/assets/side_elevation.svg" \
	"${report_smoke_root}/assets/support_legend.svg" \
	"${report_smoke_root}/camera_layout.json" \
	"${report_smoke_root}/camera_mounting_schedule.csv"
do
	if [[ ! -f "${path}" ]]; then
		failures+=("Missing smoke report file: ${path}")
	fi
done
if ! /usr/bin/python3 - "${report_smoke_json}" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["export_timestamp"] == "20260528_120000"
assert payload["app_release_label"] == "SplatViz M68A2"
assert payload["export_tag"] == "m68a2"
assert payload["layout_profile"] == "Frame-Safe 36-Camera Multi-Tier"
assert payload["render_width"] == 1280
assert payload["render_height"] == 720
assert payload["camera_count"] == 36
assert "PASS" in payload["subject_qc_counts"]
assert "PASS" in payload["volume_qc_counts"]
PY
then
	failures+=("Report payload metadata validation failed")
fi
for stale in 'M6.7' 'm63' 'M63' 'm65' 'M65'; do
	if /usr/bin/grep -R -Fq -- "${stale}" "${report_smoke_root}"; then
		failures+=("Generated report smoke output still contains stale string: ${stale}")
	fi
done

print "Still Viewer recursive smoke"
stills_smoke_root=$(/usr/bin/mktemp -d /tmp/m68a2_stills_m63.XXXXXX)
stills_smoke_json=$(/usr/bin/mktemp /tmp/m68a2_stills.XXXXXX)
if ! M68A2_STILLS_SMOKE_ROOT="${stills_smoke_root}" \
	M68A2_STILLS_SMOKE_JSON="${stills_smoke_json}" \
	"${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" -s "${PACKAGE_ROOT}/tools/m68a2_still_viewer_recursive_smoke.gd" >/dev/null
then
	failures+=("Still Viewer recursive smoke script failed")
fi
if ! /usr/bin/python3 - "${stills_smoke_json}" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["discovered_count"] == 3
assert "1/3" in data["title"]
assert "Manifest release: SplatViz M68A2" in data["meta_text"]
assert "older export/result" in data["meta_text"]
PY
then
	failures+=("Still Viewer smoke metadata validation failed")
fi

print "Splat viewer smoke"
splat_smoke_root=$(/usr/bin/mktemp -d /tmp/m68a2_splat_m63.XXXXXX)
splat_smoke_json=$(/usr/bin/mktemp /tmp/m68a2_splat.XXXXXX)
if ! M68A2_SPLAT_VIEWER_SMOKE_ROOT="${splat_smoke_root}" \
	M68A2_SPLAT_VIEWER_SMOKE_JSON="${splat_smoke_json}" \
	"${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" -s "${PACKAGE_ROOT}/tools/m68a2_splat_viewer_smoke.gd" >/dev/null
then
	failures+=("Splat viewer smoke script failed")
fi
if ! /usr/bin/python3 - "${splat_smoke_json}" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["mode"] == "Splat View"
assert data["visible_points"] > 0
assert data["latest_ply_preview_mode"] == "Original Coordinates"
assert "Debug point preview" in data["latest_ply_summary"]
assert "Vertex/Gaussian count" in data["latest_ply_summary"]
assert "older export/result" in data["latest_ply_provenance_text"]
assert "min" in data["latest_ply_summary"]
assert abs(float(data["distance_after_reset"]) - 14.5) < 1e-6
PY
then
	failures+=("Splat viewer metadata validation failed")
fi

if (( ${#warnings[@]} > 0 )); then
	print "Warnings:"
	for item in "${warnings[@]}"; do
		print "  - ${item}"
	done
fi

if (( ${#failures[@]} > 0 )); then
	print -u2 "Verification failed:"
	for item in "${failures[@]}"; do
		print -u2 "  - ${item}"
	done
	exit 1
fi

print "M68A2 verification passed."
