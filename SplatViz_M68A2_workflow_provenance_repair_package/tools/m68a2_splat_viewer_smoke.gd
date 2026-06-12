extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _assert_ok(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _write_ascii_ply(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	_assert_ok(f != null, "Could not create ASCII PLY.")
	f.store_string("ply\n")
	f.store_string("format ascii 1.0\n")
	f.store_string("element vertex 4\n")
	f.store_string("property float x\n")
	f.store_string("property float y\n")
	f.store_string("property float z\n")
	f.store_string("property float opacity\n")
	f.store_string("property float f_dc_0\n")
	f.store_string("property float f_dc_1\n")
	f.store_string("property float f_dc_2\n")
	f.store_string("end_header\n")
	f.store_string("-0.20 1.10 -0.30 2.0 0.2 0.1 0.0\n")
	f.store_string("0.30 1.55 0.10 1.6 0.1 0.0 0.2\n")
	f.store_string("0.15 1.85 0.32 1.2 0.0 0.2 0.1\n")
	f.store_string("-0.08 1.42 0.28 0.8 0.15 0.15 0.15\n")
	f.close()

func _write_binary_ply(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	_assert_ok(f != null, "Could not create binary PLY.")
	f.big_endian = false
	f.store_string("ply\n")
	f.store_string("format binary_little_endian 1.0\n")
	f.store_string("element vertex 3\n")
	f.store_string("property float x\n")
	f.store_string("property float y\n")
	f.store_string("property float z\n")
	f.store_string("property float opacity\n")
	f.store_string("property float f_dc_0\n")
	f.store_string("property float f_dc_1\n")
	f.store_string("property float f_dc_2\n")
	f.store_string("end_header\n")
	var rows := [
		[-0.10, 1.20, -0.25, 1.8, 0.2, 0.0, 0.0],
		[0.22, 1.68, 0.12, 1.4, 0.0, 0.2, 0.0],
		[0.05, 1.92, 0.30, 1.0, 0.0, 0.0, 0.2]
	]
	for row in rows:
		for value in row:
			f.store_float(float(value))
	f.close()

func _run() -> void:
	var smoke_root := OS.get_environment("M68A2_SPLAT_VIEWER_SMOKE_ROOT")
	if smoke_root == "":
		smoke_root = "/tmp/m68a2_splat_viewer_smoke_m63"
	DirAccess.make_dir_recursive_absolute(smoke_root)
	var result_root := smoke_root.path_join("result_m63")
	var ascii_path := result_root.path_join("sample_ascii.ply")
	var binary_path := result_root.path_join("sample_binary.ply")
	_write_ascii_ply(ascii_path)
	_write_binary_ply(binary_path)
	var manifest := {
		"app_release_label": "SplatViz M65A",
		"export_tag": "m65"
	}
	var mf := FileAccess.open(result_root.path_join("splatviz_msplat_manifest.json"), FileAccess.WRITE)
	_assert_ok(mf != null, "Could not create splat manifest.")
	mf.store_string(JSON.stringify(manifest, "  "))
	mf.close()

	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main_node: Node = scene.instantiate()
	root.add_child(main_node)
	await process_frame

	main_node._import_ply_file(ascii_path)
	await process_frame
	_assert_ok(main_node.mode == "Splat View", "ASCII import did not switch to Splat View.")
	_assert_ok(str(main_node.latest_ply_path) == ascii_path, "ASCII import did not update latest_ply_path.")
	_assert_ok(int(main_node.latest_ply_valid_points) > 0, "ASCII import did not produce a visible preview.")
	_assert_ok(not (main_node.latest_ply_bounds_full as Dictionary).is_empty(), "ASCII import did not populate bounds.")
	_assert_ok(str(main_node.latest_ply_summary).find("Debug point preview") >= 0, "ASCII import did not report debug preview status.")
	_assert_ok(str(main_node.latest_ply_summary).find("Vertex/Gaussian count") >= 0, "ASCII import did not report count metadata.")
	_assert_ok(str(main_node.latest_ply_preview_mode) == "Original Coordinates", "Preview mode did not report Original Coordinates.")
	_assert_ok(str(main_node.latest_ply_provenance_text).find("older export/result") >= 0, "Splat View did not warn about stale provenance.")
	main_node._on_splat_show_bounds_toggled(true)
	await process_frame
	main_node._on_splat_show_capture_bounds_toggled(true)
	await process_frame
	main_node._fit_to_loaded_splat()
	await process_frame
	main_node._reset_splat_view()
	await process_frame
	var reset_distance: float = float(main_node.distance)
	_assert_ok(absf(reset_distance - 14.5) < 0.001, "Reset View did not restore the default orbit distance.")

	main_node._import_ply_file(binary_path)
	await process_frame
	_assert_ok(str(main_node.latest_ply_path) == binary_path, "Binary import did not update latest_ply_path.")
	_assert_ok(int(main_node.latest_ply_valid_points) > 0, "Binary little-endian import did not produce a visible preview.")
	_assert_ok(str(main_node.latest_ply_summary).find("format binary_little_endian") >= 0, "Binary import summary did not report the binary format.")

	var summary := {
		"ascii_path": ascii_path,
		"binary_path": binary_path,
		"latest_ply_path": main_node.latest_ply_path,
		"latest_ply_summary": main_node.latest_ply_summary,
		"latest_ply_provenance_text": main_node.latest_ply_provenance_text,
		"latest_ply_preview_mode": main_node.latest_ply_preview_mode,
		"latest_ply_bounds_full": main_node.latest_ply_bounds_full,
		"visible_points": int(main_node.latest_ply_valid_points),
		"mode": main_node.mode,
		"distance_after_reset": reset_distance
	}
	var out_path := OS.get_environment("M68A2_SPLAT_VIEWER_SMOKE_JSON")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(summary, "  "))
			f.close()
	quit()
