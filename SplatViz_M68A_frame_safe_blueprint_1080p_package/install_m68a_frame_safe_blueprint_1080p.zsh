#!/bin/zsh
emulate -L zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PACKAGE_ROOT=${SCRIPT_DIR}
: ${SPLATVIZ_PROJECT:=$HOME/Desktop/SplatViz/splatviz_godot}
MAIN_GD="${SPLATVIZ_PROJECT}/scripts/Main.gd"

has_fixed_text() {
  local needle=$1
  local file=$2
  /usr/bin/grep -Fq -- "${needle}" "${file}"
}

if [[ ! -f "${MAIN_GD}" ]]; then
  print -u2 "Missing Main.gd at ${MAIN_GD}"
  exit 1
fi

chmod +x \
  "${PACKAGE_ROOT}/launch_m68a.zsh" \
  "${PACKAGE_ROOT}/export_m68a_layout_report.zsh" \
  "${PACKAGE_ROOT}/build_m68a_1080p_dataset.zsh" \
  "${PACKAGE_ROOT}/run_m68a_1080p_10k.zsh" \
  "${PACKAGE_ROOT}/watch_m68a_run.zsh" \
  "${PACKAGE_ROOT}/record_m68a_snapshot.zsh" \
  "${PACKAGE_ROOT}/tools/verify_m68a_patch.zsh"

required_markers=(
  "Frame-Safe 12-Camera Multi-Tier"
  "Frame-Safe 24-Camera Multi-Tier"
  "Frame-Safe 36-Camera Multi-Tier"
  "func _m67h_build_frame_safe_cameras"
  "func _m67h_capture_subject_bounds"
  "func _m67h_volume_qc_counts"
)

missing=0
for marker in "${required_markers[@]}"; do
  if ! has_fixed_text "${marker}" "${MAIN_GD}"; then
    print -u2 "Missing required marker: ${marker}"
    missing=1
  fi
done

if [[ ${missing} -ne 0 ]]; then
  backup_matches=(${MAIN_GD}.bak_m68a_*(N))
  if (( ${#backup_matches[@]} == 0 )); then
    stamp=$(date +"%Y%m%d_%H%M%S")
    cp "${MAIN_GD}" "${MAIN_GD}.bak_m68a_${stamp}"
    print "Backed up Main.gd to ${MAIN_GD}.bak_m68a_${stamp}"
  fi
  print -u2 "Automatic patching is not bundled in this package."
  print -u2 "Restore the verified M68A-compatible Main.gd state before using this package."
  exit 1
fi

print "M68A package is ready."
print "Project: ${SPLATVIZ_PROJECT}"
print "Next commands:"
print "  cd ${PACKAGE_ROOT:q}"
print "  ./tools/verify_m68a_patch.zsh"
print "  ./launch_m68a.zsh"
