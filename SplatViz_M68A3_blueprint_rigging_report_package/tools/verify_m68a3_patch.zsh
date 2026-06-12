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

print "Headless launch check"
if ! "${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" --quit >/dev/null; then
	failures+=("Godot headless launch failed")
fi

print "Duplicate function check"
dup_output=$(python3 - <<'PY' "${MAIN_GD}"
from pathlib import Path
import re, sys
seen = {}
dups = []
for i, line in enumerate(Path(sys.argv[1]).read_text().splitlines(), start=1):
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
	'report_capture_specs := "36 Komodo-X array"' \
	'report_camera_label_scheme := "AA-ID 36 Camera Grid"' \
	'func _m68a3_camera_label_for' \
	'func _m68a3_build_settings_window' \
	'"camera_label"' \
	'Sound Stage / Wood Floor'
do
	if ! /usr/bin/grep -Fq -- "${needle}" "${MAIN_GD}"; then
		failures+=("Active Main.gd missing marker: ${needle}")
	fi
done

print "Label scheme + frame-safe smoke"
label_json=$(/usr/bin/mktemp /tmp/m68a3_label.XXXXXX)
if ! M68A3_LABEL_SMOKE_JSON="${label_json}" \
	"${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" -s "${PACKAGE_ROOT}/tools/m68a3_label_scheme_smoke.gd" >/dev/null
then
	failures+=("Label scheme smoke failed")
fi
if [[ -f "${label_json}" ]]; then
	if ! /usr/bin/python3 - "${label_json}" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
expected = {
    "Frame-Safe 12-Camera Multi-Tier": 12,
    "Frame-Safe 24-Camera Multi-Tier": 24,
    "Frame-Safe 36-Camera Multi-Tier": 36,
}
assert data["camera_pov_prev_x"] < data["camera_pov_next_x"]
assert data["default_labels"][0] == "AA"
assert data["default_labels"][-1] == "ID"
assert "fell back" in data["custom_warning"]
for row in data["presets"]:
    assert expected[row["preset"]] == row["camera_count"]
    assert row["ALL_PARITY_OK"] is True
PY
	then
		failures+=("Label scheme smoke validation failed")
	fi
else
	failures+=("Label scheme smoke JSON missing")
fi

print "Report smoke"
report_root=$(/usr/bin/mktemp -d /tmp/m68a3_report.XXXXXX)
report_json=$(/usr/bin/mktemp /tmp/m68a3_report_payload.XXXXXX)
if ! M68A3_REPORT_SMOKE_ROOT="${report_root}" \
	M68A3_REPORT_SMOKE_JSON="${report_json}" \
	"${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" -s "${PACKAGE_ROOT}/tools/m68a3_report_smoke.gd" >/dev/null
then
	failures+=("Report smoke script failed")
fi
for path in \
	"${report_root}/index.html" \
	"${report_root}/sheet_01_overview.html" \
	"${report_root}/sheet_02_top_plan.html" \
	"${report_root}/sheet_03_front_elevation.html" \
	"${report_root}/sheet_04_side_elevation.html" \
	"${report_root}/sheet_05_camera_schedule.html" \
	"${report_root}/camera_layout.json" \
	"${report_root}/camera_mounting_schedule.csv" \
	"${report_root}/assets/top_plan.svg" \
	"${report_root}/assets/front_elevation.svg" \
	"${report_root}/assets/side_elevation.svg" \
	"${report_root}/assets/support_legend.svg"
do
	[[ -f "${path}" ]] || failures+=("Missing report smoke file: ${path}")
done

if ! /usr/bin/python3 - "${report_json}" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["capture_specs"] == "36 Komodo-X array"
assert payload["stage_specs"] == "Stage 1 NOZ, Truss Build"
assert payload["performer_specs"] == "Dolly Parton performs 30 songs over 2 days"
assert payload["camera_label_scheme"] == "AA-ID 36 Camera Grid"
assert payload["report_preview_background"] == "Sound Stage / Wood Floor"
assert payload["performer_height_m"] == 1.83
assert payload["cameras"][0]["camera_label"] == "AA"
assert payload["cameras"][0]["internal_camera_id"].startswith("C")
assert "subject_qc_counts" in payload
assert "volume_qc_counts" in payload
PY
then
	failures+=("Report payload validation failed")
fi

if /usr/bin/grep -Fq "QC Review" "${report_root}/sheet_01_overview.html"; then
	failures+=("Overview still contains QC Review")
fi
if /usr/bin/grep -Fq "Camera Groups Requiring Attention" "${report_root}/sheet_02_top_plan.html"; then
	failures+=("Top plan still contains Camera Groups Requiring Attention")
fi
if /usr/bin/grep -Fq "Training QC" "${report_root}/sheet_05_camera_schedule.html"; then
	failures+=("Camera schedule still exposes Training QC")
fi
if /usr/bin/grep -Fq "Volume QC" "${report_root}/sheet_05_camera_schedule.html"; then
	failures+=("Camera schedule still exposes Volume QC")
fi
if /usr/bin/grep -Eq '>(PASS|WARNING|FAIL|INVALID)<' "${report_root}/index.html"; then
	failures+=("Index still contains PASS/WARNING/FAIL/INVALID summary boxes")
fi
if ! /usr/bin/grep -Fq "Performer height" "${report_root}/front_elevation.svg"; then
	failures+=("Front elevation missing performer height scale")
fi
if ! /usr/bin/grep -Fq "Performer height" "${report_root}/side_elevation.svg"; then
	failures+=("Side elevation missing performer height scale")
fi
if ! /usr/bin/grep -Fq "AA" "${report_root}/top_plan.svg"; then
	failures+=("Top plan did not use production camera labels")
fi
if ! /usr/bin/grep -Fq "camera_label" "${report_root}/camera_mounting_schedule.csv"; then
	failures+=("CSV missing production camera label column")
fi
if ! /usr/bin/grep -Fq "\"internal_camera_id\"" "${report_root}/camera_layout.json"; then
	failures+=("camera_layout.json missing internal camera IDs")
fi

print "Stale string scan"
if /usr/bin/grep -R -Fq -- "SplatViz M6.7" "${report_root}"; then
	warnings+=("Generated report output still contains SplatViz M6.7")
fi

print "Msplat source check"
if [[ -d "${SPLATVIZ_PROJECT}/msplat" ]]; then
	if [[ -n "$(/usr/bin/find "${SPLATVIZ_PROJECT}/msplat" -type f -newer "${MAIN_GD}" -print -quit 2>/dev/null)" ]]; then
		warnings+=("Msplat files appear newer than Main.gd; verify no msplat source was modified for this patch.")
	fi
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

print "M68A3 verification passed."
