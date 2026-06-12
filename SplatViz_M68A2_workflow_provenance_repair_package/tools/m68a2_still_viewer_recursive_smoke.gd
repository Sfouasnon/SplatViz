extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _assert_ok(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _write_png(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.92, 0.94, 0.98, 1.0))
	_assert_ok(img.save_png(path) == OK, "Could not create PNG: " + path)

func _run() -> void:
	var smoke_root := OS.get_environment("M68A2_STILLS_SMOKE_ROOT")
	if smoke_root == "":
		smoke_root = "/tmp/m68a2_still_viewer_recursive_smoke_m63"
	DirAccess.make_dir_recursive_absolute(smoke_root)
	_write_png(smoke_root.path_join("images/C01/frame_000001.png"))
	_write_png(smoke_root.path_join("images/C02/frame_000001.png"))
	_write_png(smoke_root.path_join("camera_contact_renders/C03.png"))
	var manifest := {
		"app_release_label": "SplatViz M68A2",
		"export_tag": "m68a2",
		"export_timestamp": "20260528_121500"
	}
	var mf := FileAccess.open(smoke_root.path_join("render_manifest.json"), FileAccess.WRITE)
	_assert_ok(mf != null, "Could not create render manifest.")
	mf.store_string(JSON.stringify(manifest, "  "))
	mf.close()

	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main_node: Node = scene.instantiate()
	root.add_child(main_node)
	await process_frame
	main_node._open_stills_window()
	main_node._stills_set_folder(smoke_root)
	await process_frame
	await process_frame
	_assert_ok(main_node.stills_images.size() == 3, "Recursive still discovery did not find all nested images.")
	_assert_ok(main_node.stills_camera_option.item_count == 3, "Still Viewer dropdown did not list all discovered stills.")
	_assert_ok(str(main_node.stills_images[0]).find("C01") >= 0, "Natural sort did not place C01 first.")
	_assert_ok(str(main_node.stills_images[1]).find("C02") >= 0, "Natural sort did not place C02 second.")
	_assert_ok(str(main_node.stills_images[2]).find("C03") >= 0, "Natural sort did not place C03 third.")
	main_node.stills_index = 0
	main_node._stills_prev()
	await process_frame
	_assert_ok(int(main_node.stills_index) == 2, "Still Viewer Previous did not wrap to the last image.")
	main_node._stills_next()
	await process_frame
	_assert_ok(int(main_node.stills_index) == 0, "Still Viewer Next did not wrap back to the first image.")
	_assert_ok(str(main_node.stills_title_label.text).find("1/3") >= 0, "Still Viewer title did not show current index / total.")
	_assert_ok(str(main_node.stills_meta_label.text).find("Path:") >= 0, "Still Viewer metadata did not show the image path.")
	_assert_ok(str(main_node.stills_meta_label.text).find("Manifest release: SplatViz M68A2") >= 0, "Still Viewer metadata did not show manifest provenance.")
	_assert_ok(str(main_node.stills_meta_label.text).find("older export/result") >= 0, "Still Viewer did not warn about stale-path provenance.")

	var summary := {
		"discovered_count": int(main_node.stills_images.size()),
		"ordered_paths": main_node.stills_images,
		"title": str(main_node.stills_title_label.text),
		"folder_label": str(main_node.stills_folder_label.text),
		"meta_text": str(main_node.stills_meta_label.text)
	}
	var out_path := OS.get_environment("M68A2_STILLS_SMOKE_JSON")
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(summary, "  "))
			f.close()
	quit()
