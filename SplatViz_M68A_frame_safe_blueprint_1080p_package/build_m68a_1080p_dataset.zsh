#!/bin/zsh
emulate -L zsh
set -euo pipefail

: ${SPLATVIZ_PROJECT:=$HOME/Desktop/SplatViz/splatviz_godot}
: ${SPLATVIZ_EXPORT_ROOT:=$HOME/Desktop/SplatViz_Exports}
: ${SPLATVIZ_LAYOUT:="Frame-Safe 36-Camera Multi-Tier"}
: ${SPLATVIZ_RENDER_W:=1920}
: ${SPLATVIZ_RENDER_H:=1080}

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

if [[ "${SPLATVIZ_RENDER_W}" != "1920" || "${SPLATVIZ_RENDER_H}" != "1080" ]]; then
  print "WARNING: overriding default render size to ${SPLATVIZ_RENDER_W}x${SPLATVIZ_RENDER_H}"
fi

timestamp=$(date +"%Y%m%d_%H%M%S")
OUT_DIR=${OUT:-"${SPLATVIZ_EXPORT_ROOT}/splatviz_msplat_dataset_m68a_1080p_frame_safe36_${timestamp}"}
mkdir -p "${OUT_DIR}"
ensure_external_path "${OUT_DIR}" "${SPLATVIZ_PROJECT}" || {
  print -u2 "Dataset output must stay outside the Godot project."
  exit 1
}

tmp_gd_base=$(mktemp /tmp/m68a_build_dataset.XXXXXX)
tmp_gd="${tmp_gd_base}.gd"
mv "${tmp_gd_base}" "${tmp_gd}"
cat > "${tmp_gd}" <<'EOF'
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _write_json(path: String, doc: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(doc, "  "))
		f.close()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main_node: Node = scene.instantiate()
	root.add_child(main_node)
	await process_frame
	var dataset_root := OS.get_environment("M68A_DATASET_OUT")
	var render_w := int(OS.get_environment("SPLATVIZ_RENDER_W"))
	var render_h := int(OS.get_environment("SPLATVIZ_RENDER_H"))
	var size := Vector2i(render_w, render_h)
	main_node.installation_mode = "Mixed"
	main_node._set_layout(OS.get_environment("SPLATVIZ_LAYOUT"))
	await process_frame
	main_node._m67h_refresh_all_camera_layout_fields()
	var exportable: Array = main_node._m67h_prepare_dataset_export_cameras()
	if exportable.is_empty():
		push_error("No exportable cameras after subject QC.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(dataset_root.path_join("images"))
	DirAccess.make_dir_recursive_absolute(dataset_root.path_join("sparse/0"))
	for c_var in exportable:
		var c: Dictionary = c_var as Dictionary
		var img_path := dataset_root.path_join("images").path_join(main_node._camera_unique_filename(c))
		await main_node._render_camera_to_path(c, img_path, size, true)
	main_node._write_colmap_dataset(dataset_root, exportable, size)
	main_node._write_seed_point_cloud_ply(dataset_root, exportable, size)
	main_node._mirror_images_to_colmap_sparse(dataset_root)
	main_node._write_colmap_binary_dataset(dataset_root, exportable, size)
	main_node._write_nerfstudio_transforms(dataset_root, exportable, size)
	main_node._write_msplat_manifest(dataset_root, exportable, size)
	_write_json(dataset_root.path_join("m68a_qc_summary.json"), {
		"layout_profile": OS.get_environment("SPLATVIZ_LAYOUT"),
		"camera_count_total": main_node.cameras.size(),
		"camera_count_exported": exportable.size(),
		"subject_qc_counts": main_node._m67h_qc_counts(main_node.cameras),
		"volume_qc_counts": main_node._m67h_volume_qc_counts(main_node.cameras),
		"omitted_camera_ids": main_node.m67h_last_dataset_omitted_camera_ids,
		"unsafe_override_used": main_node.m67h_last_dataset_unsafe_override_used,
		"render_resolution": [render_w, render_h],
		"frame_policy": "Preserve full frame. No crop, no squeeze, no letterbox."
	})
	print(dataset_root)
	quit()
EOF

M68A_DATASET_OUT="${OUT_DIR}" \
SPLATVIZ_LAYOUT="${SPLATVIZ_LAYOUT}" \
SPLATVIZ_RENDER_W="${SPLATVIZ_RENDER_W}" \
SPLATVIZ_RENDER_H="${SPLATVIZ_RENDER_H}" \
"${GODOT}" --headless --path "${SPLATVIZ_PROJECT}" -s "${tmp_gd}"

rm -f "${tmp_gd}"
print "Dataset exported to ${OUT_DIR}"
