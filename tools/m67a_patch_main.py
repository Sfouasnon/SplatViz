#!/usr/bin/env python3
from pathlib import Path
import re, sys

main = Path(sys.argv[1])
s = main.read_text()

s = re.sub(r'"SplatViz M6\.[0-9A-Za-z\.]*"', '"SplatViz M6.7A"', s)
for old in ["SplatViz M66F", "SplatViz M66E", "SplatViz M6.6E", "SplatViz M6.6D", "SplatViz M6.6C", "SplatViz M6.6B", "SplatViz M6.6A"]:
    s = s.replace(old, "SplatViz M6.7A" if old.startswith("SplatViz M6.") else "SplatViz M67A")

button_block = '''\n\t# M67A: project-memory and physical-layout outputs.\n\t_add_button(lv, "Export Camera Layout", func(): _m67a_export_camera_layout())\n\t_add_button(lv, "Record Run Snapshot", func(): _m67a_record_run_snapshot("manual_ui"))\n\t_add_button(lv, "Open Project History", func(): OS.shell_open(_m67a_history_path()))\n'''
if 'func(): _m67a_export_camera_layout()' not in s:
    lines = s.splitlines(True)
    out = []
    inserted = False
    for line in lines:
        out.append(line)
        if not inserted and ('_add_button' in line and 'Render Clean Selected' in line):
            out.append(button_block)
            inserted = True
    if not inserted:
        for i, line in enumerate(out):
            if '_add_button' in line and 'Render Clean All' in line:
                out.insert(i + 1, button_block)
                inserted = True
                break
    if not inserted:
        out.append('\n# M67A note: UI insertion marker not found; functions installed for console/tool use.\n')
    s = ''.join(out)

