extends SceneTree

const PRESETS := [
	"Frame-Safe 12-Camera Multi-Tier",
	"Frame-Safe 24-Camera Multi-Tier",
	"Frame-Safe 36-Camera Multi-Tier",
]

func _init() -> void:
	call_deferred("_run")

func _assert_ok(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _parity_ok(main_node: Node) -> bool:
	for c_var in main_node.cameras:
		var c: Dictionary = c_var as Dictionary
		var a: Dictionary = main_node._m66d_capture_config(c, Vector2i(1920, 1080))
		var b: Dictionary = main_node._m66d_capture_config(c, Vector2i(1280, 720))
		if not (main_node._m66d_compare_capture_states(a, b) as Array).is_empty():
			return false
	return true

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main_node: Node = scene.instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame

	_assert_ok(not bool(main_node.inspector_visible), "Inspector did not start collapsed.")
	_assert_ok(not bool(main_node.splat_all_frustums), "Selected-frustum default regressed.")

	var summary := {
		"title": str(main_node.get_window().title),
		"presets": [],
		"default_labels": [],
		"custom_warning": "",
		"camera_pov_prev_x": 0.0,
		"camera_pov_next_x": 0.0
	}

	main_node._set_mode("Camera POV")
	await process_frame
	summary["camera_pov_prev_x"] = float(main_node.camera_pov_prev_button.position.x)
	summary["camera_pov_next_x"] = float(main_node.camera_pov_next_button.position.x)

	for preset in PRESETS:
		main_node._set_layout(preset)
		await process_frame
		main_node._m67h_refresh_all_camera_layout_fields()
		(summary["presets"] as Array).append({
			"preset": preset,
			"camera_count": main_node.cameras.size(),
			"ALL_PARITY_OK": _parity_ok(main_node)
		})

	main_node._set_layout("Frame-Safe 36-Camera Multi-Tier")
	await process_frame
	main_node.report_camera_label_scheme = "AA-ID 36 Camera Grid"
	var labels: Array = []
	for i in range(main_node.cameras.size()):
		var c: Dictionary = main_node.cameras[i] as Dictionary
		labels.append(main_node._m68a3_camera_label_for(i, str(c.get("id", ""))))
	summary["default_labels"] = labels
	_assert_ok(labels.size() == 36, "Expected 36 production camera labels.")
	_assert_ok(str(labels[0]) == "AA" and str(labels[35]) == "ID", "AA-ID default labels did not apply.")

	main_node.report_camera_label_scheme = "Custom comma-separated labels"
	main_node.report_custom_camera_labels = "AA,AB,AC"
	summary["custom_warning"] = str(main_node._m68a3_camera_label_warning(main_node.cameras.size()))
	_assert_ok(str(summary["custom_warning"]).find("fell back") >= 0, "Custom label mismatch warning missing.")

	var out_path := OS.get_environment("M68A3_LABEL_SMOKE_JSON")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(summary, "  "))
			f.close()
	quit()
