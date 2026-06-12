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

func _count_named(root_node: Node, needle: String) -> int:
	if root_node == null:
		return 0
	var count := 0
	for child in root_node.get_children():
		if str(child.name).findn(needle) >= 0:
			count += 1
	return count

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
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main_node: Node = scene.instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame

	_assert_ok(main_node.get_window().title == "SplatViz M68A2", "Window title did not update to SplatViz M68A2.")
	_assert_ok(main_node.mode == "Rigging / Lighting", "Startup mode is not Rigging / Lighting.")
	_assert_ok(not bool(main_node.inspector_visible), "Inspector did not start collapsed.")
	_assert_ok(not bool(main_node.splat_all_frustums), "Show All Frustums did not start disabled.")
	var startup_mode: String = main_node.mode
	var startup_inspector_collapsed := not bool(main_node.inspector_visible)
	var startup_selected_only := not bool(main_node.splat_all_frustums)
	var startup_frustum_count: int = _count_named(main_node.overlay_root, "frustum")
	_assert_ok(startup_frustum_count == 1, "Startup did not show selected frustum only.")

	main_node._set_mode("Camera POV")
	await process_frame
	await process_frame
	_assert_ok(bool(main_node.camera_pov_preview_panel.visible), "Camera POV preview panel did not open.")
	var panel_size: Vector2 = main_node.camera_pov_preview_panel.size
	var panel_style: StyleBox = main_node.camera_pov_preview_panel.get_theme_stylebox("panel")
	var panel_alpha := 1.0
	if panel_style is StyleBoxFlat:
		panel_alpha = float((panel_style as StyleBoxFlat).bg_color.a)
	_assert_ok(float(main_node.camera_pov_prev_button.position.x) < panel_size.x * 0.25, "Camera POV Previous button is still too centered.")
	_assert_ok(float(main_node.camera_pov_next_button.position.x) > panel_size.x * 0.55, "Camera POV Next button is still too centered.")
	_assert_ok(float(main_node.camera_pov_status_label.position.y) < 32.0, "Camera POV status label is not near the frame edge.")
	_assert_ok(panel_alpha <= 0.05, "Camera POV preview still uses a visible full-frame dimming panel.")

	var stamp: String = main_node._m68a_timestamp()
	var rx := RegEx.new()
	rx.compile("^\\d{8}_\\d{6}$")
	_assert_ok(rx.search(stamp) != null, "Timestamp helper did not return YYYYMMDD_HHMMSS.")
	var sample_render_root: String = main_node._m68a_make_timestamped_output_root("splatviz_render_selected_m68a2", stamp)
	_assert_ok(sample_render_root.ends_with("splatviz_render_selected_m68a2_" + stamp), "Selected render helper did not use the M68A2 parent folder naming.")
	var sample_report_root: String = main_node._m68a_layout_report_folder_name(stamp)
	_assert_ok(sample_report_root == "SplatViz_Layout_Report_M68A2_" + stamp, "Layout report helper did not use the M68A2 report folder naming.")

	var summary := {
		"release_label": main_node.get_window().title,
		"startup_mode": startup_mode,
		"inspector_collapsed": startup_inspector_collapsed,
		"selected_only_default": startup_selected_only,
		"startup_frustum_count": startup_frustum_count,
		"timestamp": stamp,
		"sample_render_root": sample_render_root,
		"sample_report_root": sample_report_root,
		"camera_pov_prev_x": float(main_node.camera_pov_prev_button.position.x),
		"camera_pov_next_x": float(main_node.camera_pov_next_button.position.x),
		"camera_pov_status_y": float(main_node.camera_pov_status_label.position.y),
		"camera_pov_panel_alpha": panel_alpha,
		"camera_pov_parity_ok": _parity_ok(main_node),
		"presets": []
	}

	for preset in PRESETS:
		main_node._set_layout(preset)
		await process_frame
		main_node._m67h_refresh_all_camera_layout_fields()
		(summary["presets"] as Array).append({
			"preset": preset,
			"camera_count": main_node.cameras.size(),
			"subject_counts": main_node._m67h_qc_counts(main_node.cameras),
			"volume_counts": main_node._m67h_volume_qc_counts(main_node.cameras),
			"ALL_PARITY_OK": _parity_ok(main_node)
		})

	var out_path := OS.get_environment("M68A2_LAYOUT_SMOKE_JSON")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(summary, "  "))
			f.close()
	quit()