m67a_block = r'''

# -----------------------------------------------------------------------------
# M67A — Roadmap Recenter: project history ledger + 1080p-first layout export
# -----------------------------------------------------------------------------

func _m67a_project_root() -> String:
	var p: String = ProjectSettings.globalize_path("res://")
	if p.ends_with("/"):
		p = p.substr(0, p.length() - 1)
	return p.get_base_dir()

func _m67a_history_path() -> String:
	return _m67a_project_root() + "/splatviz_project_history.json"

func _m67a_layout_export_dir() -> String:
	return _m67a_project_root() + "/splatviz_layout_exports"

func _m67a_now_token() -> String:
	var t: String = Time.get_datetime_string_from_system(false, true)
	return t.replace("-", "").replace(":", "").replace("T", "_").replace(" ", "_")

func _m67a_feet(meters: float) -> float:
	return meters * 3.280839895

func _m67a_value(d: Dictionary, keys: Array, fallback: Variant = "") -> Variant:
	for k in keys:
		var ks: String = str(k)
		if d.has(ks):
			return d[ks]
	return fallback

func _m67a_vec3_from_variant(v: Variant) -> Vector3:
	if typeof(v) == TYPE_VECTOR3:
		return v as Vector3
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v as Dictionary
		return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))
	if typeof(v) == TYPE_ARRAY:
		var a: Array = v as Array
		if a.size() >= 3:
			return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO

func _m67a_camera_position(c: Dictionary) -> Vector3:
	var direct: Variant = _m67a_value(c, ["position", "pos", "world_position", "origin", "camera_position"], null)
	if direct != null:
		return _m67a_vec3_from_variant(direct)
	return Vector3(float(_m67a_value(c, ["x", "pos_x", "world_x"], 0.0)), float(_m67a_value(c, ["y", "height", "pos_y", "world_y"], 0.0)), float(_m67a_value(c, ["z", "pos_z", "world_z"], 0.0)))

func _m67a_camera_target(c: Dictionary) -> Vector3:
	var direct: Variant = _m67a_value(c, ["target", "look_at", "focus", "focus_target", "subject_center"], null)
	if direct != null:
		return _m67a_vec3_from_variant(direct)
	return Vector3.ZERO

func _m67a_camera_row(c: Dictionary, idx: int) -> Dictionary:
	var name: String = str(_m67a_value(c, ["name", "id", "camera", "camera_id"], "CAM%02d" % [idx + 1]))
	var tier: String = str(_m67a_value(c, ["tier", "level", "row"], ""))
	var lens: String = str(_m67a_value(c, ["lens", "lens_name"], "Rokinon 24mm T5.6"))
	var pos: Vector3 = _m67a_camera_position(c)
	var target: Vector3 = _m67a_camera_target(c)
	var delta: Vector3 = target - pos
	var dist3: float = delta.length()
	if dist3 <= 0.0001:
		dist3 = pos.length()
	var floor_dist: float = Vector2(pos.x - target.x, pos.z - target.z).length()
	if floor_dist <= 0.0001:
		floor_dist = Vector2(pos.x, pos.z).length()
	var azimuth: float = float(_m67a_value(c, ["azimuth", "yaw", "angle_deg"], rad_to_deg(atan2(pos.x - target.x, pos.z - target.z))))
	var tilt: float = float(_m67a_value(c, ["tilt", "pitch", "tilt_deg", "pitch_deg"], rad_to_deg(atan2(delta.y, max(0.0001, floor_dist)))))
	var width: int = int(_m67a_value(c, ["width", "render_width", "w"], 1920))
	var height: int = int(_m67a_value(c, ["height", "render_height", "h"], 1080))
	var fx: float = float(_m67a_value(c, ["fx", "fl_x", "focal_x"], 1817.8))
	var fy: float = float(_m67a_value(c, ["fy", "fl_y", "focal_y"], fx))
	var hfov: float = float(_m67a_value(c, ["hfov", "hfov_deg"], 2.0 * rad_to_deg(atan(float(width) / max(0.0001, 2.0 * fx)))))
	var vfov: float = float(_m67a_value(c, ["vfov", "vfov_deg"], 2.0 * rad_to_deg(atan(float(height) / max(0.0001, 2.0 * fy)))))
	return {"camera": name, "index": idx + 1, "tier": tier, "lens": lens, "resolution": str(width) + "x" + str(height), "width_px": width, "height_px": height, "fx_px": fx, "fy_px": fy, "hfov_deg": hfov, "vfov_deg": vfov, "x_m": pos.x, "y_height_m": pos.y, "z_m": pos.z, "x_ft": _m67a_feet(pos.x), "height_ft": _m67a_feet(pos.y), "z_ft": _m67a_feet(pos.z), "distance_3d_m": dist3, "distance_3d_ft": _m67a_feet(dist3), "floor_distance_m": floor_dist, "floor_distance_ft": _m67a_feet(floor_dist), "azimuth_deg": azimuth, "tilt_pitch_deg": tilt, "target_x_m": target.x, "target_y_m": target.y, "target_z_m": target.z, "construction_note": "Place camera at listed X/Y/Z relative to SplatViz stage origin; verify target/framing with Camera POV before build."}

func _m67a_csv_escape(v: Variant) -> String:
	var t: String = str(v).replace("\"", "\"\"")
	return "\"" + t + "\""

func _m67a_export_camera_layout() -> void:
	var cams_var: Variant = get("cameras")
	var rows: Array = []
	if typeof(cams_var) == TYPE_ARRAY:
		var cams: Array = cams_var as Array
		for i in range(cams.size()):
			var cv: Variant = cams[i]
			if typeof(cv) == TYPE_DICTIONARY:
				rows.append(_m67a_camera_row(cv as Dictionary, i))
	var out_dir: String = _m67a_layout_export_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var token: String = _m67a_now_token()
	var json_path: String = out_dir + "/splatviz_m67a_camera_layout_" + token + ".json"
	var csv_path: String = out_dir + "/splatviz_m67a_camera_layout_" + token + ".csv"
	var headers: Array = ["camera", "index", "tier", "lens", "resolution", "width_px", "height_px", "fx_px", "fy_px", "hfov_deg", "vfov_deg", "x_m", "y_height_m", "z_m", "x_ft", "height_ft", "z_ft", "distance_3d_m", "distance_3d_ft", "floor_distance_m", "floor_distance_ft", "azimuth_deg", "tilt_pitch_deg", "target_x_m", "target_y_m", "target_z_m", "construction_note"]
	var payload: Dictionary = {"schema": "splatviz.camera_layout.v1", "app_version": "M67A", "created_at": Time.get_datetime_string_from_system(false, true), "frame_policy": "scale-only; preserve camera frame; no crop; no squeeze", "camera_count": rows.size(), "rows": rows}
	var jf: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if jf:
		jf.store_string(JSON.stringify(payload, "\t"))
		jf.close()
	var lines: Array = []
	var head_fields: Array = []
	for h in headers:
		head_fields.append(_m67a_csv_escape(h))
	lines.append(",".join(head_fields))
	for row_v in rows:
		var row: Dictionary = row_v as Dictionary
		var fields: Array = []
		for h in headers:
			fields.append(_m67a_csv_escape(row.get(h, "")))
		lines.append(",".join(fields))
	var cf: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
	if cf:
		cf.store_string("\n".join(lines) + "\n")
		cf.close()
	_m67a_record_run_snapshot("export_camera_layout")
	OS.shell_open(out_dir)

func _m67a_default_history() -> Dictionary:
	return {"schema": "splatviz.project_history.v1", "project": "SplatViz", "created_at": Time.get_datetime_string_from_system(false, true), "storage_policy": {"large_artifacts_live_in": "SplatViz_Exports", "small_run_memory_lives_in": "project/splatviz_project_history.json", "rule": "Keep only currently relevant datasets/results; preserve metrics, paths, settings, and rationale in JSON."}, "roadmap": {"active_focus": "1080p professional-quality 3DGS, camera/render parity, layout export, true anisotropic splat preview", "defer": "4K training except small smoke tests until storage and capacity allow."}, "runs": []}

func _m67a_load_history() -> Dictionary:
	var path: String = _m67a_history_path()
	if FileAccess.file_exists(path):
		var txt: String = FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed as Dictionary
	return _m67a_default_history()

func _m67a_save_history(hist: Dictionary) -> void:
	var path: String = _m67a_history_path()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(hist, "\t"))
		f.close()

func _m67a_record_run_snapshot(source: String = "manual") -> void:
	var hist: Dictionary = _m67a_load_history()
	if not hist.has("runs") or typeof(hist["runs"]) != TYPE_ARRAY:
		hist["runs"] = []
	var rec: Dictionary = {"timestamp": Time.get_datetime_string_from_system(false, true), "source": source, "app_version": "M67A", "export_root_path": str(get("export_root_path")), "msplat_dataset_root": str(get("msplat_dataset_root")), "msplat_result_root": str(get("msplat_result_root")), "msplat_log_path": str(get("msplat_log_path")), "latest_ply_path": str(get("latest_ply_path")), "latest_ply_summary": str(get("latest_ply_summary")), "resolution_policy": "1080p-first; 4K only for smoke/source tests unless profile capacity allows", "frame_policy": "scale-only; no crop; no squeeze"}
	var runs: Array = hist["runs"] as Array
	runs.append(rec)
	hist["runs"] = runs
	hist["latest"] = rec
	_m67a_save_history(hist)
'''

if '_m67a_project_root()' not in s:
    s = s.rstrip() + m67a_block + '\n'

main.write_text(s)
print('Patched', main)
print('  M67A labels:', s.count('SplatViz M6.7A'))
print('  M67A camera layout helper:', s.count('func _m67a_export_camera_layout'))
print('  M67A history helper:', s.count('func _m67a_record_run_snapshot'))
print('  M67A UI buttons:', s.count('func(): _m67a_export_camera_layout()'))
