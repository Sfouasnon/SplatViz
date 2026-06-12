#!/bin/zsh
emulate -L zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PACKAGE_ROOT=${SCRIPT_DIR:h}
: ${SPLATVIZ_PROJECT:=$HOME/Desktop/SplatViz/splatviz_godot}

MAIN_GD="${SPLATVIZ_PROJECT}/scripts/Main.gd"
SCENE_PATH="${SPLATVIZ_PROJECT}/scenes/Main.tscn"

has_fixed_text() {
  local needle=$1
  local file=$2
  /usr/bin/grep -Fq -- "${needle}" "${file}"
}

has_percent_placeholder() {
  /usr/bin/grep -n '%s' "$@" >/dev/null
}

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

print "Preset string check"
for preset in \
  "Frame-Safe 12-Camera Multi-Tier" \
  "Frame-Safe 24-Camera Multi-Tier" \
  "Frame-Safe 36-Camera Multi-Tier"
do
  if ! has_fixed_text "${preset}" "${MAIN_GD}"; then
    failures+=("Missing preset string: ${preset}")
  fi
done

print "Frame-safe layout smoke"
layout_smoke_json=$(mktemp /tmp/m68a_layout_smoke.XXXXXX)
if ! M68A_LAYOUT_SMOKE_JSON="${layout_smoke_json}" \
  "${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" -s "${PACKAGE_ROOT}/tools/m68a_frame_safe_layout_smoke.gd"
then
  failures+=("Layout smoke script failed")
fi
if [[ -f "${layout_smoke_json}" ]]; then
  cat "${layout_smoke_json}"
  python3 - <<'PY' "${layout_smoke_json}"
import json, sys
data = json.load(open(sys.argv[1]))
expected = {
    "Frame-Safe 12-Camera Multi-Tier": 12,
    "Frame-Safe 24-Camera Multi-Tier": 24,
    "Frame-Safe 36-Camera Multi-Tier": 36,
}
for row in data.get("presets", []):
    name = row["preset"]
    count = row["camera_count"]
    parity = bool(row["ALL_PARITY_OK"])
    if expected.get(name) != count:
        raise SystemExit(f"camera count mismatch for {name}: {count}")
    if not parity:
        raise SystemExit(f"parity false for {name}")
PY
else
  failures+=("Layout smoke JSON was not written")
fi

print "Blueprint report smoke"
report_smoke_root=$(mktemp -d /tmp/m68a_report_smoke.XXXXXX)
if ! M68A_REPORT_SMOKE_ROOT="${report_smoke_root}" \
  SPLATVIZ_LAYOUT="Frame-Safe 36-Camera Multi-Tier" \
  "${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" -s "${PACKAGE_ROOT}/tools/m68a_report_smoke.gd" >/dev/null
then
  failures+=("Report smoke script failed")
fi

expected_paths=(
  "${report_smoke_root}/index.html"
  "${report_smoke_root}/sheet_01_overview.html"
  "${report_smoke_root}/sheet_02_top_plan.html"
  "${report_smoke_root}/sheet_03_front_elevation.html"
  "${report_smoke_root}/sheet_04_side_elevation.html"
  "${report_smoke_root}/sheet_05_camera_schedule.html"
  "${report_smoke_root}/assets/report.css"
  "${report_smoke_root}/assets/top_plan.svg"
  "${report_smoke_root}/assets/front_elevation.svg"
  "${report_smoke_root}/assets/side_elevation.svg"
  "${report_smoke_root}/assets/support_legend.svg"
  "${report_smoke_root}/camera_layout.json"
  "${report_smoke_root}/camera_mounting_schedule.csv"
)
for path in "${expected_paths[@]}"; do
  if [[ ! -f "${path}" ]]; then
    failures+=("Missing smoke report file: ${path}")
  fi
done

if has_percent_placeholder \
  "${report_smoke_root}/index.html" \
  "${report_smoke_root}/sheet_01_overview.html" \
  "${report_smoke_root}/sheet_02_top_plan.html" \
  "${report_smoke_root}/sheet_03_front_elevation.html" \
  "${report_smoke_root}/sheet_04_side_elevation.html" \
  "${report_smoke_root}/sheet_05_camera_schedule.html" >/dev/null
then
  failures+=("Literal %s placeholder found in smoke report HTML")
fi

print "msplat-train detection"
MSPLAT_FOUND=""
if [[ -n "${MSPLAT_BIN:-}" && -x "${MSPLAT_BIN}" ]]; then
  MSPLAT_FOUND="${MSPLAT_BIN}"
elif [[ -x "$HOME/msplat-env/bin/msplat-train" ]]; then
  MSPLAT_FOUND="$HOME/msplat-env/bin/msplat-train"
elif command -v msplat-train >/dev/null 2>&1; then
  MSPLAT_FOUND="$(command -v msplat-train)"
fi
if [[ -n "${MSPLAT_FOUND}" ]]; then
  print "msplat-train: ${MSPLAT_FOUND}"
else
  print "WARNING: msplat-train not found. Training scripts will warn until MSPLAT_BIN or PATH is configured."
fi

if (( ${#failures[@]} > 0 )); then
  print -u2 "Verification failed:"
  for item in "${failures[@]}"; do
    print -u2 "  - ${item}"
  done
  exit 1
fi

print "M68A verification passed."
