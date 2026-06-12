#!/bin/zsh
emulate -L zsh
set -euo pipefail

: ${SPLATVIZ_PROJECT:=$HOME/Desktop/SplatViz/splatviz_godot}
: ${SPLATVIZ_EXPORT_ROOT:=$HOME/Desktop/SplatViz_Exports}
: ${SPLATVIZ_LAYOUT:="Frame-Safe 36-Camera Multi-Tier"}
: ${SPLATVIZ_RENDER_W:=1920}
: ${SPLATVIZ_RENDER_H:=1080}
: ${INSTALLATION_MODE:=Mixed}

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

ensure_external_path() {
  python3 - <<'PY' "$1" "$2"
import os, sys
target = os.path.realpath(os.path.expanduser(sys.argv[1]))
project = os.path.realpath(os.path.expanduser(sys.argv[2]))
if target == project or target.startswith(project + os.sep):
    raise SystemExit(1)
PY
}

GODOT=$(detect_godot) || {
  print -u2 "Could not find Godot. Set GODOT_BIN or install Godot."
  exit 1
}

timestamp=$(date +"%Y%m%d_%H%M%S")
OUT_DIR=${OUT:-"${SPLATVIZ_EXPORT_ROOT}/SplatViz_Layout_Report_M68A_${timestamp}"}
mkdir -p "${OUT_DIR}"
ensure_external_path "${OUT_DIR}" "${SPLATVIZ_PROJECT}" || {
  print -u2 "Report output must stay outside the Godot project."
  exit 1
}

tmp_gd_base=$(mktemp /tmp/m68a_export_report.XXXXXX)
tmp_gd="${tmp_gd_base}.gd"
mv "${tmp_gd_base}" "${tmp_gd}"
cat > "${tmp_gd}" <<'EOF'
extends SceneTree

func _copy_file(src: String, dst: String) -> void:
	if not FileAccess.file_exists(src):
		return
	var r := FileAccess.open(src, FileAccess.READ)
	if r == null:
		return
	var bytes := r.get_buffer(r.get_length())
	r.close()
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	var w := FileAccess.open(dst, FileAccess.WRITE)
	if w == null:
		return
	w.store_buffer(bytes)
	w.close()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main_node: Node = scene.instantiate()
	root.add_child(main_node)
	await process_frame
	main_node.installation_mode = OS.get_environment("INSTALLATION_MODE")
	main_node._set_layout(OS.get_environment("SPLATVIZ_LAYOUT"))
	await process_frame
	var report_root := OS.get_environment("M68A_REPORT_OUT")
	var contact_dir := report_root.path_join("camera_contact_renders")
	var diagnostic_dir := report_root.path_join("camera_qc_diagnostics")
	DirAccess.make_dir_recursive_absolute(contact_dir)
	DirAccess.make_dir_recursive_absolute(diagnostic_dir)
	await main_node._m67g_render_contact_images_blocking(contact_dir, diagnostic_dir)
	var data: Array = main_node._m67g_camera_report_data(contact_dir, diagnostic_dir)
	var payload: Dictionary = main_node._m67g_report_payload(report_root, data)
	payload["project_name"] = "SplatViz M68A Frame-Safe Blueprint Package"
	main_node._m67g_write_report_files(report_root, payload)
	_copy_file(report_root.path_join("top_plan.svg"), report_root.path_join("assets/top_plan.svg"))
	_copy_file(report_root.path_join("front_elevation.svg"), report_root.path_join("assets/front_elevation.svg"))
	_copy_file(report_root.path_join("side_elevation.svg"), report_root.path_join("assets/side_elevation.svg"))
	_copy_file(report_root.path_join("support_legend.svg"), report_root.path_join("assets/support_legend.svg"))
	print(report_root)
	quit()
EOF

M68A_REPORT_OUT="${OUT_DIR}" \
INSTALLATION_MODE="${INSTALLATION_MODE}" \
SPLATVIZ_LAYOUT="${SPLATVIZ_LAYOUT}" \
"${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" -s "${tmp_gd}"

rm -f "${tmp_gd}"
print "Layout report exported to ${OUT_DIR}"
