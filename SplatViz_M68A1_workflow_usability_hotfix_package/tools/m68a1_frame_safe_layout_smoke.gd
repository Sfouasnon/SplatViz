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

	_assert_ok(main_node.mode == "Rigging / Lighting", "Startup mode is not Rigging / Lighting.")
	_assert_ok(not bool(main_node.inspector_visible), "Inspector did not start collapsed.")
	_assert_ok(not bool(main_node.splat_all_frustums), "Show All Frustums did not start disabled.")
	var startup_mode: String = main_node.mode
	var startup_inspector_collapsed := not bool(main_node.inspector_visible)
	var startup_selected_only := not bool(main_node.splat_all_frustums)
	var startup_frustum_count: int = _count_named(main_node.overlay_root, "frustum")
	_assert_ok(startup_frustum_count == 1, "Startup did not show selected frustum only.")
	if main_node.show_all_frustums_toggle != null:
		_assert_ok(not bool(main_node.show_all_frustums_toggle.button_pressed), "Show All Frustums toggle started enabled.")

	main_node._on_show_all_frustums_toggled(true)
	await process_frame
	await process_frame
	var rig_all_count := _count_named(main_node.overlay_root, "frustum")

	main_node._on_show_all_frustums_toggled(false)
	await process_frame
	_assert_ok(_count_named(main_node.overlay_root, "frustum") == 1, "Selected-only frustum mode did not restore.")

	main_node._set_mode("Splat Viability")
	await process_frame
	await process_frame
	_assert_ok(not bool(main_node.splat_all_frustums), "Splat Viability did not preserve selected-only frustum mode.")
	var nav_start: int = int(main_node.selected_index)
	main_node._select_prev_camera()
	await process_frame
	_assert_ok(int(main_node.selected_index) == (nav_start - 1 + main_node.cameras.size()) % main_node.cameras.size(), "Previous camera navigation failed in Splat Viability.")
	_assert_ok(int(main_node.camera_option.selected) == int(main_node.selected_index), "Camera dropdown did not track selected_index after Previous.")
	var selected_cam: Dictionary = main_node.cameras[int(main_node.selected_index)] as Dictionary
	_assert_ok(str(main_node.inspector_label.text).find(str(selected_cam.get("id", ""))) >= 0, "Inspector did not refresh selected camera metadata.")
	main_node._select_next_camera()
	await process_frame
	_assert_ok(int(main_node.selected_index) == nav_start, "Next camera navigation failed in Splat Viability.")
	main_node._on_show_all_frustums_toggled(true)
	await process_frame
	await process_frame
	var viability_all_count := _count_named(main_node.overlay_root, "frustum")
	_assert_ok(viability_all_count >= main_node.cameras.size() - 1, "Splat Viability all-frustum mode failed. Count=" + str(viability_all_count) + " cameras=" + str(main_node.cameras.size()))
	main_node._on_show_all_frustums_toggled(false)

	main_node._set_mode("Camera POV")
	await process_frame
	_assert_ok(bool(main_node.camera_pov_preview_panel.visible), "Camera POV preview panel did not open.")
	var pov_start: int = int(main_node.selected_index)
	main_node._select_next_camera()
	await process_frame
	_assert_ok(int(main_node.selected_index) == (pov_start + 1) % main_node.cameras.size(), "Next camera navigation failed in Camera POV.")
	var pov_cam: Dictionary = main_node.cameras[int(main_node.selected_index)] as Dictionary
	_assert_ok(str(main_node.camera_pov_status_label.text).find(str(pov_cam.get("id", ""))) >= 0, "Camera POV status label did not refresh.")
	main_node._select_prev_camera()
	await process_frame
	_assert_ok(int(main_node.selected_index) == pov_start, "Previous camera navigation failed in Camera POV.")

	var rx := RegEx.new()
	rx.compile("^\\d{8}_\\d{6}$")
	var stamp: String = main_node._m68a_timestamp()
	_assert_ok(rx.search(stamp) != null, "Timestamp helper did not return YYYYMMDD_HHMMSS.")
	var sample_root: String = main_node._m68a_make_timestamped_output_root("render_selected_smoke", stamp)
	_assert_ok(sample_root.ends_with("render_selected_smoke_" + stamp), "Timestamped output root helper did not append the timestamp to the parent folder name.")

	var summary := {
		"startup_mode": startup_mode,
		"inspector_collapsed": startup_inspector_collapsed,
		"selected_only_default": startup_selected_only,
		"startup_frustum_count": startup_frustum_count,
		"timestamp": stamp,
		"sample_output_root": sample_root,
		"presets": []
	}

	for preset in PRESETS:
		main_node._set_layout(preset)
		await process_frame
		main_node._m67h_refresh_all_camera_layout_fields()
		var row := {
			"preset": preset,
			"camera_count": main_node.cameras.size(),
			"subject_counts": main_node._m67h_qc_counts(main_node.cameras),
			"volume_counts": main_node._m67h_volume_qc_counts(main_node.cameras),
			"ALL_PARITY_OK": _parity_ok(main_node)
		}
		(summary["presets"] as Array).append(row)
		print(JSON.stringify(row, "  "))

	var out_path := OS.get_environment("M68A1_LAYOUT_SMOKE_JSON")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(summary, "  "))
			f.close()
	quit()
