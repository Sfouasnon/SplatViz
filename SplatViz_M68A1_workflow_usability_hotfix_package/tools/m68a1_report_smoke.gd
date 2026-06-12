extends SceneTree

var png_1x1 := Marshalls.base64_to_raw("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRXsAAAAASUVORK5CYII=")

func _init() -> void:
	call_deferred("_run")

func _write_png(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(png_1x1)
		f.close()

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

func _run() -> void:
	var report_root := OS.get_environment("M68A1_REPORT_SMOKE_ROOT")
	if report_root == "":
		report_root = "/tmp/m68a1_report_smoke"
	DirAccess.make_dir_recursive_absolute(report_root)
	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main_node: Node = scene.instantiate()
	root.add_child(main_node)
	await process_frame
	main_node.installation_mode = "Mixed"
	main_node._set_layout(OS.get_environment("SPLATVIZ_LAYOUT") if OS.get_environment("SPLATVIZ_LAYOUT") != "" else "Frame-Safe 36-Camera Multi-Tier")
	await process_frame
	var contact_dir := report_root.path_join("camera_contact_renders")
	var diagnostic_dir := report_root.path_join("camera_qc_diagnostics")
	DirAccess.make_dir_recursive_absolute(contact_dir)
	DirAccess.make_dir_recursive_absolute(diagnostic_dir)
	for c_var in main_node.cameras:
		var c: Dictionary = c_var as Dictionary
		var name: String = main_node._camera_unique_filename(c)
		if main_node._m67h_camera_exports_contact_frame(c):
			_write_png(contact_dir.path_join(name))
		elif main_node._m67h_camera_requires_diagnostic_thumbnail(c):
			_write_png(diagnostic_dir.path_join(name))
	var data: Array = main_node._m67g_camera_report_data(contact_dir, diagnostic_dir)
	var payload: Dictionary = main_node._m67g_report_payload(report_root, data, "20260528_120000")
	main_node._m67g_write_report_files(report_root, payload)
	_copy_file(report_root.path_join("top_plan.svg"), report_root.path_join("assets/top_plan.svg"))
	_copy_file(report_root.path_join("front_elevation.svg"), report_root.path_join("assets/front_elevation.svg"))
	_copy_file(report_root.path_join("side_elevation.svg"), report_root.path_join("assets/side_elevation.svg"))
	_copy_file(report_root.path_join("support_legend.svg"), report_root.path_join("assets/support_legend.svg"))
	var payload_out := OS.get_environment("M68A1_REPORT_SMOKE_JSON")
	if payload_out != "":
		var f := FileAccess.open(payload_out, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(payload, "  "))
			f.close()
	quit()
