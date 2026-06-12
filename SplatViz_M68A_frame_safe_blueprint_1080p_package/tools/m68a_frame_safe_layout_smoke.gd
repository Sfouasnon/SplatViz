extends SceneTree

const PRESETS := [
	"Frame-Safe 12-Camera Multi-Tier",
	"Frame-Safe 24-Camera Multi-Tier",
	"Frame-Safe 36-Camera Multi-Tier",
]

func _init() -> void:
	call_deferred("_run")

func _margin_extrema(cam_list: Array) -> Dictionary:
	var min_margin := 999.0
	var max_margin := -999.0
	for c_var in cam_list:
		var c: Dictionary = c_var as Dictionary
		var margins: Dictionary = c.get("subject_frame_qc_margins_pct", c.get("frame_qc_margins", {}))
		for key in ["left_pct", "right_pct", "top_pct", "bottom_pct"]:
			if margins.has(key):
				var v := float(margins[key])
				min_margin = min(min_margin, v)
				max_margin = max(max_margin, v)
	if min_margin == 999.0:
		min_margin = 0.0
	if max_margin == -999.0:
		max_margin = 0.0
	return {"min": min_margin, "max": max_margin}

func _parity_ok(main_node: Node) -> bool:
	for c_var in main_node.cameras:
		var c: Dictionary = c_var as Dictionary
		var a: Dictionary = main_node._m66d_capture_config(c, Vector2i(1920, 1080))
		var b: Dictionary = main_node._m66d_capture_config(c, Vector2i(1280, 720))
		var cmp: Array = main_node._m66d_compare_capture_states(a, b)
		if not cmp.is_empty():
			return false
	return true

func _run() -> void:
	var summary := {"presets": []}
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main_node: Node = scene.instantiate()
	root.add_child(main_node)
	await process_frame
	for preset in PRESETS:
		main_node._set_layout(preset)
		await process_frame
		main_node._m67h_refresh_all_camera_layout_fields()
		var counts: Dictionary = main_node._m67h_qc_counts(main_node.cameras)
		var volume_counts: Dictionary = main_node._m67h_volume_qc_counts(main_node.cameras)
		var extrema: Dictionary = _margin_extrema(main_node.cameras)
		var row := {
			"preset": preset,
			"camera_count": main_node.cameras.size(),
			"subject_counts": counts,
			"volume_counts": volume_counts,
			"subject_margin_min_pct": snappedf(float(extrema.get("min", 0.0)), 0.01),
			"subject_margin_max_pct": snappedf(float(extrema.get("max", 0.0)), 0.01),
			"ALL_PARITY_OK": _parity_ok(main_node)
		}
		print(JSON.stringify(row, "  "))
		(summary["presets"] as Array).append(row)
	var out_path := OS.get_environment("M68A_LAYOUT_SMOKE_JSON")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(summary, "  "))
			f.close()
	quit()
