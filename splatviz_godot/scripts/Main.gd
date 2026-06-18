extends Node3D
# M67G1 panel-style compatibility repair

const SPLATVIZ_RELEASE_LABEL = "SplatViz M68A2"
const SPLATVIZ_EXPORT_TAG = "m68a2"
const FT_TO_M = 0.3048
const STAGE_W_M = 17.98
const STAGE_D_M = 17.37
const GRID_H_M = 5.49
const ROBOT_HEIGHT_M = 1.8034 # 5 ft 11 in
const TARGET = Vector3(0.0, 1.62, 0.0) # approximate eye/focus height for 5 ft 11 in subject
const M67H_CAPTURE_VOLUME_BASE_CENTER_M = Vector3(0.0, 0.925, 0.0)
const M67H_CAPTURE_VOLUME_BASE_SIZE_M = Vector3(1.20, 1.85, 1.35)
const M67H_CAPTURE_VOLUME_MOTION_MARGIN_M = Vector3(0.16, 0.10, 0.16)
const M67H_SUBJECT_BOUNDS_PADDING_M = Vector3(0.07, 0.03, 0.07)
const M67H_SUBJECT_BOTTOM_TARGET_MARGIN_PCT = 11.0
const M67H_SUBJECT_SIDE_TARGET_MARGIN_PCT = 9.0
const M67H_SUBJECT_TOP_MIN_MARGIN_PCT = 5.0
const M67H_SUBJECT_HARD_FAIL_MARGIN_PCT = 2.0
const M67H_VOLUME_WARNING_MARGIN_PCT = 4.0
const M67H_GENERATOR_RADIUS_SAFETY_FACTOR = 1.08
const M67H_GENERATOR_RADIUS_STEP_M = 0.12
const M67H_GENERATOR_MIN_RADIUS_M = 2.8
const M67H_GENERATOR_MAX_RADIUS_M = 6.6
const CLEAN_RENDER_SIZE = Vector2i(1920, 1080)
const M67F_REPORT_CONTACT_RENDER_SIZE = Vector2i(1280, 720) # clean 16:9 report contact renders; no crop/squeeze/letterbox # 1080p at source 16:9 aspect
const SOURCE_RENDER_SIZE = Vector2i(3840, 2160) # M66E source training stills, lossless 4K 16:9
# Capture-camera optics now live in capture_math.gd (single source of truth).
# These aliases keep existing call sites working during the module split.
const M66D_CAPTURE_KEEP_ASPECT = CaptureMath.CAPTURE_KEEP_ASPECT
const M66D_CAPTURE_NEAR = CaptureMath.CAPTURE_NEAR
const M66D_CAPTURE_FAR = CaptureMath.CAPTURE_FAR
const M66D_LANDSCAPE_VFOV_DEG = CaptureMath.LANDSCAPE_VFOV_DEG
const M66D_PORTRAIT_VFOV_DEG = CaptureMath.PORTRAIT_VFOV_DEG
var LEFT_PANEL_W = 360.0 # M67F mutable left rail width
const RIGHT_PANEL_W = 455.0
const TOP_BAR_H = 58.0

var mat_floor: StandardMaterial3D
var mat_grid: StandardMaterial3D
var mat_truss: StandardMaterial3D
var mat_stand: StandardMaterial3D
var mat_camera_body: StandardMaterial3D
var mat_camera_lens: StandardMaterial3D
var mat_camera_selected: StandardMaterial3D
var mat_body: StandardMaterial3D
var mat_focus_box: StandardMaterial3D
var mat_frustum_faint: StandardMaterial3D
var mat_selected: StandardMaterial3D
var mat_prev: StandardMaterial3D
var mat_next: StandardMaterial3D
var mat_weak_line: StandardMaterial3D
var mat_focus_too_near: StandardMaterial3D
var mat_focus_accept: StandardMaterial3D
var mat_focus_critical: StandardMaterial3D

var orbit_camera: Camera3D
var stage_root: Node3D
var camera_root: Node3D
var overlay_root: Node3D
var rig_root: Node3D
var performer_root: Node3D
var focus_envelope_root: Node3D
var robot_model_root: Node3D
var height_scale_root: Node3D
var ui_layer: CanvasLayer
var status_label: Label
var inspector_label: Label
var prediction_label: Label
var camera_option: OptionButton
var export_path_label: Label
var export_dialog: FileDialog
var layout_report_dialog_m67c: FileDialog
var layout_report_mode_dialog_m67g: ConfirmationDialog
var layout_report_mode_option_m67g: OptionButton
var msplat_dataset_dialog: FileDialog
var ply_import_dialog: FileDialog
var right_panel: PanelContainer
var top_bar: PanelContainer
var inspector_toggle_button: Button
var layout_option: OptionButton
var mode_label: Label
var left_panel: PanelContainer
var left_panel_width_m67c = 360.0
var left_panel_collapsed_m67c = false
var left_panel_toggle_button_m67c: Button
var left_panel_narrow_button_m67c: Button
var left_panel_wide_button_m67c: Button
var prev_cam_button: Button
var next_cam_button: Button
var edit_status_label: Label
var msplat_status_label: Label
var msplat_panel: PanelContainer
var msplat_window: Window
var msplat_terminal_label
var msplat_path_label: Label
var msplat_command_label: Label
var msplat_iters_option: OptionButton
var msplat_progress_bar: ProgressBar
var msplat_progress_label: Label
var msplat_last_step = 0
var msplat_last_splats = 0
var msplat_log_path = ""
var msplat_running = false
var msplat_poll_seconds = 0.0
var msplat_final_refresh_ticks = 0
var msplat_process_id = -1
var msplat_log_last_size = 0
var msplat_log_idle_seconds = 0.0
var msplat_stall_notice_shown = false
var msplat_last_phase = "idle"
var msplat_train_path = ""
var msplat_num_iters = 1500
var latest_ply_path = ""
var latest_ply_summary = ""
var latest_ply_valid_points = 0
var latest_ply_bounds_full: Dictionary = {}
var latest_ply_bounds_focus: Dictionary = {}
var latest_ply_preview_mode := "No PLY loaded"
var latest_ply_provenance_text := "No manifest found; provenance unknown."
var latest_ply_show_bounds := true
var latest_ply_show_capture_bounds := true
var latest_ply_auto_fit_camera := false
var msplat_dataset_root = ""
var msplat_result_root = ""
var msplat_export_unsafe_override_once := false
var m67h_last_dataset_unsafe_override_used := false
var m67h_last_dataset_omitted_camera_ids: Array[String] = []
var splat_root: Node3D
var splat_point_material: StandardMaterial3D


# M66A: Passive disk-based Still Viewer. It browses exported image folders and
# optional metadata JSON without mutating cameras/export/msplat state.
const STILL_VIEWER_LENS_NAME := "Rokinon 24mm T5.6"
var stills_window: Window
var stills_panel_root: Control
var stills_folder_dialog: FileDialog
var stills_image_rect: TextureRect
var stills_folder_label: Label
var stills_title_label: Label
var stills_status_label: Label
var stills_meta_label: Label
var stills_camera_option: OptionButton
var stills_zoom_button: Button
var stills_folder_path := ""
var stills_images: Array[String] = []
var stills_index := 0
var stills_zoom_1to1 := false
var stills_metadata: Dictionary = {}
var stills_discovery_root := ""
var stills_provenance_text := "No manifest found; provenance unknown."

var mode = "Focus"
var layout_name = "Frame-Safe 36-Camera Multi-Tier"
var installation_mode := "Mixed"
var selected_index = 0
var cameras: Array = []
var camera_nodes: Array = []
var export_root_path = ""
var inspector_visible = false
var camera_pov_active = false
var comparison_panel: PanelContainer
var comparison_label: Label
var focus_readout_panel: PanelContainer
var focus_readout_label: Label
var show_all_frustums_toggle: CheckButton


# M66D: navigation legend + exact Camera POV preview overlay.
var nav_legend_panel: PanelContainer
var nav_legend_visible := true
var camera_pov_preview_panel: PanelContainer
var camera_pov_texture_rect: TextureRect
var camera_pov_status_label: Label
var camera_pov_prev_button: Button
var camera_pov_next_button: Button
var camera_pov_subviewport: SubViewport
var camera_pov_render_camera: Camera3D
var splat_all_frustums = false
var m67b_render_dialog: Window
var m67b_render_selected_only: bool = false
var m67b_splat_tools_panel: PanelContainer
var splat_show_bounds_toggle: CheckButton
var splat_show_capture_bounds_toggle: CheckButton
var settings_window_m68a3: Window
var report_capture_specs := "36 Komodo-X array"
var report_stage_specs := "Stage 1 NOZ, Truss Build"
var report_performer_specs := "Dolly Parton performs 30 songs over 2 days"
var report_stage_name := "NOZ Stage #1"
var report_floor_type := "Wood sound-stage floor"
var report_camera_label_scheme := "AA-ID 36 Camera Grid"
var report_custom_camera_labels := ""
var report_preview_background := "Sound Stage / Wood Floor"
var report_height_scale_enabled := true
var report_performer_height_m := ROBOT_HEIGHT_M
var report_performer_height_source := "default"
var settings_capture_specs_edit: LineEdit
var settings_stage_specs_edit: LineEdit
var settings_performer_specs_edit: LineEdit
var settings_stage_name_edit: LineEdit
var settings_floor_type_edit: LineEdit
var settings_build_mode_option: OptionButton
var settings_label_scheme_option: OptionButton
var settings_custom_labels_edit: LineEdit
var settings_preview_background_option: OptionButton
var settings_height_m_edit: LineEdit
var settings_height_scale_toggle: CheckButton

var pivot = Vector3(0, 1.2, 0)
var yaw = deg_to_rad(-38.0)
var pitch = deg_to_rad(-34.0)
var distance = 14.5
var mouse_down_left = false
var mouse_down_middle = false
var mouse_down_right = false
var last_mouse = Vector2.ZERO
var active_pointer_in_view = false

func _ready() -> void:
	export_root_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/SplatViz_Exports"
	get_window().title = SPLATVIZ_RELEASE_LABEL
	_build_materials()
	_build_world()
	_build_ui()
	_m67f_update_focus_legend()
	_m67c_init_left_panel_controls()
	_m67c_init_layout_report_dialog()
	_set_layout(layout_name)
	_set_mode("Rigging / Lighting")
	_update_orbit_camera()
	_update_inspector()
	_m68a_update_camera_nav_ui()
	_update_export_label()

func _process(delta: float) -> void:
	_process_keyboard(delta)
	_layout_ui()
	_m67c_update_left_panel_controls()
	_poll_msplat_terminal(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# M66C: Esc closes Still Viewer before falling through to scene controls.
		if event.keycode == KEY_ESCAPE and stills_window != null and stills_window.visible:
			stills_window.visible = false
			return
		if event.keycode == KEY_ESCAPE:
			mouse_down_left = false
			mouse_down_middle = false
			mouse_down_right = false
		# M66D: navigation hotkeys.
		elif event.keycode == KEY_H:
			_toggle_nav_legend()
		elif event.keycode == KEY_R:
			_reset_current_view()
		elif event.keycode == KEY_F:
			_frame_selected_camera()
		elif _m68a_camera_nav_shortcuts_allowed() and event.keycode == KEY_BRACKETLEFT:
			_select_prev_camera()
			return
		elif _m68a_camera_nav_shortcuts_allowed() and event.keycode == KEY_BRACKETRIGHT:
			_select_next_camera()
			return
		elif event.keycode == KEY_1:
			_preset_perspective()
		elif event.keycode == KEY_2:
			_preset_top()
		elif event.keycode == KEY_3:
			_preset_front()
		elif event.keycode == KEY_4:
			_preset_eye_line()
		elif event.keycode == KEY_5:
			_preset_truss()

	if event is InputEventMouseButton:
		var in_view = _viewport_hit(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_down_left = event.pressed and in_view
			active_pointer_in_view = in_view
			last_mouse = event.position
			if event.pressed and in_view and not Input.is_key_pressed(KEY_SHIFT):
				_try_select_camera(event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			mouse_down_middle = event.pressed and in_view
			active_pointer_in_view = in_view
			last_mouse = event.position
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_down_right = event.pressed and in_view
			active_pointer_in_view = in_view
			last_mouse = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and in_view:
			distance = max(0.25, distance * 0.9)
			_update_orbit_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and in_view:
			distance = min(80.0, distance * 1.1)
			_update_orbit_camera()

	# M66D: Mac trackpad pinch zoom in all viewport modes. Pinch out zooms in; pinch in zooms out.
	if event is InputEventMagnifyGesture:
		var magnify_event: InputEventMagnifyGesture = event as InputEventMagnifyGesture
		var zoom_factor: float = clamp(float(magnify_event.factor), 0.50, 2.00)
		if zoom_factor > 0.001:
			distance = clamp(distance / zoom_factor, 0.25, 80.0)
			_update_orbit_camera()
			return

	# M66D: two-finger trackpad pan translates the view left/right/up/down.
	if event is InputEventPanGesture:
		var pan_event: InputEventPanGesture = event as InputEventPanGesture
		_pan_view(pan_event.delta * 1.65)
		return

	if event is InputEventMouseMotion and active_pointer_in_view:
		var delta = event.position - last_mouse
		last_mouse = event.position
		if mouse_down_left and Input.is_key_pressed(KEY_SHIFT):
			_pan_view(delta)
		elif mouse_down_left:
			yaw -= delta.x * 0.008
			pitch = clamp(pitch - delta.y * 0.006, deg_to_rad(-86.0), deg_to_rad(5.0))
			_update_orbit_camera()
		elif mouse_down_middle:
			_pan_view(delta)
		elif mouse_down_right:
			yaw -= delta.x * 0.006
			pitch = clamp(pitch - delta.y * 0.006, deg_to_rad(-86.0), deg_to_rad(20.0))
			_update_orbit_camera()

func _right_panel_width() -> float:
	return RIGHT_PANEL_W if inspector_visible else 0.0

func _m68a_timestamp() -> String:
	var d = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [int(d["year"]), int(d["month"]), int(d["day"]), int(d["hour"]), int(d["minute"]), int(d["second"])]

func _m68a_focus_owner_accepts_text_input() -> bool:
	var owner = get_viewport().gui_get_focus_owner()
	return owner is LineEdit or owner is TextEdit

func _m68a_camera_nav_shortcuts_allowed() -> bool:
	return not _m68a_focus_owner_accepts_text_input()

func _m68a_make_timestamped_output_root(prefix: String, stamp: String = "") -> String:
	if stamp == "":
		stamp = _m68a_timestamp()
	return export_root_path.path_join(prefix + "_" + stamp)

func _m68a_selected_camera_status_text() -> String:
	if cameras.is_empty() or selected_index < 0 or selected_index >= cameras.size():
		return "No camera selected"
	var c: Dictionary = cameras[selected_index]
	var subject_status = str(c.get("subject_frame_qc_status", c.get("frame_qc_status", "UNKNOWN")))
	var volume_status = str(c.get("volume_frame_qc_status", "OUTSIDE"))
	return str(c.get("id", "")) + " · " + str(selected_index + 1) + "/" + str(cameras.size()) + " · subject " + subject_status + " · volume " + volume_status

func _m68a_set_inspector_visible(visible: bool) -> void:
	inspector_visible = visible
	if right_panel != null:
		right_panel.visible = inspector_visible
	if inspector_toggle_button != null:
		inspector_toggle_button.text = "Hide Inspector" if inspector_visible else "Show Inspector"
		var screen_size = get_viewport().get_visible_rect().size
		inspector_toggle_button.position = Vector2(screen_size.x - RIGHT_PANEL_W - 112, TOP_BAR_H + 8) if inspector_visible else Vector2(screen_size.x - 138, TOP_BAR_H + 8)

func _m68a_update_camera_nav_ui() -> void:
	var nav_text = _m68a_selected_camera_status_text()
	if camera_pov_status_label != null:
		camera_pov_status_label.text = "Camera POV — " + nav_text + "  ·  [ / ]"
	if prev_cam_button != null:
		prev_cam_button.disabled = cameras.is_empty()
		prev_cam_button.tooltip_text = "Previous camera"
	if next_cam_button != null:
		next_cam_button.disabled = cameras.is_empty()
		next_cam_button.tooltip_text = "Next camera"
	if camera_pov_prev_button != null:
		camera_pov_prev_button.disabled = cameras.is_empty()
	if camera_pov_next_button != null:
		camera_pov_next_button.disabled = cameras.is_empty()

func _m68a_layout_profile_slug() -> String:
	match layout_name:
		"Frame-Safe 12-Camera Multi-Tier":
			return "frame_safe12"
		"Frame-Safe 24-Camera Multi-Tier":
			return "frame_safe24"
		"Frame-Safe 36-Camera Multi-Tier":
			return "frame_safe36"
		"Lean 16-Camera Msplat":
			return "lean16_msplat"
		"Recommended 24-Camera Baseline":
			return "recommended24_baseline"
		"Premium 36-Camera Multi-Tier":
			return "premium36_multi_tier"
		_:
			return layout_name.to_lower().replace(" ", "_").replace("-", "_")

func _m68a_layout_report_folder_name(stamp: String) -> String:
	return "SplatViz_Layout_Report_M68A2_" + stamp

func _m68a_trimmed_path(path: String, max_len: int = 104) -> String:
	if path.length() <= max_len:
		return path
	return "…" + path.substr(max(0, path.length() - max_len + 1))

func _m68a_natural_sort_key(text: String) -> String:
	var rx := RegEx.new()
	if rx.compile("\\d+") != OK:
		return text.to_lower()
	var out := text.to_lower()
	var matches := rx.search_all(out)
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var digits := m.get_string()
		var padded := digits.pad_zeros(8)
		out = out.substr(0, m.get_start()) + padded + out.substr(m.get_end())
	return out

func _m68a_path_uses_stale_export_tag(path: String) -> bool:
	var rx := RegEx.new()
	if rx.compile("(^|[^a-z0-9])(m63|m65|m66|m67)([^a-z0-9]|$)") != OK:
		return false
	return rx.search(path.to_lower()) != null

func _m68a_release_warning_for_path(path: String) -> String:
	if path == "":
		return ""
	if _m68a_path_uses_stale_export_tag(path):
		return "This appears to be an older export/result and may not reflect the current Frame-Safe M68A2 workflow."
	return ""

func _m68a_manifest_candidates_for_path(path: String) -> Array:
	var candidates: Array = []
	var current := path
	if not DirAccess.dir_exists_absolute(current):
		current = current.get_base_dir()
	for _i in range(6):
		if current == "":
			break
		candidates.append(current.path_join("render_manifest.json"))
		candidates.append(current.path_join("splatviz_msplat_manifest.json"))
		candidates.append(current.path_join("camera_layout.json"))
		var parent := current.get_base_dir()
		if parent == current:
			break
		current = parent
	return candidates

func _m68a_manifest_info_for_path(path: String) -> Dictionary:
	var info := {
		"manifest_path": "",
		"app_release_label": "",
		"export_tag": "",
		"summary": "No manifest found; provenance unknown.",
		"warning": _m68a_release_warning_for_path(path)
	}
	for candidate_any in _m68a_manifest_candidates_for_path(path):
		var candidate := str(candidate_any)
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = parsed as Dictionary
		info["manifest_path"] = candidate
		info["app_release_label"] = str(d.get("app_release_label", d.get("splatviz_version", "")))
		info["export_tag"] = str(d.get("export_tag", ""))
		var parts: Array[String] = []
		if str(info["app_release_label"]) != "":
			parts.append("Manifest release: " + str(info["app_release_label"]))
		if str(info["export_tag"]) != "":
			parts.append("export_tag=" + str(info["export_tag"]))
		parts.append("Manifest: " + candidate.get_file())
		info["summary"] = " · ".join(PackedStringArray(parts))
		var manifest_release := str(info["app_release_label"]).to_lower()
		var manifest_tag := str(info["export_tag"]).to_lower()
		if manifest_release != "" and manifest_release != SPLATVIZ_RELEASE_LABEL.to_lower():
			info["warning"] = "This appears to be an older export/result and may not reflect the current Frame-Safe M68A2 workflow."
		elif manifest_tag != "" and manifest_tag != SPLATVIZ_EXPORT_TAG:
			info["warning"] = "This appears to be an older export/result and may not reflect the current Frame-Safe M68A2 workflow."
		return info
	return info

func _m68a_bounds_summary_lines(label: String, bounds: Dictionary) -> String:
	if bounds.is_empty():
		return label + ": unavailable"
	var min_v: Vector3 = bounds.get("min", Vector3.ZERO)
	var max_v: Vector3 = bounds.get("max", Vector3.ZERO)
	var span_v: Vector3 = bounds.get("span", Vector3.ZERO)
	var center_v: Vector3 = bounds.get("center", Vector3.ZERO)
	return label + "\nmin " + _m68a_vec3_bounds_text(min_v) + "\nmax " + _m68a_vec3_bounds_text(max_v) + "\nsize " + _m68a_vec3_bounds_text(span_v) + "\ncenter " + _m68a_vec3_bounds_text(center_v)

func _m68a_render_manifest_counts(cam_list: Array) -> Dictionary:
	return {
		"subject_qc_counts": _m67h_qc_counts(cam_list),
		"volume_qc_counts": _m67h_volume_qc_counts(cam_list)
	}

func _m68a3_default_camera_labels_36() -> Array[String]:
	return [
		"AA", "AB", "AC", "AD",
		"BA", "BB", "BC", "BD",
		"CA", "CB", "CC", "CD",
		"DA", "DB", "DC", "DD",
		"EA", "EB", "EC", "ED",
		"FA", "FB", "FC", "FD",
		"GA", "GB", "GC", "GD",
		"HA", "HB", "HC", "HD",
		"IA", "IB", "IC", "ID"
	]

func _m68a3_custom_camera_labels() -> Array[String]:
	var out: Array[String] = []
	for raw in report_custom_camera_labels.split(","):
		var trimmed := raw.strip_edges()
		if trimmed != "":
			out.append(trimmed)
	return out

func _m68a3_current_camera_labels(count: int) -> Array[String]:
	if report_camera_label_scheme == "Custom comma-separated labels":
		var custom = _m68a3_custom_camera_labels()
		if custom.size() == count:
			return custom
	if report_camera_label_scheme == "AA-ID 36 Camera Grid" and count == 36:
		return _m68a3_default_camera_labels_36()
	var out: Array[String] = []
	for i in range(count):
		out.append("C%02d" % (i + 1))
	return out

func _m68a3_camera_label_for(index: int, internal_id: String) -> String:
	var labels = _m68a3_current_camera_labels(cameras.size())
	if index >= 0 and index < labels.size():
		return labels[index]
	return internal_id

func _m68a3_camera_label_warning(count: int) -> String:
	if report_camera_label_scheme != "Custom comma-separated labels":
		return ""
	var custom = _m68a3_custom_camera_labels()
	if custom.size() == count:
		return ""
	return "Custom camera labels did not match the camera count; the report fell back to the safe default label scheme."

func _m68a3_apply_report_settings_from_ui() -> void:
	if settings_capture_specs_edit != null:
		report_capture_specs = settings_capture_specs_edit.text.strip_edges()
	if settings_stage_specs_edit != null:
		report_stage_specs = settings_stage_specs_edit.text.strip_edges()
	if settings_performer_specs_edit != null:
		report_performer_specs = settings_performer_specs_edit.text.strip_edges()
	if settings_stage_name_edit != null:
		report_stage_name = settings_stage_name_edit.text.strip_edges()
	if settings_floor_type_edit != null:
		report_floor_type = settings_floor_type_edit.text.strip_edges()
	if settings_build_mode_option != null and settings_build_mode_option.selected >= 0:
		installation_mode = settings_build_mode_option.get_item_text(settings_build_mode_option.selected)
	if settings_label_scheme_option != null and settings_label_scheme_option.selected >= 0:
		report_camera_label_scheme = settings_label_scheme_option.get_item_text(settings_label_scheme_option.selected)
	if settings_custom_labels_edit != null:
		report_custom_camera_labels = settings_custom_labels_edit.text.strip_edges()
	if settings_preview_background_option != null and settings_preview_background_option.selected >= 0:
		report_preview_background = settings_preview_background_option.get_item_text(settings_preview_background_option.selected)
	if settings_height_m_edit != null:
		var parsed = settings_height_m_edit.text.strip_edges().to_float()
		if parsed > 0.01:
			report_performer_height_m = parsed
			report_performer_height_source = "user"
	if settings_height_scale_toggle != null:
		report_height_scale_enabled = settings_height_scale_toggle.button_pressed
	if status_label != null:
		status_label.text = "Report settings updated."

func _m68a3_sync_report_settings_ui() -> void:
	if settings_capture_specs_edit != null:
		settings_capture_specs_edit.text = report_capture_specs
	if settings_stage_specs_edit != null:
		settings_stage_specs_edit.text = report_stage_specs
	if settings_performer_specs_edit != null:
		settings_performer_specs_edit.text = report_performer_specs
	if settings_stage_name_edit != null:
		settings_stage_name_edit.text = report_stage_name
	if settings_floor_type_edit != null:
		settings_floor_type_edit.text = report_floor_type
	if settings_custom_labels_edit != null:
		settings_custom_labels_edit.text = report_custom_camera_labels
	if settings_height_m_edit != null:
		settings_height_m_edit.text = _m67g_num(report_performer_height_m, 2)
	if settings_height_scale_toggle != null:
		settings_height_scale_toggle.button_pressed = report_height_scale_enabled

func _m68a3_settings_add_row(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(220, 0)
	hb.add_child(lbl)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(control)
	parent.add_child(hb)

func _viewport_hit(p: Vector2) -> bool:
	var s = get_viewport().get_visible_rect().size
	return p.x > _m67c_left_panel_width() and p.x < s.x - _right_panel_width() and p.y > TOP_BAR_H and p.y < s.y - 8

func _process_keyboard(delta: float) -> void:
	var speed = max(2.0, distance * 0.4) * delta
	var basis = orbit_camera.global_transform.basis
	var right = basis.x.normalized()
	var forward = -basis.z.normalized()
	forward.y = 0
	forward = forward.normalized()
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pivot += forward * speed
		_update_orbit_camera()
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pivot -= forward * speed
		_update_orbit_camera()
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pivot -= right * speed
		_update_orbit_camera()
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pivot += right * speed
		_update_orbit_camera()
	if Input.is_key_pressed(KEY_Q):
		pivot.y -= speed
		_update_orbit_camera()
	if Input.is_key_pressed(KEY_E):
		pivot.y += speed
		_update_orbit_camera()

func _pan_view(delta: Vector2) -> void:
	var basis = orbit_camera.global_transform.basis
	var right = basis.x.normalized()
	var up = basis.y.normalized()
	var scale = distance * 0.0017
	pivot += (-right * delta.x + up * delta.y) * scale
	_update_orbit_camera()

func _update_orbit_camera() -> void:
	if orbit_camera == null:
		return
	# M66D orbit FOV reset: Camera POV owns capture FOV; all orbit modes use validation FOV.
	if mode != "Camera POV":
		orbit_camera.keep_aspect = Camera3D.KEEP_HEIGHT
		orbit_camera.fov = 45.0
	var cp = cos(pitch)
	var pos = pivot + Vector3(sin(yaw) * cp, -sin(pitch), cos(yaw) * cp) * distance
	orbit_camera.global_position = pos
	orbit_camera.look_at(pivot, Vector3.UP)
	_update_status_nav()

func _update_status_nav() -> void:
	if status_label:
		status_label.text = "Viewport: pinch/wheel zoom · two-finger drag pan · left drag orbit · Q/E vertical · F frame · R reset · H legend."

func _build_materials() -> void:
	mat_floor = _mat(Color(0.035, 0.11, 0.12, 1.0), false)
	mat_grid = _mat(Color(0.08, 0.32, 0.36, 0.55), true)
	mat_truss = _mat(Color(1.0, 0.66, 0.12, 0.86), true)
	mat_stand = _mat(Color(1.0, 0.65, 0.12, 1.0), false)
	mat_camera_body = _mat(Color(0.84, 0.86, 0.78, 1.0), false)
	mat_camera_lens = _mat(Color(0.0, 0.08, 0.16, 1.0), false)
	mat_camera_selected = _mat(Color(0.20, 0.95, 0.50, 1.0), false)
	mat_body = _mat(Color(0.92, 0.94, 0.9, 1.0), false)
	mat_focus_box = _mat(Color(0.2, 0.65, 1.0, 0.020), true)
	mat_frustum_faint = _mat(Color(0.25, 0.9, 0.5, 0.045), true)
	mat_selected = _mat(Color(1.0, 0.12, 0.85, 0.085), true)
	mat_prev = _mat(Color(0.0, 0.75, 1.0, 0.065), true)
	mat_next = _mat(Color(1.0, 0.62, 0.0, 0.065), true)
	mat_weak_line = _mat(Color(1.0, 1.0, 1.0, 0.85), true)
	mat_focus_too_near = _mat(Color(1.0, 0.34, 0.08, 0.035), true)
	mat_focus_accept = _mat(Color(1.0, 0.80, 0.08, 0.032), true)
	mat_focus_critical = _mat(Color(0.25, 1.0, 0.42, 0.045), true)
	# M6.5A: visible unshaded point material for imported Msplat/PLY previews.
	splat_point_material = _mat(Color(0.85, 1.0, 0.92, 1.0), false)

func _mat(color: Color, transparent: bool) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	m.metallic = 0.0
	if transparent or color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Opaque-only depth draw keeps diagnostic volumes readable without making
		# every layer blast through every other layer.
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _build_world() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.01, 0.035, 0.04)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.48, 0.48)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)

	var light = DirectionalLight3D.new()
	light.light_energy = 1.2
	light.rotation_degrees = Vector3(-55, -35, 0)
	add_child(light)

	orbit_camera = Camera3D.new()
	orbit_camera.name = "OrbitCamera"
	orbit_camera.fov = 45.0
	orbit_camera.current = true
	add_child(orbit_camera)

	stage_root = Node3D.new()
	stage_root.name = "StageHelperRoot"
	add_child(stage_root)
	camera_root = Node3D.new()
	camera_root.name = "CameraRigRoot"
	add_child(camera_root)
	overlay_root = Node3D.new()
	overlay_root.name = "DiagnosticOverlayRoot"
	add_child(overlay_root)
	rig_root = Node3D.new()
	rig_root.name = "RigAssetRoot"
	add_child(rig_root)
	performer_root = Node3D.new()
	performer_root.name = "PerformerRoot"
	add_child(performer_root)
	splat_root = Node3D.new()
	splat_root.name = "MsplatResultRoot"
	add_child(splat_root)

	_build_stage_floor()
	_build_height_scale()
	_build_rig_assets()
	_build_performer()
	_build_focus_envelope()

func _build_stage_floor() -> void:
	var floor = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(STAGE_W_M, STAGE_D_M)
	floor.mesh = plane
	floor.material_override = mat_floor
	floor.name = "NOZ Stage #1 floor 59x57ft"
	stage_root.add_child(floor)

	var step = 1.0
	var x = -STAGE_W_M / 2.0
	while x <= STAGE_W_M / 2.0:
		_add_box(Vector3(x, 0.012, 0), Vector3(0.012, 0.012, STAGE_D_M), mat_grid, stage_root, "stage grid –")
		x += step
	var z = -STAGE_D_M / 2.0
	while z <= STAGE_D_M / 2.0:
		_add_box(Vector3(0, 0.014, z), Vector3(STAGE_W_M, 0.012, 0.012), mat_grid, stage_root, "stage grid z")
		z += step

	_add_box(Vector3(-STAGE_W_M/2.0, 0.04, 0), Vector3(0.045, 0.045, STAGE_D_M), mat_grid, stage_root, "stage boundary")
	_add_box(Vector3(STAGE_W_M/2.0, 0.04, 0), Vector3(0.045, 0.045, STAGE_D_M), mat_grid, stage_root, "stage boundary")
	_add_box(Vector3(0, 0.04, -STAGE_D_M/2.0), Vector3(STAGE_W_M, 0.045, 0.045), mat_grid, stage_root, "stage boundary")
	_add_box(Vector3(0, 0.04, STAGE_D_M/2.0), Vector3(STAGE_W_M, 0.045, 0.045), mat_grid, stage_root, "stage boundary")

func _build_height_scale() -> void:
	height_scale_root = Node3D.new()
	height_scale_root.name = "Performer Height Scale"
	stage_root.add_child(height_scale_root)
	var origin = Vector3(-0.82, 0.0, 0.62)
	_add_box(origin + Vector3(0.0, 1.20, 0.0), Vector3(0.035, 2.40, 0.035), mat_truss, height_scale_root, "height scale mast")
	_add_box(origin + Vector3(0.0, 0.03, 0.0), Vector3(0.34, 0.06, 0.34), mat_truss, height_scale_root, "height scale base")
	for i in range(11):
		var meters = 0.25 * float(i)
		var tick_w = 0.30 if i % 4 == 0 else (0.22 if i % 2 == 0 else 0.15)
		_add_box(origin + Vector3(0.0, meters, 0.0), Vector3(tick_w, 0.018, 0.018), mat_truss, height_scale_root, "height scale tick %.2fm" % meters)
		if i % 2 == 0:
			var label = Label3D.new()
			label.position = origin + Vector3(-0.96, meters + 0.02, 0.0)
			label.font_size = 22
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.modulate = Color(1.0, 0.94, 0.78, 0.95)
			label.text = "%.2fm / %.1fft" % [meters, meters / FT_TO_M]
			height_scale_root.add_child(label)
	var title = Label3D.new()
	title.position = origin + Vector3(-0.52, ROBOT_HEIGHT_M + 0.12, 0.10)
	title.font_size = 26
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(1.0, 0.96, 0.82, 0.98)
	title.text = "Height scale"
	height_scale_root.add_child(title)

func _build_rig_assets() -> void:
	# M67C: orange poles/rails/truss helpers are disabled by default.
	return

func _add_stand(pos: Vector3, h: float, label: String) -> void:
	var pole = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.035
	mesh.height = h
	pole.mesh = mesh
	pole.material_override = mat_stand
	pole.position = pos + Vector3(0, h/2.0, 0)
	pole.name = label
	rig_root.add_child(pole)
	var base = MeshInstance3D.new()
	var sm = CylinderMesh.new()
	sm.top_radius = 0.12
	sm.bottom_radius = 0.12
	sm.height = 0.025
	base.mesh = sm
	base.material_override = mat_stand
	base.position = pos + Vector3(0, 0.02, 0)
	base.name = label + " base"
	rig_root.add_child(base)

func _build_performer() -> void:
	var loaded = _load_robot_asset()
	if not loaded:
		_build_fallback_robot_proxy()
	_add_sphere(TARGET, 0.045, _mat(Color(0.45, 0.95, 1.0, 1.0), false), performer_root, "eyes / focus target")

func _load_robot_asset() -> bool:
	# M2.9: load the raw GLB at runtime using GLTFDocument instead of
	# ResourceLoader.load(..., "PackedScene"), which fails before Godot has
	# created editor import metadata for a raw .glb.
	var robot_path = "res://assets/models/SplatVizRobot.glb"
	if not FileAccess.file_exists(robot_path):
		push_warning("SplatVizRobot.glb missing at " + robot_path + "; using fallback proxy.")
		return false

	var gltf_doc = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	var err = gltf_doc.append_from_file(robot_path, gltf_state)
	if err == OK:
		var generated = gltf_doc.generate_scene(gltf_state)
		if generated != null and generated is Node3D:
			robot_model_root = generated as Node3D
			robot_model_root.name = "SplatVizRobot_5ft11_actual_glb_runtime"
			performer_root.add_child(robot_model_root)
			_fit_robot_to_height(robot_model_root, ROBOT_HEIGHT_M)
			if status_label != null:
				status_label.text = "Loaded SplatVizRobot.glb with GLTFDocument runtime importer."
			return true
		push_warning("SplatVizRobot.glb parsed but generated scene was null; using fallback proxy.")
	else:
		push_warning("SplatVizRobot.glb runtime GLTF import failed err=" + str(err) + "; using fallback proxy.")

	# Last fallback: ResourceLoader can work if editor import metadata exists.
	var res = ResourceLoader.load(robot_path)
	if res != null and res is PackedScene:
		robot_model_root = (res as PackedScene).instantiate() as Node3D
		if robot_model_root != null:
			robot_model_root.name = "SplatVizRobot_5ft11_actual_glb_imported"
			performer_root.add_child(robot_model_root)
			_fit_robot_to_height(robot_model_root, ROBOT_HEIGHT_M)
			return true
	return false

func _build_fallback_robot_proxy() -> void:
	# Detailed hard-surface fallback only used if SplatVizRobot.glb fails to import.
	var white = _mat(Color(0.92, 0.96, 0.94, 1.0), false)
	var blue = _mat(Color(0.08, 0.42, 1.0, 1.0), false)
	var black = _mat(Color(0.015, 0.02, 0.025, 1.0), false)
	_add_box(Vector3(0, 1.02, 0), Vector3(0.44, 0.70, 0.25), white, performer_root, "fallback robot torso")
	_add_box(Vector3(0, 1.18, -0.135), Vector3(0.34, 0.24, 0.025), black, performer_root, "fallback robot chest black panel")
	_add_sphere(Vector3(0, 1.56, 0), 0.20, white, performer_root, "fallback robot head")
	_add_box(Vector3(0, 1.56, -0.18), Vector3(0.28, 0.10, 0.025), black, performer_root, "fallback robot blue visor base")
	_add_sphere(Vector3(-0.07, 1.57, -0.202), 0.025, blue, performer_root, "fallback robot left eye")
	_add_sphere(Vector3(0.07, 1.57, -0.202), 0.025, blue, performer_root, "fallback robot right eye")
	_add_sphere(Vector3(0, 1.10, -0.155), 0.055, blue, performer_root, "fallback SplatViz chest mark")
	_add_box(Vector3(-0.22, 0.43, 0), Vector3(0.13, 0.78, 0.13), white, performer_root, "fallback left leg")
	_add_box(Vector3(0.22, 0.43, 0), Vector3(0.13, 0.78, 0.13), white, performer_root, "fallback right leg")
	_add_box(Vector3(-0.23, 0.04, -0.04), Vector3(0.24, 0.08, 0.34), white, performer_root, "fallback left foot")
	_add_box(Vector3(0.23, 0.04, -0.04), Vector3(0.24, 0.08, 0.34), white, performer_root, "fallback right foot")
	_add_box(Vector3(-0.43, 1.12, 0), Vector3(0.11, 0.62, 0.11), white, performer_root, "fallback left arm")
	_add_box(Vector3(0.43, 1.12, 0), Vector3(0.11, 0.62, 0.11), white, performer_root, "fallback right arm")
	_add_sphere(Vector3(-0.43, 0.74, -0.01), 0.07, black, performer_root, "fallback left hand")
	_add_sphere(Vector3(0.43, 0.74, -0.01), 0.07, black, performer_root, "fallback right hand")

func _fit_robot_to_height(root: Node3D, target_height_m: float) -> void:
	var aabb = _global_aabb_for_node(root)
	var height = max(0.001, aabb.size.y)
	var factor = target_height_m / height
	root.scale *= factor
	# After scaling, recenter on stage origin and place feet on floor.
	aabb = _global_aabb_for_node(root)
	var center_x = aabb.position.x + aabb.size.x * 0.5
	var center_z = aabb.position.z + aabb.size.z * 0.5
	root.global_position += Vector3(-center_x, -aabb.position.y, -center_z)

func _global_aabb_for_node(root: Node) -> AABB:
	var bounds = [
		Vector3(999999.0, 999999.0, 999999.0),
		Vector3(-999999.0, -999999.0, -999999.0),
		false
	]
	_collect_mesh_bounds(root, bounds)
	if not bool(bounds[2]):
		return AABB(Vector3(-0.25, 0.0, -0.25), Vector3(0.5, ROBOT_HEIGHT_M, 0.5))
	var min_v: Vector3 = bounds[0]
	var max_v: Vector3 = bounds[1]
	return AABB(min_v, max_v - min_v)

func _collect_mesh_bounds(node: Node, bounds: Array) -> void:
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		if mi.mesh != null:
			var box = mi.mesh.get_aabb()
			var corners = [
				box.position,
				box.position + Vector3(box.size.x, 0, 0),
				box.position + Vector3(0, box.size.y, 0),
				box.position + Vector3(0, 0, box.size.z),
				box.position + Vector3(box.size.x, box.size.y, 0),
				box.position + Vector3(box.size.x, 0, box.size.z),
				box.position + Vector3(0, box.size.y, box.size.z),
				box.position + box.size
			]
			var min_v: Vector3 = bounds[0]
			var max_v: Vector3 = bounds[1]
			for corner in corners:
				var gp = mi.global_transform * corner
				min_v.x = min(min_v.x, gp.x)
				min_v.y = min(min_v.y, gp.y)
				min_v.z = min(min_v.z, gp.z)
				max_v.x = max(max_v.x, gp.x)
				max_v.y = max(max_v.y, gp.y)
				max_v.z = max(max_v.z, gp.z)
			bounds[0] = min_v
			bounds[1] = max_v
			bounds[2] = true
	for child in node.get_children():
		_collect_mesh_bounds(child, bounds)

func _build_focus_envelope() -> void:
	focus_envelope_root = Node3D.new()
	focus_envelope_root.name = "PerformerFocusEnvelopeRoot"
	add_child(focus_envelope_root)
	var box = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(1.2, 1.85, 1.35)
	box.mesh = bm
	box.material_override = mat_focus_box
	box.position = Vector3(0, 0.95, 0)
	box.name = "blue performer focus envelope: solid occupancy volume"
	focus_envelope_root.add_child(box)
	var line_pts = _box_lines(Vector3(0,0.95,0), Vector3(1.2,1.85,1.35))
	var wire = MeshInstance3D.new()
	wire.mesh = _line_mesh(line_pts)
	wire.material_override = _mat(Color(0.25, 0.65, 1.0, 1.0), true)
	wire.name = "blue performer focus envelope wire"
	focus_envelope_root.add_child(wire)

func _m67h_vec3_to_array(v: Vector3) -> Array:
	return CaptureMath.vec3_to_array(v)

func _m67h_variant_to_vec3(v: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	return CaptureMath.variant_to_vec3(v, fallback)

func _m67h_subject_frame_safety() -> Dictionary:
	return {
		"bottom_target_margin_pct": M67H_SUBJECT_BOTTOM_TARGET_MARGIN_PCT,
		"side_target_margin_pct": M67H_SUBJECT_SIDE_TARGET_MARGIN_PCT,
		"top_min_margin_pct": M67H_SUBJECT_TOP_MIN_MARGIN_PCT,
		"hard_fail_margin_pct": M67H_SUBJECT_HARD_FAIL_MARGIN_PCT
	}

func _m67h_volume_frame_safety() -> Dictionary:
	return {
		"warning_margin_pct": M67H_VOLUME_WARNING_MARGIN_PCT
	}

func _m67h_frame_safety() -> Dictionary:
	return _m67h_subject_frame_safety()

func _m67h_capture_volume() -> Dictionary:
	var margin := M67H_CAPTURE_VOLUME_MOTION_MARGIN_M
	var half = M67H_CAPTURE_VOLUME_BASE_SIZE_M * 0.5
	var min_v := Vector3(
		M67H_CAPTURE_VOLUME_BASE_CENTER_M.x - half.x - margin.x,
		0.0,
		M67H_CAPTURE_VOLUME_BASE_CENTER_M.z - half.z - margin.z
	)
	var max_v := Vector3(
		M67H_CAPTURE_VOLUME_BASE_CENTER_M.x + half.x + margin.x,
		M67H_CAPTURE_VOLUME_BASE_CENTER_M.y + half.y + margin.y,
		M67H_CAPTURE_VOLUME_BASE_CENTER_M.z + half.z + margin.z
	)
	var size_v := max_v - min_v
	var center_v := min_v + size_v * 0.5
	return {
		"center": center_v,
		"size": size_v,
		"min": min_v,
		"max": max_v,
		"motion_margin": margin,
		"floor_included": true
	}

func _m67h_bounds_points(bounds: Dictionary) -> Array:
	var min_v: Vector3 = bounds.get("min", Vector3.ZERO)
	var max_v: Vector3 = bounds.get("max", Vector3.ZERO)
	return [
		Vector3(min_v.x, min_v.y, min_v.z),
		Vector3(max_v.x, min_v.y, min_v.z),
		Vector3(min_v.x, max_v.y, min_v.z),
		Vector3(max_v.x, max_v.y, min_v.z),
		Vector3(min_v.x, min_v.y, max_v.z),
		Vector3(max_v.x, min_v.y, max_v.z),
		Vector3(min_v.x, max_v.y, max_v.z),
		Vector3(max_v.x, max_v.y, max_v.z)
	]

func _m67h_capture_volume_points(volume: Dictionary) -> Array:
	return _m67h_bounds_points(volume)

func _m67h_capture_subject_bounds() -> Dictionary:
	var source_node: Node = robot_model_root if robot_model_root != null else performer_root
	var estimated := robot_model_root == null
	var source_name := "estimated_reference_subject" if estimated else "robot_mesh_aabb"
	var aabb := AABB(Vector3(-0.28, 0.0, -0.22), Vector3(0.56, ROBOT_HEIGHT_M, 0.44))
	if source_node != null:
		aabb = _global_aabb_for_node(source_node)
	var padding := M67H_SUBJECT_BOUNDS_PADDING_M
	var min_v := aabb.position - Vector3(padding.x, 0.0, padding.z)
	min_v.y = max(0.0, aabb.position.y - padding.y)
	var max_v := aabb.position + aabb.size + padding
	var size_v := max_v - min_v
	var center_v := min_v + size_v * 0.5
	return {
		"center": center_v,
		"size": size_v,
		"min": min_v,
		"max": max_v,
		"padding": padding,
		"source": source_name,
		"estimated": estimated,
		"floor_included": true
	}

func _m67h_camera_focus_target(_c: Dictionary) -> Vector3:
	return TARGET

func _m67h_camera_aim_target(c: Dictionary) -> Vector3:
	if c.has("aim_target_m"):
		return _m67h_variant_to_vec3(c["aim_target_m"], TARGET)
	return _m67h_capture_subject_bounds().get("center", TARGET)

func _m67h_capture_axes_from_target(c: Dictionary, aim_target: Vector3) -> Dictionary:
	return CaptureMath.capture_axes_from_target(c, aim_target)

func _m67h_project_bounds(c: Dictionary, size: Vector2i, bounds: Dictionary, aim_target: Vector3) -> Dictionary:
	var axes = _m67h_capture_axes_from_target(c, aim_target)
	var pos: Vector3 = axes["position"] as Vector3
	var forward: Vector3 = axes["forward"] as Vector3
	var right: Vector3 = axes["right"] as Vector3
	var up: Vector3 = axes["up"] as Vector3
	var tan_half_v = tan(deg_to_rad(_m66d_capture_vfov_deg(c)) * 0.5)
	var aspect = float(size.x) / max(1.0, float(size.y))
	var tan_half_h = tan_half_v * aspect
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var behind_points := 0
	for point_var in _m67h_bounds_points(bounds):
		var point: Vector3 = point_var as Vector3
		var rel = point - pos
		var depth = rel.dot(forward)
		if depth <= 0.001:
			behind_points += 1
			continue
		var nx = rel.dot(right) / max(0.0001, depth * tan_half_h)
		var ny = rel.dot(up) / max(0.0001, depth * tan_half_v)
		min_x = min(min_x, nx)
		max_x = max(max_x, nx)
		min_y = min(min_y, ny)
		max_y = max(max_y, ny)
	if behind_points > 0:
		return {
			"aim_target": aim_target,
			"fits_inside_frame": false,
			"behind_points": behind_points,
			"margins": {"left_pct": -100.0, "right_pct": -100.0, "top_pct": -100.0, "bottom_pct": -100.0},
			"projected_coverage_pct": 999.0,
			"projected_bounds_ndc": {"min_x": -2.0, "max_x": 2.0, "min_y": -2.0, "max_y": 2.0}
		}
	var left_pct = (min_x + 1.0) * 50.0
	var right_pct = (1.0 - max_x) * 50.0
	var bottom_pct = (min_y + 1.0) * 50.0
	var top_pct = (1.0 - max_y) * 50.0
	var width_pct = max(0.0, (max_x - min_x) * 50.0)
	var height_pct = max(0.0, (max_y - min_y) * 50.0)
	return {
		"aim_target": aim_target,
		"fits_inside_frame": min_x >= -1.0 and max_x <= 1.0 and min_y >= -1.0 and max_y <= 1.0,
		"behind_points": 0,
		"margins": {
			"left_pct": left_pct,
			"right_pct": right_pct,
			"top_pct": top_pct,
			"bottom_pct": bottom_pct
		},
		"projected_coverage_pct": clamp((width_pct / 100.0) * (height_pct / 100.0) * 100.0, 0.0, 999.0),
		"projected_bounds_ndc": {"min_x": min_x, "max_x": max_x, "min_y": min_y, "max_y": max_y}
	}

func _m67h_project_capture_volume(c: Dictionary, size: Vector2i, volume: Dictionary, aim_target: Vector3) -> Dictionary:
	return _m67h_project_bounds(c, size, volume, aim_target)

func _m67h_candidate_score(candidate: Dictionary) -> Array:
	var margins: Dictionary = candidate.get("margins", {})
	var bottom = float(margins.get("bottom_pct", -999.0))
	var side = min(float(margins.get("left_pct", -999.0)), float(margins.get("right_pct", -999.0)))
	var top = float(margins.get("top_pct", -999.0))
	return [bottom, side, -top]

func _m67h_candidate_better(a: Dictionary, b: Dictionary) -> bool:
	if b.is_empty():
		return true
	var sa = _m67h_candidate_score(a)
	var sb = _m67h_candidate_score(b)
	for i in range(sa.size()):
		if float(sa[i]) > float(sb[i]) + 0.0001:
			return true
		if float(sa[i]) < float(sb[i]) - 0.0001:
			return false
	return false

func _m67h_classify_subject_fit(candidate: Dictionary, safety: Dictionary) -> String:
	var margins: Dictionary = candidate.get("margins", {})
	var fits_inside = bool(candidate.get("fits_inside_frame", false))
	if not fits_inside:
		return "INVALID"
	var left = float(margins.get("left_pct", -999.0))
	var right = float(margins.get("right_pct", -999.0))
	var top = float(margins.get("top_pct", -999.0))
	var bottom = float(margins.get("bottom_pct", -999.0))
	var side_min = min(left, right)
	if side_min >= float(safety.get("side_target_margin_pct", 0.0)) \
		and bottom >= float(safety.get("bottom_target_margin_pct", 0.0)) \
		and top >= float(safety.get("top_min_margin_pct", 0.0)):
		return "PASS"
	if min(min(left, right), min(top, bottom)) >= float(safety.get("hard_fail_margin_pct", 0.0)):
		return "WARNING"
	return "FAIL"

func _m67h_classify_volume_fit(candidate: Dictionary, safety: Dictionary) -> String:
	if not bool(candidate.get("fits_inside_frame", false)):
		return "OUTSIDE"
	var margins: Dictionary = candidate.get("margins", {})
	var margin_floor = min(
		min(float(margins.get("left_pct", -999.0)), float(margins.get("right_pct", -999.0))),
		min(float(margins.get("top_pct", -999.0)), float(margins.get("bottom_pct", -999.0)))
	)
	return "PASS" if margin_floor >= float(safety.get("warning_margin_pct", 0.0)) else "WARNING"

func _m67h_subject_frame_qc_reason(subject_status: String, volume_status: String, fits_inside: bool) -> String:
	if subject_status == "PASS":
		if volume_status == "PASS":
			return "The full subject fits with safe training margins."
		if volume_status == "WARNING":
			return "The full subject fits for training, but the wider planning volume runs tight in frame."
		return "The full subject fits for training, but the wider planning volume extends outside the frame."
	if subject_status == "WARNING":
		if fits_inside:
			return "The full subject stays in frame, but one or more preferred training margins are tighter than target."
		return "The subject is near frame limits and needs a physical correction before capture."
	if subject_status == "FAIL":
		return "The subject fits only at hard-limit margins. Treat this camera as diagnostic until the layout is corrected."
	return "The subject cannot fit safely inside the current frame with this fixed camera position and lens."

func _m67h_support_bucket(mount: String) -> String:
	var lower = mount.to_lower()
	if lower.find("tripod") >= 0:
		return "Tripods"
	if lower.find("stand") >= 0 or lower.find("tower") >= 0:
		return "Stands"
	if lower.find("truss") >= 0:
		return "Truss"
	return installation_mode

func _m67h_installation_mode() -> String:
	var seen: Dictionary = {}
	for c_var in cameras:
		var c: Dictionary = c_var as Dictionary
		seen[_m67h_support_bucket(str(c.get("mount", "")))] = true
	if seen.size() == 1:
		return str(seen.keys()[0])
	return "Mixed"

func _m67h_frame_qc_recommendation(c: Dictionary, margins: Dictionary, status: String, volume_status: String = "PASS") -> String:
	if status == "PASS" and volume_status == "PASS":
		return "Install to the solved aim target and preserve the full frame."
	if status == "PASS" and volume_status == "WARNING":
		return "Training-safe for the subject. Keep the solved aim target, and treat the wider planning volume as tight."
	if status == "PASS" and volume_status == "OUTSIDE":
		return "Training-safe for the subject. The wider planning volume extends outside the frame, so use this view only if that is acceptable for the shot plan."
	var pos: Vector3 = c.get("position", Vector3.ZERO)
	var subject = _m67h_capture_subject_bounds()
	var center: Vector3 = subject.get("center", TARGET)
	var left = float(margins.get("left_pct", 0.0))
	var right = float(margins.get("right_pct", 0.0))
	var bottom = float(margins.get("bottom_pct", 0.0))
	var actions: Array[String] = []
	if min(left, right) < M67H_SUBJECT_SIDE_TARGET_MARGIN_PCT:
		actions.append("move camera back")
		actions.append("use a wider lens")
	if bottom < M67H_SUBJECT_BOTTOM_TARGET_MARGIN_PCT:
		actions.append("raise mount" if pos.y < center.y else "lower mount")
	if status == "WARNING":
		actions.append("adjust pan/tilt to match the solved framing target")
	if status == "INVALID":
		actions.append("change support placement")
	var dedup: Array[String] = []
	for action in actions:
		if not dedup.has(action):
			dedup.append(action)
	if dedup.is_empty():
		dedup.append("adjust pan/tilt to match the solved framing target")
	var support = _m67h_support_bucket(str(c.get("mount", "")))
	if support == "Truss":
		return "Recommended correction: adjust pan/tilt first, then shift the truss mount location, then change radius, lens, or support if needed."
	if support == "Stands":
		return "Recommended correction: adjust aim first, then stand height, then stand floor radius or stand placement if the subject still clips."
	if support == "Tripods":
		return "Recommended correction: adjust aim first, then tripod height, tripod distance, and tripod footprint clearance if the subject still clips."
	if status == "INVALID":
		dedup.append("change support placement")
	return "Recommended correction: " + ", ".join(PackedStringArray(dedup)) + "."

func _m67h_solve_frame_safe_aim_for_bounds(c: Dictionary, size: Vector2i, bounds: Dictionary, safety: Dictionary) -> Dictionary:
	var center: Vector3 = bounds.get("center", TARGET)
	var min_v: Vector3 = bounds.get("min", center)
	var max_v: Vector3 = bounds.get("max", center)
	var size_v: Vector3 = bounds.get("size", Vector3.ONE)
	var solve_top_y = max_v.y + size_v.y * 0.24
	var solve_bottom_y = max(0.0, min_v.y - size_v.y * 0.06)
	var best_safe: Dictionary = {}
	var best_inside: Dictionary = {}
	var best_any: Dictionary = {}
	for i in range(65):
		var t = float(i) / 64.0
		var aim_y = lerpf(solve_top_y, solve_bottom_y, t)
		var candidate = _m67h_project_bounds(c, size, bounds, Vector3(center.x, aim_y, center.z))
		var margins: Dictionary = candidate.get("margins", {})
		var left = float(margins.get("left_pct", -999.0))
		var right = float(margins.get("right_pct", -999.0))
		var top = float(margins.get("top_pct", -999.0))
		var bottom = float(margins.get("bottom_pct", -999.0))
		var side_min = min(left, right)
		if _m67h_candidate_better(candidate, best_any):
			best_any = candidate
		if bool(candidate.get("fits_inside_frame", false)) and _m67h_candidate_better(candidate, best_inside):
			best_inside = candidate
		if bool(candidate.get("fits_inside_frame", false)) \
			and side_min >= float(safety["side_target_margin_pct"]) \
			and bottom >= float(safety["bottom_target_margin_pct"]) \
			and top >= float(safety["top_min_margin_pct"]) \
			and _m67h_candidate_better(candidate, best_safe):
			best_safe = candidate
	return best_safe if not best_safe.is_empty() else (best_inside if not best_inside.is_empty() else best_any)

func _m67h_solve_frame_safe_aim(c: Dictionary, size: Vector2i = CLEAN_RENDER_SIZE) -> Dictionary:
	var subject = _m67h_capture_subject_bounds()
	var volume = _m67h_capture_volume()
	var subject_safety = _m67h_subject_frame_safety()
	var volume_safety = _m67h_volume_frame_safety()
	var chosen = _m67h_solve_frame_safe_aim_for_bounds(c, size, subject, subject_safety)
	var chosen_margins: Dictionary = chosen.get("margins", {})
	var subject_status = _m67h_classify_subject_fit(chosen, subject_safety)
	var volume_projection = _m67h_project_bounds(c, size, volume, chosen.get("aim_target", subject.get("center", TARGET)))
	var volume_status = _m67h_classify_volume_fit(volume_projection, volume_safety)
	var reason = _m67h_subject_frame_qc_reason(subject_status, volume_status, bool(chosen.get("fits_inside_frame", false)))
	var recommendation = _m67h_frame_qc_recommendation(c, chosen_margins, subject_status, volume_status)
	return {
		"aim_target": chosen.get("aim_target", subject.get("center", TARGET)),
		"focus_target": _m67h_camera_focus_target(c),
		"capture_subject_bounds": subject,
		"capture_volume": volume,
		"subject_frame_safety": subject_safety,
		"volume_frame_safety": volume_safety,
		"subject_projected_coverage_pct": float(chosen.get("projected_coverage_pct", 0.0)),
		"subject_projected_bounds_ndc": chosen.get("projected_bounds_ndc", {}),
		"subject_fits_inside_frame": bool(chosen.get("fits_inside_frame", false)),
		"subject_status": subject_status,
		"subject_margins": chosen_margins,
		"volume_projected_coverage_pct": float(volume_projection.get("projected_coverage_pct", 0.0)),
		"volume_projected_bounds_ndc": volume_projection.get("projected_bounds_ndc", {}),
		"volume_fits_inside_frame": bool(volume_projection.get("fits_inside_frame", false)),
		"volume_status": volume_status,
		"volume_margins": volume_projection.get("margins", {}),
		"fits_inside_frame": bool(chosen.get("fits_inside_frame", false)),
		"status": subject_status,
		"reason": reason,
		"recommendation": recommendation,
		"margins": chosen_margins,
		"projected_coverage_pct": float(chosen.get("projected_coverage_pct", 0.0)),
		"projected_bounds_ndc": chosen.get("projected_bounds_ndc", {})
	}

func _m67h_camera_layout_metrics(c: Dictionary) -> Dictionary:
	var azimuth = float(c.get("azimuth_deg", 0.0))
	var tier = str(c.get("tier", "mid"))
	var same_tier: Array = []
	for other_var in cameras:
		var other: Dictionary = other_var as Dictionary
		if str(other.get("id", "")) == str(c.get("id", "")):
			continue
		if str(other.get("tier", "")) == tier:
			same_tier.append(float(other.get("azimuth_deg", 0.0)))
	var nearest_gap = 360.0
	for other_az in same_tier:
		var delta = absf(fposmod(azimuth - float(other_az) + 540.0, 360.0) - 180.0)
		nearest_gap = min(nearest_gap, delta)
	var redundancy_warning = nearest_gap < 18.0
	return {
		"nearest_same_tier_azimuth_gap_deg": nearest_gap,
		"redundancy_warning": redundancy_warning,
		"tier": tier
	}

func _m67h_refresh_camera_layout_fields(c: Dictionary) -> Dictionary:
	var pos: Vector3 = c.get("position", Vector3.ZERO)
	var focus_target = _m67h_camera_focus_target(c)
	c["focus_target_m"] = focus_target
	c["focus_m"] = pos.distance_to(focus_target)
	c["px_cm"] = _projected_px_cm(float(c["focus_m"]), bool(c.get("portrait", false)))
	c["azimuth_deg"] = fposmod(rad_to_deg(atan2(pos.z, pos.x)), 360.0)
	var solved = _m67h_solve_frame_safe_aim(c, CLEAN_RENDER_SIZE)
	c["aim_target_m"] = solved.get("aim_target", focus_target)
	c["capture_subject_bounds_m"] = {
		"center_m": _m67h_vec3_to_array((solved.get("capture_subject_bounds", {}) as Dictionary).get("center", Vector3.ZERO)),
		"size_m": _m67h_vec3_to_array((solved.get("capture_subject_bounds", {}) as Dictionary).get("size", Vector3.ZERO)),
		"min_m": _m67h_vec3_to_array((solved.get("capture_subject_bounds", {}) as Dictionary).get("min", Vector3.ZERO)),
		"max_m": _m67h_vec3_to_array((solved.get("capture_subject_bounds", {}) as Dictionary).get("max", Vector3.ZERO)),
		"padding_m": _m67h_vec3_to_array((solved.get("capture_subject_bounds", {}) as Dictionary).get("padding", Vector3.ZERO)),
		"source": str((solved.get("capture_subject_bounds", {}) as Dictionary).get("source", "estimated_reference_subject")),
		"estimated": bool((solved.get("capture_subject_bounds", {}) as Dictionary).get("estimated", true))
	}
	c["capture_volume_bounds_m"] = {
		"center_m": _m67h_vec3_to_array((solved.get("capture_volume", {}) as Dictionary).get("center", Vector3.ZERO)),
		"size_m": _m67h_vec3_to_array((solved.get("capture_volume", {}) as Dictionary).get("size", Vector3.ZERO)),
		"min_m": _m67h_vec3_to_array((solved.get("capture_volume", {}) as Dictionary).get("min", Vector3.ZERO)),
		"max_m": _m67h_vec3_to_array((solved.get("capture_volume", {}) as Dictionary).get("max", Vector3.ZERO)),
		"motion_margin_m": _m67h_vec3_to_array((solved.get("capture_volume", {}) as Dictionary).get("motion_margin", Vector3.ZERO))
	}
	c["subject_frame_qc_status"] = str(solved.get("subject_status", "INVALID"))
	c["subject_frame_qc_reason"] = str(solved.get("reason", ""))
	c["subject_frame_qc_recommendation"] = str(solved.get("recommendation", ""))
	c["subject_frame_qc_margins_pct"] = solved.get("subject_margins", {})
	c["subject_frame_coverage_pct"] = float(solved.get("subject_projected_coverage_pct", 0.0))
	c["subject_frame_qc_projected_bounds_ndc"] = solved.get("subject_projected_bounds_ndc", {})
	c["volume_frame_qc_status"] = str(solved.get("volume_status", "OUTSIDE"))
	c["volume_frame_qc_margins_pct"] = solved.get("volume_margins", {})
	c["volume_frame_coverage_pct"] = float(solved.get("volume_projected_coverage_pct", 0.0))
	c["volume_frame_qc_projected_bounds_ndc"] = solved.get("volume_projected_bounds_ndc", {})
	c["frame_qc_status"] = str(solved.get("subject_status", "INVALID"))
	c["frame_qc_reason"] = str(solved.get("reason", ""))
	c["frame_qc_recommendation"] = str(solved.get("recommendation", ""))
	c["frame_qc_margins"] = solved.get("subject_margins", {})
	c["frame_qc_projected_coverage_pct"] = float(solved.get("subject_projected_coverage_pct", 0.0))
	c["frame_qc_projected_bounds_ndc"] = solved.get("subject_projected_bounds_ndc", {})
	c["layout_metrics"] = _m67h_camera_layout_metrics(c)
	return c

func _m67h_refresh_all_camera_layout_fields() -> void:
	for i in range(cameras.size()):
		cameras[i] = _m67h_refresh_camera_layout_fields(cameras[i])

func _m67h_qc_counts(cam_list: Array = cameras) -> Dictionary:
	var counts := {"PASS": 0, "WARNING": 0, "FAIL": 0, "INVALID": 0}
	for c_var in cam_list:
		var c: Dictionary = c_var as Dictionary
		var status = str(c.get("subject_frame_qc_status", c.get("frame_qc_status", "INVALID")))
		if not counts.has(status):
			counts[status] = 0
		counts[status] = int(counts[status]) + 1
	return counts

func _m67h_volume_qc_counts(cam_list: Array = cameras) -> Dictionary:
	var counts := {"PASS": 0, "WARNING": 0, "OUTSIDE": 0}
	for c_var in cam_list:
		var c: Dictionary = c_var as Dictionary
		var status = str(c.get("volume_frame_qc_status", "OUTSIDE"))
		if not counts.has(status):
			counts[status] = 0
		counts[status] = int(counts[status]) + 1
	return counts

func _m67h_camera_exports_contact_frame(c: Dictionary) -> bool:
	var status = str(c.get("frame_qc_status", "INVALID"))
	return status == "PASS" or status == "WARNING"

func _m67h_camera_requires_diagnostic_thumbnail(c: Dictionary) -> bool:
	var status = str(c.get("frame_qc_status", "INVALID"))
	return status == "FAIL" or status == "INVALID"

func _m67h_export_policy(c: Dictionary) -> String:
	if _m67h_camera_exports_contact_frame(c):
		return "valid_contact_and_training"
	if _m67h_camera_requires_diagnostic_thumbnail(c):
		return "diagnostic_only"
	return "blocked"

func _m67h_exportable_training_cameras(cam_list: Array = cameras) -> Array:
	var exportable: Array = []
	for c_var in cam_list:
		var c: Dictionary = c_var as Dictionary
		if _m67h_camera_exports_contact_frame(c):
			exportable.append(c)
	return exportable

func _m67h_unsafe_training_cameras(cam_list: Array = cameras) -> Array:
	var unsafe: Array = []
	for c_var in cam_list:
		var c: Dictionary = c_var as Dictionary
		if _m67h_camera_requires_diagnostic_thumbnail(c):
			unsafe.append(c)
	return unsafe

func _m67h_camera_list_summary(cam_list: Array) -> String:
	var parts: Array[String] = []
	for c_var in cam_list:
		var c: Dictionary = c_var as Dictionary
		parts.append(str(c.get("id", "")) + " " + str(c.get("frame_qc_status", "INVALID")))
	return ", ".join(PackedStringArray(parts))

func _m67h_prepare_dataset_export_cameras() -> Array:
	_m67h_refresh_all_camera_layout_fields()
	var exportable = _m67h_exportable_training_cameras(cameras)
	var unsafe = _m67h_unsafe_training_cameras(cameras)
	m67h_last_dataset_omitted_camera_ids.clear()
	m67h_last_dataset_unsafe_override_used = false
	if unsafe.is_empty():
		msplat_export_unsafe_override_once = false
		return exportable
	if not msplat_export_unsafe_override_once:
		msplat_export_unsafe_override_once = true
		var message = "Dataset export blocked: " + str(unsafe.size()) + " camera(s) are FAIL/INVALID. Run Export Dataset again to override and export only PASS/WARNING cameras."
		_append_msplat_terminal("$ " + message)
		_append_msplat_terminal("$ Unsafe cameras: " + _m67h_camera_list_summary(unsafe))
		if status_label:
			status_label.text = message
		if msplat_status_label:
			msplat_status_label.text = message
		return []
	msplat_export_unsafe_override_once = false
	m67h_last_dataset_unsafe_override_used = true
	for c_var in unsafe:
		var c: Dictionary = c_var as Dictionary
		m67h_last_dataset_omitted_camera_ids.append(str(c.get("id", "")))
	_append_msplat_terminal("$ Override accepted: exporting only PASS/WARNING training frames.")
	_append_msplat_terminal("$ Omitted FAIL/INVALID cameras: " + ", ".join(PackedStringArray(m67h_last_dataset_omitted_camera_ids)))
	if exportable.is_empty():
		var no_safe = "Dataset export stopped: no PASS/WARNING cameras remain after QC filtering."
		_append_msplat_terminal("$ " + no_safe)
		if status_label:
			status_label.text = no_safe
		if msplat_status_label:
			msplat_status_label.text = no_safe
		return []
	return exportable

func _set_layout(name: String) -> void:
	layout_name = name
	if layout_option != null:
		for i in range(layout_option.item_count):
			if layout_option.get_item_text(i) == layout_name:
				layout_option.select(i)
				break
	for child in camera_root.get_children():
		child.queue_free()
	for child in overlay_root.get_children():
		child.queue_free()
	cameras.clear()
	camera_nodes.clear()
	_build_cameras()
	_m67h_refresh_all_camera_layout_fields()
	for i in range(min(cameras.size(), camera_nodes.size())):
		var node = camera_nodes[i] as Node3D
		if node != null:
			node.look_at(_m67h_camera_aim_target(cameras[i]), Vector3.UP)
	installation_mode = _m67h_installation_mode()
	_rebuild_camera_dropdown()
	selected_index = min(selected_index, max(0, cameras.size() - 1))
	_m66e_refresh_after_camera_change()

func _m67h_is_frame_safe_profile(name: String) -> bool:
	return name.begins_with("Frame-Safe ")

func _m67h_array_profile(name: String) -> Dictionary:
	if name == "Frame-Safe 12-Camera Multi-Tier":
		return {
			"name": name,
			"array_size": 12,
			"tier_count": 3,
			"cameras_per_tier": 4,
			"azimuth_spacing_deg": 90.0,
			"tier_stagger_deg": 30.0,
			"tiers": ["low", "mid", "high"]
		}
	if name == "Frame-Safe 24-Camera Multi-Tier":
		return {
			"name": name,
			"array_size": 24,
			"tier_count": 3,
			"cameras_per_tier": 8,
			"azimuth_spacing_deg": 45.0,
			"tier_stagger_deg": 15.0,
			"tiers": ["low", "mid", "high"]
		}
	if name == "Frame-Safe 36-Camera Multi-Tier":
		return {
			"name": name,
			"array_size": 36,
			"tier_count": 3,
			"cameras_per_tier": 12,
			"azimuth_spacing_deg": 30.0,
			"tier_stagger_deg": 10.0,
			"tiers": ["low", "mid", "high"]
		}
	if name.begins_with("Lean"):
		return {"name": name, "array_size": 16}
	if name.begins_with("Recommended"):
		return {"name": name, "array_size": 24}
	return {"name": name, "array_size": 36}

func _m67h_generated_support_limits() -> Dictionary:
	match installation_mode:
		"Truss":
			return {"min_radius_m": 3.2, "max_radius_m": 6.6}
		"Stands":
			return {"min_radius_m": 3.0, "max_radius_m": 5.8}
		"Tripods":
			return {"min_radius_m": 2.8, "max_radius_m": 5.2}
		_:
			return {"min_radius_m": M67H_GENERATOR_MIN_RADIUS_M, "max_radius_m": 6.2}

func _m67h_generated_tier_heights(subject_bounds: Dictionary) -> Dictionary:
	var size_v: Vector3 = subject_bounds.get("size", Vector3(0.6, ROBOT_HEIGHT_M, 0.5))
	var min_v: Vector3 = subject_bounds.get("min", Vector3.ZERO)
	var low = clamp(min_v.y + size_v.y * 0.38, 0.58, 1.10)
	var mid = clamp(min_v.y + size_v.y * 0.76, low + 0.42, 1.70)
	var high = clamp(min_v.y + size_v.y * 1.28, mid + 0.48, 2.75)
	match installation_mode:
		"Truss":
			high = min(2.95, high + 0.14)
			mid = min(1.85, mid + 0.06)
		"Tripods":
			high = min(high, 2.15)
		"Stands":
			high = min(high, 2.45)
	return {"low": low, "mid": mid, "high": high}

func _m67h_generated_mount_label(azimuth_deg: float, tier: String) -> String:
	var sector = "front"
	if azimuth_deg >= 45.0 and azimuth_deg < 135.0:
		sector = "upstage"
	elif azimuth_deg >= 135.0 and azimuth_deg < 225.0:
		sector = "camera-left"
	elif azimuth_deg >= 225.0 and azimuth_deg < 315.0:
		sector = "downstage"
	else:
		sector = "camera-right"
	if installation_mode == "Truss":
		return "truss run " + sector
	if installation_mode == "Stands":
		return "stand arc " + sector
	if installation_mode == "Tripods":
		return "tripod arc " + sector
	if tier == "high":
		return "truss run " + sector
	if tier == "mid":
		return "stand arc " + sector
	return "tripod arc " + sector

func _m67h_required_camera_radius(subject_bounds: Dictionary, portrait: bool) -> float:
	var size_v: Vector3 = subject_bounds.get("size", Vector3(0.6, ROBOT_HEIGHT_M, 0.5))
	var subject_safety = _m67h_subject_frame_safety()
	var vfov = M66D_PORTRAIT_VFOV_DEG if portrait else M66D_LANDSCAPE_VFOV_DEG
	var tan_half_v = tan(deg_to_rad(vfov) * 0.5)
	var tan_half_h = tan_half_v * (float(CLEAN_RENDER_SIZE.x) / float(CLEAN_RENDER_SIZE.y))
	var half_horizontal_span = max(0.10, Vector2(size_v.x, size_v.z).length() * 0.5)
	var width_fraction = max(0.10, 1.0 - (2.0 * float(subject_safety.get("side_target_margin_pct", 0.0)) / 100.0))
	var height_fraction = max(0.10, 1.0 - ((float(subject_safety.get("bottom_target_margin_pct", 0.0)) + float(subject_safety.get("top_min_margin_pct", 0.0))) / 100.0))
	var radius_h = half_horizontal_span / max(0.05, tan_half_h * width_fraction)
	var radius_v = (size_v.y * 0.5) / max(0.05, tan_half_v * height_fraction)
	return max(radius_h, radius_v) * M67H_GENERATOR_RADIUS_SAFETY_FACTOR

func _m67h_build_frame_safe_cameras(profile: Dictionary) -> void:
	var subject_bounds = _m67h_capture_subject_bounds()
	var tier_heights = _m67h_generated_tier_heights(subject_bounds)
	var limits = _m67h_generated_support_limits()
	var spacing_deg = float(profile.get("azimuth_spacing_deg", 30.0))
	var stagger_deg = float(profile.get("tier_stagger_deg", 10.0))
	var tier_order: Array = profile.get("tiers", ["low", "mid", "high"])
	var raw: Array = []
	var tier_radii: Dictionary = {}
	for tier_idx in range(tier_order.size()):
		var tier_name = str(tier_order[tier_idx])
		for slot in range(int(profile.get("cameras_per_tier", 1))):
			var azimuth_deg = fposmod(float(slot) * spacing_deg + float(tier_idx) * stagger_deg, 360.0)
			var base_radius = clamp(
				_m67h_required_camera_radius(subject_bounds, false),
				float(limits.get("min_radius_m", M67H_GENERATOR_MIN_RADIUS_M)),
				float(limits.get("max_radius_m", M67H_GENERATOR_MAX_RADIUS_M))
			)
			var radius = base_radius
			var solved: Dictionary = {}
			while radius <= float(limits.get("max_radius_m", M67H_GENERATOR_MAX_RADIUS_M)) + 0.0001:
				var pos = Vector3(cos(deg_to_rad(azimuth_deg)) * radius, float(tier_heights.get(tier_name, 1.55)), sin(deg_to_rad(azimuth_deg)) * radius)
				var probe = {
					"id": "TEMP",
					"position": pos,
					"tier": tier_name,
					"portrait": false,
					"mount": _m67h_generated_mount_label(azimuth_deg, tier_name),
					"frame_safe_generation": true
				}
				solved = _m67h_solve_frame_safe_aim(probe, CLEAN_RENDER_SIZE)
				var subject_status = str(solved.get("subject_status", "INVALID"))
				if subject_status == "PASS":
					break
				if subject_status == "WARNING" and radius >= base_radius + 0.24:
					break
				radius += M67H_GENERATOR_RADIUS_STEP_M
			if not tier_radii.has(tier_name):
				tier_radii[tier_name] = []
			(tier_radii[tier_name] as Array).append(radius)
			raw.append({
				"azimuth_deg": azimuth_deg,
				"position": Vector3(cos(deg_to_rad(azimuth_deg)) * radius, float(tier_heights.get(tier_name, 1.55)), sin(deg_to_rad(azimuth_deg)) * radius),
				"tier": tier_name,
				"portrait": false,
				"mount": _m67h_generated_mount_label(azimuth_deg, tier_name),
				"frame_safe_generation": true,
				"array_profile_name": str(profile.get("name", layout_name)),
				"array_size": int(profile.get("array_size", 0)),
				"tier_count": int(profile.get("tier_count", 3)),
				"cameras_per_tier": int(profile.get("cameras_per_tier", 0)),
				"tier_height_m": float(tier_heights.get(tier_name, 1.55)),
				"radius_m": radius,
				"azimuth_spacing_deg": spacing_deg,
				"tier_stagger_deg": stagger_deg
			})
	raw.sort_custom(func(a, b):
		var da = a as Dictionary
		var db = b as Dictionary
		if absf(float(da.get("azimuth_deg", 0.0)) - float(db.get("azimuth_deg", 0.0))) > 0.001:
			return float(da.get("azimuth_deg", 0.0)) < float(db.get("azimuth_deg", 0.0))
		var order = {"low": 0, "mid": 1, "high": 2}
		return int(order.get(str(da.get("tier", "mid")), 1)) < int(order.get(str(db.get("tier", "mid")), 1))
	)
	for i in range(raw.size()):
		var data: Dictionary = raw[i] as Dictionary
		data["id"] = "C%02d" % (i + 1)
		data["index"] = i
		data["tier_heights_m"] = {
			"low": float(tier_heights.get("low", 0.0)),
			"mid": float(tier_heights.get("mid", 0.0)),
			"high": float(tier_heights.get("high", 0.0))
		}
		data["tier_radius_m"] = {
			"low": _m67h_num_array_mean(tier_radii.get("low", [])),
			"mid": _m67h_num_array_mean(tier_radii.get("mid", [])),
			"high": _m67h_num_array_mean(tier_radii.get("high", []))
		}
		data = _m67h_refresh_camera_layout_fields(data)
		cameras.append(data)
		var node = _create_camera_proxy(data)
		camera_nodes.append(node)

func _m67h_num_array_mean(values: Variant) -> float:
	if typeof(values) != TYPE_ARRAY:
		return 0.0
	var arr: Array = values as Array
	if arr.is_empty():
		return 0.0
	var total := 0.0
	for value in arr:
		total += float(value)
	return total / float(arr.size())

func _camera_count() -> int:
	return int(_m67h_array_profile(layout_name).get("array_size", 36))

func _build_cameras() -> void:
	if _m67h_is_frame_safe_profile(layout_name):
		_m67h_build_frame_safe_cameras(_m67h_array_profile(layout_name))
		return
	var count = _camera_count()
	var radius = 3.9
	if count == 16:
		radius = 3.85
	elif count == 24:
		radius = 4.05
	else:
		radius = 4.1
	for i in range(count):
		var a = TAU * float(i) / float(count)
		var tier = _tier_for(i, count)
		var h = 1.35
		if tier == "low":
			h = 0.72
		elif tier == "high":
			h = 2.45
		else:
			h = 1.55
		var pos = Vector3(cos(a) * radius, h, sin(a) * radius)
		var id = "C%02d" % (i + 1)
		var portrait = (i % 5 == 0 or tier == "low")
		var data = {
			"id": id,
			"index": i,
			"azimuth_deg": rad_to_deg(a),
			"position": pos,
			"tier": tier,
			"portrait": portrait,
			"mount": _mount_zone_for_angle(a, tier)
		}
		data = _m67h_refresh_camera_layout_fields(data)
		cameras.append(data)
		var node = _create_camera_proxy(data)
		camera_nodes.append(node)

func _tier_for(i: int, count: int) -> String:
	if count == 16:
		if i % 4 == 0:
			return "high"
		if i % 4 == 2:
			return "low"
		return "mid"
	if count == 24:
		if i % 6 == 0 or i % 6 == 1:
			return "high"
		if i % 6 == 3 or i % 6 == 4:
			return "low"
		return "mid"
	# 36 camera default: balanced low/mid/high tiers.
	if i % 6 == 0 or i % 6 == 1:
		return "low"
	if i % 6 == 3 or i % 6 == 4:
		return "high"
	return "mid"

func _mount_zone_for_angle(a: float, tier: String) -> String:
	var deg = fposmod(rad_to_deg(a), 360.0)
	if deg > 55 and deg < 125:
		return "upstage truss"
	if deg > 235 and deg < 305:
		return "front truss"
	if deg >= 125 and deg <= 235:
		return "left tower/stand zone"
	return "right tower/stand zone"

func _projected_px_cm(d: float, portrait: bool) -> float:
	var base = 52.0 / max(d, 0.1)
	if portrait:
		base *= 1.05
	return snapped(base, 0.01)

func _create_camera_proxy(data: Dictionary) -> Node3D:
	var holder = Node3D.new()
	holder.name = str(data["id"]) + " KOMODO-X proxy"
	holder.position = data["position"] as Vector3
	camera_root.add_child(holder)
	holder.look_at(_m67h_camera_aim_target(data), Vector3.UP)

	var body = MeshInstance3D.new()
	var bm = BoxMesh.new()
	# RED KOMODO-X proxy body: approx 129 x 101 x 95 mm scaled slightly up for visibility.
	bm.size = Vector3(0.24, 0.18, 0.19)
	body.mesh = bm
	body.material_override = mat_camera_body if int(data.get("index", 0)) != selected_index else mat_camera_selected
	body.position = Vector3(0, 0, 0.04)
	body.name = str(data["id"]) + " body"
	holder.add_child(body)

	var lens = MeshInstance3D.new()
	var lm = CylinderMesh.new()
	lm.top_radius = 0.065
	lm.bottom_radius = 0.065
	lm.height = 0.22
	lens.mesh = lm
	lens.material_override = mat_camera_lens
	lens.rotation_degrees.x = 90
	lens.position = Vector3(0, 0, -0.13)
	lens.name = str(data["id"]) + " lens barrel"
	holder.add_child(lens)

	var fp = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	fp.mesh = sm
	fp.material_override = _mat(Color(0.25, 0.9, 1.0, 1.0), false)
	fp.position = Vector3(0, 0, -0.005)
	fp.name = str(data["id"]) + " film-plane origin"
	holder.add_child(fp)

	var label = Label3D.new()
	label.name = str(data["id"]) + " label"
	label.text = str(data["id"])
	label.font_size = 22
	label.modulate = Color(0.88,0.98,0.92,0.92)
	label.position = Vector3(0.0, 0.24, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visible = false
	holder.add_child(label)
	return holder

func _rebuild_camera_dropdown() -> void:
	if camera_option == null:
		return
	camera_option.clear()
	for c in cameras:
		camera_option.add_item(str(c["id"]) + " · " + str(round(float(c["azimuth_deg"]))) + "° · " + str(c["tier"]))
	camera_option.selected = selected_index

func _rebuild_overlays() -> void:
	# M67D: hide rig helper geometry outside Rigging / Lighting.
	if rig_root != null:
		rig_root.visible = mode == "Rigging / Lighting"
	for child in overlay_root.get_children():
		child.queue_free()
	if focus_envelope_root != null:
		focus_envelope_root.visible = mode == "Focus" or mode == "Splat Viability"
	if mode == "Focus":
		# M2.9: all cameras transform to focus-style visualization, with reduced opacity.
		for i in range(cameras.size()):
			_add_focus_zones_for_camera(i, i == selected_index)
		_m67f_add_focus_arrow_for_selected()
	elif mode == "Splat Viability":
		# M2.9: user-selectable all-frustum or one-at-a-time contribution view.
		if splat_all_frustums:
			for i in range(cameras.size()):
				var mat = _splat_material(i, i == selected_index)
				var frustum = _make_frustum_mesh(cameras[i], mat, i == selected_index, true)
				overlay_root.add_child(frustum)
		else:
			var mat_one = _splat_material(selected_index, true)
			mat_one.albedo_color.a = 0.14
			overlay_root.add_child(_make_frustum_mesh(cameras[selected_index], mat_one, true, true))
		_add_contribution_overlay()
		if splat_all_frustums:
			_add_redundancy_markers()
	elif mode == "Rigging / Lighting":
		_add_mount_lines()
		if not cameras.is_empty():
			if splat_all_frustums:
				for i in range(cameras.size()):
					var rig_mat = mat_selected if i == selected_index else mat_frustum_faint
					overlay_root.add_child(_make_frustum_mesh(cameras[i], rig_mat, i == selected_index, true))
			else:
				overlay_root.add_child(_make_frustum_mesh(cameras[selected_index], mat_selected, true, true))
	elif mode == "Edit Camera":
		if focus_envelope_root != null:
			focus_envelope_root.visible = true
		if not cameras.is_empty():
			if splat_all_frustums:
				for i in range(cameras.size()):
					var edit_mat = mat_selected if i == selected_index else mat_frustum_faint
					overlay_root.add_child(_make_frustum_mesh(cameras[i], edit_mat, i == selected_index, true))
			else:
				overlay_root.add_child(_make_frustum_mesh(cameras[selected_index], mat_selected, true, true))
			_add_mount_lines()
	elif mode == "Camera POV":
		# Keep the viewport clean; left/right buttons drive camera order.
		pass
	elif mode == "Comparison":
		# Comparison is a 2D analysis panel over a clean scene.
		pass
	elif mode == "Splat View":
		# Dedicated result-view mode: no camera frustums, no rig overlays.
		pass
	_update_camera_highlight()
	_update_inspector()

func _splat_material(i: int, selected: bool) -> StandardMaterial3D:
	var palette = [
		Color(0.95, 0.10, 0.78, 0.075),
		Color(0.05, 0.78, 1.00, 0.060),
		Color(1.00, 0.58, 0.06, 0.055),
		Color(0.45, 0.95, 0.20, 0.055),
		Color(0.72, 0.35, 1.00, 0.060),
		Color(1.00, 0.92, 0.12, 0.052),
		Color(0.10, 1.00, 0.70, 0.055),
		Color(1.00, 0.30, 0.30, 0.052),
		Color(0.30, 0.55, 1.00, 0.055),
		Color(0.95, 0.55, 0.95, 0.055)
	]
	var c: Color = palette[i % palette.size()]
	if selected:
		c.a = 0.085
	else:
		c.a = 0.018
	return _mat(c, true)

func _prev_index() -> int:
	return (selected_index - 1 + cameras.size()) % cameras.size()

func _next_index() -> int:
	return (selected_index + 1) % cameras.size()

func _make_frustum_mesh(data: Dictionary, material: StandardMaterial3D, strong: bool, stop_at_subject: bool = false) -> MeshInstance3D:
	# Issue 5 fix: frustum geometry now derives from CaptureMath (per-camera
	# capture vfov + render aspect) instead of a hardcoded 36 deg / 16:9
	# approximation, so the overlay matches the rendered stills exactly.
	# Portrait roll lives in the camera basis, so no width/height swap here.
	var origin: Vector3 = data["position"] as Vector3
	var target = _m67h_camera_aim_target(data)
	var axes = CaptureMath.capture_axes_from_target(data, target)
	var forward: Vector3 = axes["forward"] as Vector3
	var right: Vector3 = axes["right"] as Vector3
	var up: Vector3 = axes["up"] as Vector3
	var focus_d = origin.distance_to(target)
	var far_d = focus_d * 0.985 if stop_at_subject else max(6.0, focus_d + 1.4)
	var aspect = float(CLEAN_RENDER_SIZE.x) / float(CLEAN_RENDER_SIZE.y)
	var half_ext: Vector2 = CaptureMath.frustum_half_extents(data, far_d, aspect)
	var half_w = half_ext.x
	var half_h = half_ext.y
	var center = origin + forward * far_d
	var p1 = center + right * half_w + up * half_h
	var p2 = center - right * half_w + up * half_h
	var p3 = center - right * half_w - up * half_h
	var p4 = center + right * half_w - up * half_h
	var verts = PackedVector3Array([
		origin, p1, p2,
		origin, p2, p3,
		origin, p3, p4,
		origin, p4, p1,
		p1, p2, p3,
		p1, p3, p4
	])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.name = str(data["id"]) + " sensor-shaped frustum from film plane"
	# Outline lines for sensor gate and sides.
	var pts = PackedVector3Array([origin,p1, origin,p2, origin,p3, origin,p4, p1,p2, p2,p3, p3,p4, p4,p1])
	var line = MeshInstance3D.new()
	line.mesh = _line_mesh(pts)
	line.material_override = _mat(Color(material.albedo_color.r, material.albedo_color.g, material.albedo_color.b, 0.52 if strong else 0.16), true)
	line.name = str(data["id"]) + " frustum outline"
	inst.add_child(line)
	return inst

func _add_focus_zones_for_camera(idx: int, selected: bool) -> void:
	var data = cameras[idx]
	var origin: Vector3 = data["position"] as Vector3
	var d: float = float(data["focus_m"])
	# User-provided RED 6K 16:9 / 24mm / T5.6 reference: focus around 14ft,
	# hyperfocal 19'11", acceptable DoF near 8'3" and far 46'11".
	# Viewport clips far display to keep Focus mode readable; inspector reports the full values.
	var near_d = 2.52
	var full_far_d = 14.30
	var critical_near = max(0.4, d - 0.55)
	var critical_far = d + 0.55
	var display_far = min(full_far_d, d + 1.15)
	# Selected camera reads clearly; all other cameras are intentionally faint context.
	# This prevents the focus view from becoming a solid yellow/orange wall.
	var alpha_mul = 0.38 if selected else 0.018
	_add_frustum_segment(data, max(0.4, critical_near - 0.75), critical_near, _mat(Color(1.0,0.32,0.06,0.030 * alpha_mul), true), str(data["id"]) + " orange: approaching too near")
	_add_frustum_segment(data, critical_near - 0.18, critical_near, _mat(Color(1.0,0.82,0.08,0.030 * alpha_mul), true), str(data["id"]) + " yellow: acceptable near focus")
	_add_frustum_segment(data, critical_near, critical_far, _mat(Color(0.22,1.0,0.38,0.075 * alpha_mul), true), str(data["id"]) + " green: critical sharpness slab")
	_add_frustum_segment(data, critical_far, display_far, _mat(Color(1.0,0.82,0.08,0.030 * alpha_mul), true), str(data["id"]) + " yellow: acceptable far focus")
	if not selected:
		_add_focus_centerline(origin, TARGET, data)
	# Focus numbers now live in the bottom-right UI readout instead of inside the 3D frustum.

func _add_focus_centerline(origin: Vector3, target: Vector3, data: Dictionary) -> void:
	var d = origin.distance_to(target)
	var forward = (target - origin).normalized()
	var pts = PackedVector3Array([origin + forward * max(0.25, d - 0.75), origin + forward * min(d + 0.75, d + 1.1)])
	var line = MeshInstance3D.new()
	line.mesh = _line_mesh(pts)
	line.material_override = _mat(Color(0.72, 1.0, 0.72, 0.22), true)
	line.name = str(data["id"]) + " faint focus centerline"
	overlay_root.add_child(line)

func _add_frustum_segment(c: Dictionary, near_d: float, far_d: float, material: Material, name: String) -> void:
	# Issue 5 fix: segments use the camera's true aim target, per-camera capture
	# vfov, and render aspect via CaptureMath (was: TARGET + hardcoded 36 deg 16:9).
	if far_d <= near_d + 0.02:
		return
	var origin: Vector3 = c["position"] as Vector3
	var target: Vector3 = _m67h_camera_aim_target(c)
	var axes = CaptureMath.capture_axes_from_target(c, target)
	var forward: Vector3 = axes["forward"] as Vector3
	var right: Vector3 = axes["right"] as Vector3
	var up: Vector3 = axes["up"] as Vector3
	var aspect = float(CLEAN_RENDER_SIZE.x) / float(CLEAN_RENDER_SIZE.y)
	var near_ext: Vector2 = CaptureMath.frustum_half_extents(c, near_d, aspect)
	var far_ext: Vector2 = CaptureMath.frustum_half_extents(c, far_d, aspect)
	var n_w = near_ext.x
	var n_h = near_ext.y
	var f_w = far_ext.x
	var f_h = far_ext.y
	var nc = origin + forward * near_d
	var fc = origin + forward * far_d
	var n1 = nc + right*n_w + up*n_h
	var n2 = nc - right*n_w + up*n_h
	var n3 = nc - right*n_w - up*n_h
	var n4 = nc + right*n_w - up*n_h
	var f1 = fc + right*f_w + up*f_h
	var f2 = fc - right*f_w + up*f_h
	var f3 = fc - right*f_w - up*f_h
	var f4 = fc + right*f_w - up*f_h
	var verts = PackedVector3Array([
		n1,n2,f2, n1,f2,f1,
		n2,n3,f3, n2,f3,f2,
		n3,n4,f4, n3,f4,f3,
		n4,n1,f1, n4,f1,f4,
		n1,n2,n3, n1,n3,n4,
		f1,f2,f3, f1,f3,f4
	])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.name = name
	overlay_root.add_child(inst)

func _add_contribution_overlay() -> void:
	var count = cameras.size()
	var gap = 360.0 / count
	var weak_count = 0
	if count == 16:
		weak_count = 8
	elif count == 24:
		weak_count = 2
	else:
		weak_count = 0
	# selected / neighbor performer-side patches
	_add_subject_wedge(cameras[selected_index], mat_selected, 0.68, "selected camera subject contribution")
	_add_subject_wedge(cameras[_prev_index()], mat_prev, 0.58, "previous neighbor subject contribution")
	_add_subject_wedge(cameras[_next_index()], mat_next, 0.58, "next neighbor subject contribution")
	for i in range(weak_count):
		var deg = i * 360.0 / max(weak_count, 1) + gap * 0.5
		_add_dead_zone_hatch(deg_to_rad(deg), "add view: %.1f° gap" % gap)

func _add_subject_wedge(data: Dictionary, material: Material, scale: float, label: String) -> void:
	var origin: Vector3 = data["position"] as Vector3
	var dir = (Vector3(0, 0.9, 0) - origin).normalized()
	var center = Vector3(0, 1.0, 0) - dir * 0.38
	var right = dir.cross(Vector3.UP).normalized()
	if right.length() < 0.001:
		right = Vector3.RIGHT
	var up = Vector3.UP
	var w = 0.75 * scale
	var h = 1.55 * scale
	var p1 = center + right*w + up*h*0.5
	var p2 = center - right*w + up*h*0.5
	var p3 = center - right*w - up*h*0.5
	var p4 = center + right*w - up*h*0.5
	var verts = PackedVector3Array([p1,p2,p3, p1,p3,p4])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst = MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.name = label + " projected onto performer volume"
	overlay_root.add_child(inst)

func _add_dead_zone_hatch(angle: float, text: String) -> void:
	var radius = 0.72
	var center = Vector3(cos(angle)*radius, 1.1, sin(angle)*radius)
	var tangent = Vector3(-sin(angle), 0, cos(angle)).normalized()
	var up = Vector3.UP
	var pts = PackedVector3Array()
	for j in range(5):
		var y = 0.45 + j * 0.25
		pts.append(center + tangent * -0.22 + up * (y - 1.1))
		pts.append(center + tangent * 0.22 + up * (y - 0.88))
	var line = MeshInstance3D.new()
	line.mesh = _line_mesh(pts)
	line.material_override = mat_weak_line
	line.name = "weak/dead contribution hatching: " + text
	overlay_root.add_child(line)
	# M3.7: weak-view text is shown in bottom readout, not over the subject.
	# _add_label3d(text, center + Vector3(0, 0.85, 0), Color(1,1,1))

func _add_mount_lines() -> void:
	for i in range(cameras.size()):
		var c = cameras[i]
		var pos: Vector3 = c["position"] as Vector3
		var mount = Vector3(pos.x, clamp(pos.y - 0.7, 0.1, 3.6), pos.z)
		var line = MeshInstance3D.new()
		line.mesh = _line_mesh(PackedVector3Array([pos, mount]))
		line.material_override = mat_truss
		line.name = str(c["id"]) + " assumed mount confidence line"
		overlay_root.add_child(line)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	var screen_size = get_viewport().get_visible_rect().size
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 0
	top_bar.offset_top = 0
	top_bar.offset_right = 0
	top_bar.offset_bottom = TOP_BAR_H
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(screen_size.x, TOP_BAR_H)
	top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	top_bar.add_theme_stylebox_override("panel", _panel_style(Color(0.015,0.035,0.04,1.0)))
	root.add_child(top_bar)
	var th = HBoxContainer.new()
	th.custom_minimum_size = Vector2(screen_size.x - 24, TOP_BAR_H - 10)
	th.add_theme_constant_override("separation", 22)
	top_bar.add_child(th)
	_add_toolbar_label(th, SPLATVIZ_RELEASE_LABEL, 22, Color(0.68, 1.0, 0.82), 165)
	_add_toolbar_button(th, "Scene", func(): _set_mode("Rigging / Lighting"), 92)
	_add_toolbar_button(th, "Cameras", func(): _set_mode("Edit Camera"), 110)
	_add_toolbar_button(th, "Analysis", func(): _m67a1_toggle_analysis(), 112)
	_add_toolbar_button(th, "Export", func(): _m67a1_open_export_tools(), 92)
	_add_toolbar_button(th, "Msplat", func(): _open_msplat_window(), 104)
	_add_toolbar_button(th, "Splat View", func(): _set_mode("Splat View"), 122)
	_add_toolbar_button(th, "Stills", func(): _open_stills_window(), 86)
	_add_toolbar_button(th, "Settings", func(): _m68a3_open_settings_window(), 98)
	_add_toolbar_button(th, "Help", func(): _show_help(), 78)
	_add_toolbar_button(th, "Inspector", func(): _toggle_inspector(), 98)
	_m68a3_build_settings_window()

	left_panel = PanelContainer.new()
	left_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_panel.offset_left = 0
	left_panel.offset_top = TOP_BAR_H
	left_panel.offset_right = _m67c_left_panel_width()
	left_panel.offset_bottom = 0
	left_panel.position = Vector2(0, TOP_BAR_H)
	left_panel.size = Vector2(_m67c_left_panel_width(), screen_size.y - TOP_BAR_H)
	left_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	left_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02,0.07,0.075,1.0)))
	root.add_child(left_panel)
	# M3.9: left panel uses a fixed dock width with vertical scrolling.
	# This prevents lower controls from being clipped on laptop-height windows.
	var left_scroll = ScrollContainer.new()
	left_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_panel.add_child(left_scroll)
	var lv = VBoxContainer.new()
	lv.custom_minimum_size = Vector2(max(220.0, _m67c_left_panel_width() - 24.0), 0)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 6)
	left_scroll.add_child(lv)
	var rail_controls = HBoxContainer.new()
	rail_controls.add_theme_constant_override("separation", 4)
	lv.add_child(rail_controls)
	_add_button(rail_controls, "Hide", func(): _m67d_toggle_left_rail())
	_add_button(rail_controls, "–", func(): _m67d_resize_left_rail(-40.0))
	_add_button(rail_controls, "+", func(): _m67d_resize_left_rail(40.0))
	_add_label(lv, "PROJECT / STAGE", 14, Color(0.45, 1.0, 0.67))
	_add_label(lv, "NOZ Stage #1\n59×57 ft / 17.98×17.37 m\ngrid 18 ft / 5.49 m", 15, Color(0.82,0.93,0.89))

	_add_label(lv, "LAYOUT", 14, Color(0.45, 1.0, 0.67))
	layout_option = OptionButton.new()
	layout_option.add_theme_font_size_override("font_size", 16)
	layout_option.add_item("Frame-Safe 12-Camera Multi-Tier")
	layout_option.add_item("Frame-Safe 24-Camera Multi-Tier")
	layout_option.add_item("Frame-Safe 36-Camera Multi-Tier")
	layout_option.add_item("Lean 16-Camera Msplat")
	layout_option.add_item("Recommended 24-Camera Baseline")
	layout_option.add_item("Premium 36-Camera Multi-Tier")
	layout_option.item_selected.connect(func(idx): _on_layout_selected(idx))
	for i in range(layout_option.item_count):
		if layout_option.get_item_text(i) == layout_name:
			layout_option.select(i)
			break
	lv.add_child(layout_option)

	_add_label(lv, "MODE", 14, Color(0.45, 1.0, 0.67))
	_add_button(lv, "Focus", func(): _set_mode("Focus"))
	_add_button(lv, "Splat Viability", func(): _set_mode("Splat Viability"))
	_add_button(lv, "Compare Layouts", func(): _m67a1_toggle_analysis())
	_add_button(lv, "Edit Camera", func(): _set_mode("Edit Camera"))
	_add_button(lv, "Camera POV", func(): _set_mode("Camera POV"))
	_add_button(lv, "Rigging / Lighting", func(): _set_mode("Rigging / Lighting"))
	mode_label = _add_label(lv, "Mode: Rigging / Lighting", 17, Color.WHITE)
	_add_label(lv, "FRUSTUMS", 14, Color(0.45, 1.0, 0.67))
	show_all_frustums_toggle = CheckButton.new()
	show_all_frustums_toggle.text = "Show All Frustums"
	show_all_frustums_toggle.button_pressed = splat_all_frustums
	show_all_frustums_toggle.focus_mode = Control.FOCUS_NONE
	show_all_frustums_toggle.toggled.connect(func(pressed): _on_show_all_frustums_toggled(pressed))
	lv.add_child(show_all_frustums_toggle)

	_add_label(lv, "RENDER / EXPORT", 14, Color(0.45, 1.0, 0.67))
	_add_button(lv, "Render Cameras…", func(): _m67c_render_camera_dialog(false))
	_add_button(lv, "Render Selected Camera…", func(): _m67c_render_camera_dialog(true))
	_add_button(lv, "Export Layout Report…", func(): _prompt_external_layout_report())
	export_path_label = _add_label(lv, "Export folder:
" + export_root_path, 12, Color(0.70,0.84,0.78))

	# Msplat actions live in the top Msplat tab so the left panel stays focused on scene/layout controls.
	msplat_status_label = _add_label(lv, "Msplat opens as a separate terminal window from the top tab.", 12, Color(0.70,0.84,0.78))

	_add_label(lv, "CAMERA", 14, Color(0.45, 1.0, 0.67))
	camera_option = OptionButton.new()
	camera_option.add_theme_font_size_override("font_size", 16)
	camera_option.item_selected.connect(func(idx): _on_camera_selected(idx))
	lv.add_child(camera_option)

	_add_label(lv, "EDIT CAMERA", 14, Color(0.45, 1.0, 0.67))
	var edit_grid = GridContainer.new()
	edit_grid.columns = 2
	lv.add_child(edit_grid)
	_add_button(edit_grid, "In 0.25m", func(): _nudge_selected_camera("in"))
	_add_button(edit_grid, "Out 0.25m", func(): _nudge_selected_camera("out"))
	_add_button(edit_grid, "Az -2°", func(): _nudge_selected_camera("az_left"))
	_add_button(edit_grid, "Az +2°", func(): _nudge_selected_camera("az_right"))
	_add_button(edit_grid, "Up 0.15m", func(): _nudge_selected_camera("up"))
	_add_button(edit_grid, "Down 0.15m", func(): _nudge_selected_camera("down"))
	_add_button(edit_grid, "Toggle Roll", func(): _nudge_selected_camera("roll"))
	_add_button(edit_grid, "Reset Layout", func(): _set_layout(layout_name))
	edit_status_label = _add_label(lv, "Edit mode: select a camera, then nudge position. Metrics update live.", 13, Color(0.78,0.94,0.86))

	_add_label(lv, "VIEW PRESETS", 14, Color(0.45, 1.0, 0.67))
	var view_grid = GridContainer.new()
	view_grid.columns = 2
	lv.add_child(view_grid)
	_add_button(view_grid, "Perspective", func(): _preset_perspective())
	_add_button(view_grid, "Top", func(): _preset_top())
	_add_button(view_grid, "Front", func(): _preset_front())
	_add_button(view_grid, "Eye Line", func(): _preset_eye_line())
	_add_button(view_grid, "Reset", func(): _preset_perspective())
	_add_button(view_grid, "Save View PNG", func(): _save_view_png())

	_add_label(lv, "CAMERA TIERS\n● Low Tier    ● Mid Tier    ● High Tier", 14, Color(0.78,0.94,0.86))
	status_label = _add_label(lv, "", 14, Color(0.86,0.95,0.9))
	prediction_label = _add_label(lv, "Prediction status: hypotheses require gsplat validation. Msplat is a local run option only.", 15, Color.WHITE)

	right_panel = PanelContainer.new()
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_left = -RIGHT_PANEL_W
	right_panel.offset_right = 0
	right_panel.offset_top = TOP_BAR_H
	right_panel.offset_bottom = 0
	right_panel.position = Vector2(screen_size.x - RIGHT_PANEL_W, TOP_BAR_H)
	right_panel.size = Vector2(RIGHT_PANEL_W, screen_size.y - TOP_BAR_H)
	right_panel.visible = inspector_visible
	right_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	right_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02,0.07,0.075,1.0)))
	root.add_child(right_panel)
	var rv = VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right_panel.add_child(rv)
	_add_label(rv, "INSPECTOR", 20, Color.WHITE)
	_add_label(rv, "ANALYSIS INSPECTOR", 15, Color(0.45, 1.0, 0.67))
	inspector_label = _add_label(rv, "", 18, Color.WHITE)

	inspector_toggle_button = Button.new()
	inspector_toggle_button.text = "Hide Inspector" if inspector_visible else "Show Inspector"
	inspector_toggle_button.position = Vector2(screen_size.x - RIGHT_PANEL_W - 112, TOP_BAR_H + 8) if inspector_visible else Vector2(screen_size.x - 138, TOP_BAR_H + 8)
	inspector_toggle_button.size = Vector2(130, 34)
	inspector_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	inspector_toggle_button.pressed.connect(func(): _toggle_inspector())
	root.add_child(inspector_toggle_button)

	# Persistent next/previous camera buttons, useful in Camera POV and selection review.
	prev_cam_button = Button.new()
	prev_cam_button.text = "‹\nPrev\nCam"
	prev_cam_button.position = Vector2(_m67c_left_panel_width() + 12, screen_size.y * 0.48)
	prev_cam_button.size = Vector2(56, 92)
	prev_cam_button.mouse_filter = Control.MOUSE_FILTER_STOP
	prev_cam_button.pressed.connect(func(): _select_prev_camera())
	root.add_child(prev_cam_button)
	next_cam_button = Button.new()
	next_cam_button.text = "›\nNext\nCam"
	next_cam_button.position = Vector2(screen_size.x - RIGHT_PANEL_W - 68, screen_size.y * 0.48)
	next_cam_button.size = Vector2(56, 92)
	next_cam_button.mouse_filter = Control.MOUSE_FILTER_STOP
	next_cam_button.pressed.connect(func(): _select_next_camera())
	root.add_child(next_cam_button)

	focus_readout_panel = PanelContainer.new()
	focus_readout_panel.position = Vector2(screen_size.x - RIGHT_PANEL_W - 470, screen_size.y - 222)
	focus_readout_panel.size = Vector2(560, 210)
	focus_readout_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_readout_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012,0.04,0.045,0.86)))
	root.add_child(focus_readout_panel)
	focus_readout_label = Label.new()
	focus_readout_label.add_theme_font_size_override("font_size", 18)
	focus_readout_label.add_theme_color_override("font_color", Color(0.92, 1.0, 0.92))
	focus_readout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_readout_panel.add_child(focus_readout_label)

	export_dialog = FileDialog.new()
	export_dialog.title = "Choose SplatViz Export Folder"
	export_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.dir_selected.connect(func(dir): _set_export_folder(dir))
	root.add_child(export_dialog)

	msplat_dataset_dialog = FileDialog.new()
	msplat_dataset_dialog.title = "Choose Msplat Dataset or Rendered Images Folder"
	msplat_dataset_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	msplat_dataset_dialog.access = FileDialog.ACCESS_FILESYSTEM
	msplat_dataset_dialog.dir_selected.connect(func(dir): _set_msplat_dataset_folder(dir))
	root.add_child(msplat_dataset_dialog)

	ply_import_dialog = FileDialog.new()
	ply_import_dialog.title = "Import Splat PLY"
	ply_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	ply_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	ply_import_dialog.filters = PackedStringArray(["*.ply ; PLY point cloud / Gaussian splat preview"])
	ply_import_dialog.file_selected.connect(func(path): _import_ply_file(path))
	root.add_child(ply_import_dialog)


	stills_folder_dialog = FileDialog.new()
	stills_folder_dialog.title = "Choose Still Image Folder or Dataset Root"
	stills_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	stills_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	stills_folder_dialog.dir_selected.connect(func(dir: String): _stills_set_folder(dir))
	root.add_child(stills_folder_dialog)

	_build_comparison_panel(root, screen_size)
	_build_msplat_panel(root, screen_size)
	_m67b_build_render_dialog()
	_m67b_build_splat_view_tools(root, screen_size)
	_build_stills_panel(root, screen_size)
	_build_camera_pov_preview(root, screen_size)
	_build_nav_legend(root)

func _build_comparison_panel(root: Control, screen_size: Vector2) -> void:
	comparison_panel = PanelContainer.new()
	comparison_panel.position = Vector2(LEFT_PANEL_W + 24, TOP_BAR_H + 24)
	comparison_panel.size = Vector2(max(520.0, screen_size.x - LEFT_PANEL_W - RIGHT_PANEL_W - 48), 280)
	comparison_panel.visible = false
	comparison_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	comparison_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018,0.055,0.06,0.96)))
	root.add_child(comparison_panel)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	comparison_panel.add_child(vb)
	var title = _add_label(vb, "Layout Comparison — Prediction Only", 22, Color(0.68,1.0,0.82))
	comparison_label = _add_label(vb, "", 17, Color(0.88,0.96,0.92))
	_update_comparison_panel()

func _m68a3_build_settings_window() -> void:
	if settings_window_m68a3 != null:
		return
	settings_window_m68a3 = Window.new()
	settings_window_m68a3.title = "Report Setup / Production Specs"
	settings_window_m68a3.size = Vector2i(720, 640)
	settings_window_m68a3.min_size = Vector2i(620, 520)
	settings_window_m68a3.visible = false
	settings_window_m68a3.close_requested.connect(func(): settings_window_m68a3.hide())
	add_child(settings_window_m68a3)
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_window_m68a3.add_child(scroll)
	var vb = VBoxContainer.new()
	vb.custom_minimum_size = Vector2(640, 0)
	vb.add_theme_constant_override("separation", 12)
	scroll.add_child(vb)
	settings_capture_specs_edit = LineEdit.new()
	_m68a3_settings_add_row(vb, "Capture Specs", settings_capture_specs_edit)
	settings_stage_specs_edit = LineEdit.new()
	_m68a3_settings_add_row(vb, "Stage Specs", settings_stage_specs_edit)
	settings_performer_specs_edit = LineEdit.new()
	_m68a3_settings_add_row(vb, "Performer Specs", settings_performer_specs_edit)
	settings_stage_name_edit = LineEdit.new()
	_m68a3_settings_add_row(vb, "Stage Name", settings_stage_name_edit)
	settings_floor_type_edit = LineEdit.new()
	_m68a3_settings_add_row(vb, "Floor Type / Surface", settings_floor_type_edit)
	settings_build_mode_option = OptionButton.new()
	for mode_name in ["Truss", "Stands", "Tripods", "Mixed"]:
		settings_build_mode_option.add_item(mode_name)
	_m68a3_settings_add_row(vb, "Build Mode", settings_build_mode_option)
	settings_label_scheme_option = OptionButton.new()
	for scheme in ["C01-C36", "AA-ID 36 Camera Grid", "Custom comma-separated labels"]:
		settings_label_scheme_option.add_item(scheme)
	_m68a3_settings_add_row(vb, "Camera Label Scheme", settings_label_scheme_option)
	settings_custom_labels_edit = LineEdit.new()
	settings_custom_labels_edit.placeholder_text = "AA, AB, AC, ..."
	_m68a3_settings_add_row(vb, "Custom Labels", settings_custom_labels_edit)
	settings_preview_background_option = OptionButton.new()
	for bg in ["Dark Grid", "Light Blueprint", "Sound Stage / Wood Floor"]:
		settings_preview_background_option.add_item(bg)
	_m68a3_settings_add_row(vb, "Report Preview Background", settings_preview_background_option)
	settings_height_m_edit = LineEdit.new()
	settings_height_m_edit.placeholder_text = "1.83"
	_m68a3_settings_add_row(vb, "Performer / Subject Height (m)", settings_height_m_edit)
	settings_height_scale_toggle = CheckButton.new()
	settings_height_scale_toggle.text = "Show height scale on report elevations"
	_m68a3_settings_add_row(vb, "Height Scale", settings_height_scale_toggle)
	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	var apply_btn = Button.new()
	apply_btn.text = "Apply"
	apply_btn.pressed.connect(func(): _m68a3_apply_report_settings_from_ui())
	actions.add_child(apply_btn)
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): settings_window_m68a3.hide())
	actions.add_child(close_btn)
	vb.add_child(actions)
	_m68a3_sync_report_settings_ui()

func _m68a3_open_settings_window() -> void:
	_m68a3_build_settings_window()
	_m68a3_sync_report_settings_ui()
	for i in range(settings_build_mode_option.item_count):
		if settings_build_mode_option.get_item_text(i) == installation_mode:
			settings_build_mode_option.select(i)
			break
	for i in range(settings_label_scheme_option.item_count):
		if settings_label_scheme_option.get_item_text(i) == report_camera_label_scheme:
			settings_label_scheme_option.select(i)
			break
	for i in range(settings_preview_background_option.item_count):
		if settings_preview_background_option.get_item_text(i) == report_preview_background:
			settings_preview_background_option.select(i)
			break
	settings_window_m68a3.popup_centered_ratio(0.55)

func _build_msplat_panel(root: Control, screen_size: Vector2) -> void:
	# M4.0: Use an explicit fixed layout for the Msplat Terminal window.
	# The previous container layout allowed labels/options to collapse into vertical text on some macOS window sizes.
	msplat_window = Window.new()
	msplat_window.title = "SplatViz Msplat Terminal"
	msplat_window.size = Vector2i(1360, 860)
	msplat_window.min_size = Vector2i(1180, 760)
	msplat_window.visible = false
	msplat_window.close_requested.connect(func(): msplat_window.visible = false)
	add_child(msplat_window)

	var root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	msplat_window.add_child(root_control)

	msplat_panel = PanelContainer.new()
	msplat_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	msplat_panel.visible = true
	msplat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	msplat_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.010,0.026,0.028,1.0)))
	root_control.add_child(msplat_panel)

	var title = Label.new()
	title.text = "Msplat Terminal"
	title.position = Vector2(24, 22)
	title.size = Vector2(420, 42)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.68,1.0,0.82))
	root_control.add_child(title)

	var desc = Label.new()
	desc.text = "Separate window. Browse an exported SplatViz dataset or clean-image folder, run msplat-train, then load splat.ply back onto the open stage."
	desc.position = Vector2(24, 76)
	desc.size = Vector2(1280, 28)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.82,0.93,0.89))
	desc.autowrap_mode = TextServer.AUTOWRAP_OFF
	root_control.add_child(desc)

	var iter_label = Label.new()
	iter_label.text = "Training iterations"
	iter_label.position = Vector2(24, 118)
	iter_label.size = Vector2(170, 34)
	iter_label.add_theme_font_size_override("font_size", 15)
	iter_label.add_theme_color_override("font_color", Color(0.78,0.94,0.86))
	iter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	root_control.add_child(iter_label)

	msplat_iters_option = OptionButton.new()
	msplat_iters_option.position = Vector2(204, 112)
	msplat_iters_option.size = Vector2(150, 38)
	msplat_iters_option.add_theme_font_size_override("font_size", 15)
	for v in [1500, 5000, 10000, 30000]:
		msplat_iters_option.add_item(str(v))
	msplat_iters_option.selected = 0
	msplat_iters_option.item_selected.connect(func(idx): _on_msplat_iters_selected(idx))
	root_control.add_child(msplat_iters_option)

	var note = Label.new()
	note.text = "Note: current msplat-train CLI exposes no resume/checkpoint flag. Higher iteration runs retrain from the selected dataset."
	note.position = Vector2(380, 118)
	note.size = Vector2(900, 30)
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.74,0.86,0.80))
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	root_control.add_child(note)

	msplat_progress_label = Label.new()
	msplat_progress_label.text = "Idle · no active Msplat run"
	msplat_progress_label.position = Vector2(24, 152)
	msplat_progress_label.size = Vector2(820, 24)
	msplat_progress_label.add_theme_font_size_override("font_size", 14)
	msplat_progress_label.add_theme_color_override("font_color", Color(0.78,0.94,0.86))
	msplat_progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	root_control.add_child(msplat_progress_label)

	msplat_progress_bar = ProgressBar.new()
	msplat_progress_bar.position = Vector2(880, 154)
	msplat_progress_bar.size = Vector2(420, 18)
	msplat_progress_bar.min_value = 0
	msplat_progress_bar.max_value = 100
	msplat_progress_bar.value = 0
	root_control.add_child(msplat_progress_bar)

	var y1 = 186
	var bw = 205
	var bh = 38
	var gap = 8
	_add_abs_button(root_control, "Browse Dataset Folder…", Vector2(24, y1), Vector2(bw, bh), func(): _browse_msplat_dataset_folder())
	_add_abs_button(root_control, "Find Latest Dataset", Vector2(24 + (bw+gap), y1), Vector2(bw, bh), func(): _find_latest_msplat_dataset())
	_add_abs_button(root_control, "Export Dataset", Vector2(24 + 2*(bw+gap), y1), Vector2(bw, bh), func(): _export_msplat_dataset())
	_add_abs_button(root_control, "Run Msplat", Vector2(24 + 3*(bw+gap), y1), Vector2(bw, bh), func(): _run_msplat_smoke_test())
	_add_abs_button(root_control, "Run Longer 10k", Vector2(24, y1 + 48), Vector2(bw, bh), func(): _run_msplat_longer())
	_add_abs_button(root_control, "Load Latest Splat", Vector2(24 + (bw+gap), y1 + 48), Vector2(bw, bh), func(): _load_latest_msplat_result())
	_add_abs_button(root_control, "Import PLY…", Vector2(24 + 2*(bw+gap), y1 + 48), Vector2(bw, bh), func(): _browse_ply_file())
	_add_abs_button(root_control, "Refresh Log", Vector2(24 + 3*(bw+gap), y1 + 48), Vector2(bw, bh), func(): _refresh_msplat_terminal(true))
	_add_abs_button(root_control, "Clear Terminal", Vector2(24, y1 + 96), Vector2(bw, bh), func(): _clear_msplat_terminal())
	_add_abs_button(root_control, "Open Result Folder", Vector2(24 + (bw+gap), y1 + 96), Vector2(bw, bh), func(): _open_msplat_result_folder())
	_add_abs_button(root_control, "Copy Command", Vector2(24 + 2*(bw+gap), y1 + 96), Vector2(bw, bh), func(): _copy_msplat_command())

	msplat_path_label = Label.new()
	msplat_path_label.position = Vector2(24, 344)
	msplat_path_label.size = Vector2(1280, 58)
	msplat_path_label.add_theme_font_size_override("font_size", 14)
	msplat_path_label.add_theme_color_override("font_color", Color(0.78,0.94,0.86))
	msplat_path_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	root_control.add_child(msplat_path_label)

	msplat_command_label = Label.new()
	msplat_command_label.position = Vector2(24, 408)
	msplat_command_label.size = Vector2(1280, 52)
	msplat_command_label.add_theme_font_size_override("font_size", 14)
	msplat_command_label.add_theme_color_override("font_color", Color(0.92,0.96,0.88))
	msplat_command_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_control.add_child(msplat_command_label)

	var terminal_box = PanelContainer.new()
	terminal_box.position = Vector2(24, 472)
	terminal_box.size = Vector2(1308, 358)
	terminal_box.mouse_filter = Control.MOUSE_FILTER_STOP
	terminal_box.add_theme_stylebox_override("panel", _panel_style(Color(0.0,0.008,0.01,1.0)))
	root_control.add_child(terminal_box)

	msplat_terminal_label = TextEdit.new()
	msplat_terminal_label.position = Vector2(8, 8)
	msplat_terminal_label.size = Vector2(1292, 342)
	msplat_terminal_label.add_theme_font_size_override("font_size", 14)
	msplat_terminal_label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.82))
	msplat_terminal_label.add_theme_color_override("font_readonly_color", Color(0.78, 1.0, 0.82))
	msplat_terminal_label.editable = false
	msplat_terminal_label.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	msplat_terminal_label.scroll_fit_content_height = false
	msplat_terminal_label.text = "$ " + SPLATVIZ_RELEASE_LABEL + " Msplat terminal ready.\n$ Browse/export a dataset, then Run Msplat. Older datasets are auto-upgraded with COLMAP binary sparse metadata.\n$ Sparse status: " + SPLATVIZ_RELEASE_LABEL + " exports robot-only COLMAP seed tracks; clean render forces performer visible and splat preview hidden.\n$ Progress follows step logs plus child CPU/mem health; save/eval finalization can be quiet for several minutes.\n"
	terminal_box.add_child(msplat_terminal_label)
	_update_msplat_terminal_header()

func _build_camera_pov_preview(root: Control, screen_size: Vector2) -> void:
	# M66D: exact aspect-fit Camera POV preview. This is separate from the orbit viewport
	# so the preview can match 1920×1080 clean renders even when the app viewport is not 16:9.
	camera_pov_subviewport = SubViewport.new()
	camera_pov_subviewport.name = "M66D Camera POV exact 16x9 SubViewport"
	camera_pov_subviewport.size = CLEAN_RENDER_SIZE
	camera_pov_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	camera_pov_subviewport.world_3d = get_viewport().world_3d
	camera_pov_subviewport.disable_3d = false
	add_child(camera_pov_subviewport)

	camera_pov_render_camera = Camera3D.new()
	camera_pov_render_camera.name = "M66D Camera POV render camera"
	camera_pov_subviewport.add_child(camera_pov_render_camera)
	camera_pov_render_camera.current = true

	camera_pov_preview_panel = PanelContainer.new()
	camera_pov_preview_panel.visible = false
	camera_pov_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_pov_preview_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.0, 0.0, 0.0, 0.0)))
	root.add_child(camera_pov_preview_panel)

	camera_pov_texture_rect = TextureRect.new()
	camera_pov_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera_pov_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camera_pov_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	camera_pov_preview_panel.add_child(camera_pov_texture_rect)
	camera_pov_texture_rect.texture = camera_pov_subviewport.get_texture()

	camera_pov_status_label = Label.new()
	camera_pov_status_label.position = Vector2(18, 16)
	camera_pov_status_label.size = Vector2(860, 28)
	camera_pov_status_label.add_theme_font_size_override("font_size", 15)
	camera_pov_status_label.add_theme_color_override("font_color", Color(0.92, 1.0, 0.92))
	camera_pov_status_label.text = "Camera POV"
	camera_pov_preview_panel.add_child(camera_pov_status_label)

	camera_pov_prev_button = Button.new()
	camera_pov_prev_button.text = "Previous Camera"
	camera_pov_prev_button.position = Vector2(18, 50)
	camera_pov_prev_button.size = Vector2(146, 34)
	camera_pov_prev_button.focus_mode = Control.FOCUS_NONE
	camera_pov_prev_button.mouse_filter = Control.MOUSE_FILTER_STOP
	camera_pov_prev_button.pressed.connect(func(): _select_prev_camera())
	camera_pov_preview_panel.add_child(camera_pov_prev_button)

	camera_pov_next_button = Button.new()
	camera_pov_next_button.text = "Next Camera"
	camera_pov_next_button.position = Vector2(174, 50)
	camera_pov_next_button.size = Vector2(130, 34)
	camera_pov_next_button.focus_mode = Control.FOCUS_NONE
	camera_pov_next_button.mouse_filter = Control.MOUSE_FILTER_STOP
	camera_pov_next_button.pressed.connect(func(): _select_next_camera())
	camera_pov_preview_panel.add_child(camera_pov_next_button)

func _build_nav_legend(root: Control) -> void:
	# M67F: draggable navigation helper, minimize-only. Press H to minimize/expand.
	nav_legend_panel = PanelContainer.new()
	nav_legend_panel.visible = true
	nav_legend_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	nav_legend_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.010, 0.030, 0.034, 0.88)))
	root.add_child(nav_legend_panel)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	nav_legend_panel.add_child(vb)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(event): _m67f_nav_legend_gui_input(event))
	vb.add_child(row)
	var title: Label = Label.new()
	title.text = "Navigation"
	title.custom_minimum_size = Vector2(158, 24)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.68, 1.0, 0.82))
	row.add_child(title)
	var min_btn: Button = Button.new()
	min_btn.text = "–"
	min_btn.custom_minimum_size = Vector2(28, 24)
	min_btn.focus_mode = Control.FOCUS_NONE
	min_btn.pressed.connect(func(): _m67f_toggle_nav_minimized())
	row.add_child(min_btn)
	var body: Label = Label.new()
	body.name = "M67FNavLegendBody"
	body.text = "Pinch / wheel: zoom
Two-finger drag: pan
Left drag: orbit
Shift+drag: pan
Q/E: up/down · F: frame
R: reset · H: minimize/expand
[ / ]: previous / next camera
Drag this helper by its title"
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.82, 0.94, 0.88))
	body.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(body)
	_m67f_apply_nav_minimized()

func _hide_nav_legend() -> void:
	_m67f_set_nav_minimized(true)

func _toggle_nav_legend() -> void:
	_m67f_toggle_nav_minimized()

func _reset_current_view() -> void:
	if mode == "Splat View" and latest_ply_path != "":
		# Reuse the loaded PLY's current robust framing by reloading the preview only.
		_load_ply_point_cloud(latest_ply_path)
		_set_mode("Splat View")
	elif mode == "Camera POV":
		_camera_pov()
	else:
		_preset_perspective()

func _m66d_layout_camera_pov_preview(s: Vector2) -> void:
	if camera_pov_preview_panel == null:
		return
	var right_w: float = _right_panel_width()
	var x0: float = LEFT_PANEL_W + 18
	var y0: float = TOP_BAR_H + 18
	var avail_w: float = max(240.0, s.x - LEFT_PANEL_W - right_w - 36)
	var avail_h: float = max(180.0, s.y - TOP_BAR_H - 36)
	var panel_w: float = min(avail_w, avail_h * 16.0 / 9.0)
	var panel_h: float = panel_w * 9.0 / 16.0
	if panel_h > avail_h:
		panel_h = avail_h
		panel_w = panel_h * 16.0 / 9.0
	camera_pov_preview_panel.position = Vector2(x0 + (avail_w - panel_w) * 0.5, y0 + (avail_h - panel_h) * 0.5)
	camera_pov_preview_panel.size = Vector2(panel_w, panel_h)
	if camera_pov_status_label != null:
		camera_pov_status_label.position = Vector2(18, 14)
		camera_pov_status_label.size = Vector2(max(180.0, panel_w - 36.0), 28)
	if camera_pov_prev_button != null:
		camera_pov_prev_button.size = Vector2(150, 36)
		camera_pov_prev_button.position = Vector2(18, clamp(panel_h * 0.5 - 18.0, 56.0, max(56.0, panel_h - 54.0)))
	if camera_pov_next_button != null:
		camera_pov_next_button.size = Vector2(136, 36)
		camera_pov_next_button.position = Vector2(max(18.0, panel_w - camera_pov_next_button.size.x - 18.0), clamp(panel_h * 0.5 - 18.0, 56.0, max(56.0, panel_h - 54.0)))

func _update_comparison_panel() -> void:
	if comparison_label == null:
		return
	comparison_label.text = "ANGLE DENSITY\n"
	comparison_label.text += "• Lean 16-Camera Msplat: max gap ≈ 22.5°. Use for Msplat runs only; weak for full-body performer reconstruction hypotheses.\n"
	comparison_label.text += "• Recommended 24-Camera Baseline: max gap ≈ 15°. Plausible baseline; validate with clean renders before trusting lower resolutions.\n"
	comparison_label.text += "• Premium 36-Camera Multi-Tier: max gap ≈ 10°. Stronger low/mid/high angular density; inspect same-tier neighbor redundancy.\n\n"
	comparison_label.text += "RESOLUTION DECISION\n"
	comparison_label.text += "6K is the current reference. 5K is the first data-reduction candidate at ~13–14 ft if msplat/gsplat validation holds. 4K remains a test candidate, not a planning assumption, unless cameras move closer or reconstruction metrics support it.\n\n"
	comparison_label.text += "ROLL STRATEGY\n"
	comparison_label.text += "Use portrait where vertical face/body detail or motion margin is the priority. Use landscape where horizontal parallax continuity and crop safety are the priority. The current mixed roll assignment is a heuristic, now reported per camera.\n\n"
	comparison_label.text += "REDUNDANCY POLICY\n"
	comparison_label.text += "Flag near-identical same-tier neighbors as candidates to reassign. Do not treat redundancy as automatic removal; it may still protect hands, hair, wardrobe, instruments, or occlusion."


func _open_msplat_window() -> void:
	_update_msplat_terminal_header()
	_refresh_msplat_terminal(false)
	if msplat_window != null:
		msplat_window.visible = true
		msplat_window.popup_centered_ratio(0.72)
	if status_label:
		status_label.text = "Msplat Terminal opened in a separate window. Use Browse Dataset Folder… for an existing SplatViz render set."

func _show_help() -> void:
	var dlg = AcceptDialog.new()
	dlg.title = "SplatViz Help"
	dlg.size = Vector2(780, 620)
	dlg.min_size = Vector2(640, 480)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	dlg.add_child(margin)
	var label = RichTextLabel.new()
	label.fit_content = true
	label.bbcode_enabled = false
	label.text = "SplatViz Help

Navigation
• Wheel / pinch: zoom
• Left drag: orbit
• Shift + drag or middle/two-finger drag: pan
• WASD/arrows: move floor-plane pivot
• Q / E: vertical pan
• F: frame selected camera
• [ / ]: previous / next camera when focus is not in a text field
• H: minimize/expand the draggable navigation helper

Rendering
• Render Cameras… asks 1080p or 4K.
• Render Selected Camera… asks 1080p or 4K.
• Frame policy: preserve camera frame, scale only, no crop, no squeeze.

Layout export
• Export Layout Report… asks for a destination folder.
• The report writes HTML, SVG diagrams, CSV, JSON, and clean per-camera contact renders.
• Contact renders are exact camera outputs at 16:9 report resolution, with no crop, squeeze, or letterboxing.

Diagnostics
• Project history is an internal JSON ledger for run notes and metrics. It is not a user-facing camera layout report."
	margin.add_child(label)
	add_child(dlg)
	dlg.popup_centered()

func _on_msplat_iters_selected(idx: int) -> void:
	var values = [1500, 5000, 10000, 30000]
	idx = clamp(idx, 0, values.size() - 1)
	msplat_num_iters = int(values[idx])
	_update_msplat_terminal_header()
	_append_msplat_terminal("$ Training iterations set to " + str(msplat_num_iters))

func _browse_ply_file() -> void:
	if ply_import_dialog != null:
		var start_dir = msplat_result_root if msplat_result_root != "" else export_root_path
		ply_import_dialog.current_dir = start_dir
		ply_import_dialog.popup_centered_ratio(0.62)

func _fit_to_loaded_splat() -> void:
	if latest_ply_path == "" or not FileAccess.file_exists(latest_ply_path):
		if status_label != null:
			status_label.text = "No loaded PLY to fit. Import a PLY or load the latest msplat result first."
		return
	var count = _load_ply_point_cloud(latest_ply_path)
	_set_mode("Splat View")
	if status_label != null:
		status_label.text = "Fit to loaded splat: " + latest_ply_path + " · visible points " + str(count) + " · " + latest_ply_summary

func _reset_splat_view() -> void:
	_preset_perspective()
	if status_label != null:
		status_label.text = "Splat View orbit reset. Use Fit To Splat to refocus the loaded preview."

func _import_ply_file(path: String) -> void:
	if path == "":
		return
	latest_ply_path = path
	var count = _load_ply_point_cloud(path)
	_set_mode("Splat View")
	if status_label:
		status_label.text = "Imported PLY preview: " + path + " · visible points " + str(count) + " · " + latest_ply_summary
	if msplat_terminal_label:
		_append_msplat_terminal("$ Imported PLY preview: " + path + " (" + str(count) + " visible points) " + latest_ply_summary)

func _apply_mode_visibility() -> void:
	var splat_view = mode == "Splat View"
	var camera_clean_view = mode == "Camera POV"
	if camera_clean_view:
		_m66d_apply_scene_visibility(_m66d_capture_visibility_policy())
		return
	if camera_root != null:
		camera_root.visible = not splat_view
	if stage_root != null:
		stage_root.visible = not splat_view
	if rig_root != null:
		rig_root.visible = not splat_view
	if overlay_root != null:
		overlay_root.visible = not splat_view
	# M6.5A: Splat View is reserved for imported/reconstructed PLY results. Hide source robot.
	if performer_root != null:
		performer_root.visible = not splat_view
	if focus_envelope_root != null and splat_view:
		focus_envelope_root.visible = false
	if splat_root != null:
		splat_root.visible = splat_view

func _msplat_panel_size(s: Vector2) -> Vector2:
	var w = max(640.0, s.x - LEFT_PANEL_W - _right_panel_width() - 48)
	var h = 330.0
	return Vector2(w, min(h, max(260.0, s.y - TOP_BAR_H - 36)))

func _msplat_panel_position(s: Vector2) -> Vector2:
	var panel_size = _msplat_panel_size(s)
	return Vector2(LEFT_PANEL_W + 24, max(TOP_BAR_H + 16, s.y - panel_size.y - 16))

func _panel_style(color: Color = Color(0.018, 0.065, 0.060, 0.92), arg2 = null, arg3 = null, arg4 = null) -> StyleBoxFlat:
	# M67G2: flexible compatibility wrapper.
	# Supports older calls:
	#   _panel_style()
	#   _panel_style(bg_color)
	# and newer stacked M67G calls:
	#   _panel_style(bg_color, radius, border_width)
	#   _panel_style(bg_color, border_color, border_width)
	#   _panel_style(bg_color, border_color, border_width, radius)
	var border_col: Color = Color(0.09, 0.62, 0.58, 0.68)
	var radius: int = 8
	var border_width: int = 1

	if arg2 != null:
		if typeof(arg2) == TYPE_COLOR:
			border_col = arg2
		elif typeof(arg2) == TYPE_INT or typeof(arg2) == TYPE_FLOAT:
			radius = int(arg2)

	if arg3 != null:
		if typeof(arg3) == TYPE_COLOR:
			border_col = arg3
		elif typeof(arg3) == TYPE_INT or typeof(arg3) == TYPE_FLOAT:
			border_width = int(arg3)

	if arg4 != null:
		if typeof(arg4) == TYPE_INT or typeof(arg4) == TYPE_FLOAT:
			radius = int(arg4)
		elif typeof(arg4) == TYPE_COLOR:
			border_col = arg4

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border_col
	sb.border_width_left = border_width
	sb.border_width_top = border_width
	sb.border_width_right = border_width
	sb.border_width_bottom = border_width
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	return sb
func _add_toolbar_label(parent: Node, text: String, size: int, color: Color, min_w: float) -> Label:
	var l = Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(min_w, 28)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(l)
	return l

func _add_toolbar_button(parent: Node, text: String, cb: Callable, min_w: float) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 36)
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _add_label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _add_button(parent: Node, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(130, 32)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _add_abs_button(parent: Node, text: String, pos: Vector2, sz: Vector2, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", 14)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _on_show_all_frustums_toggled(pressed: bool) -> void:
	splat_all_frustums = pressed
	if mode == "Splat Viability" or mode == "Rigging / Lighting" or mode == "Edit Camera":
		_rebuild_overlays()
	_update_inspector()

func _on_splat_show_bounds_toggled(pressed: bool) -> void:
	latest_ply_show_bounds = pressed
	if latest_ply_path != "" and FileAccess.file_exists(latest_ply_path):
		_load_ply_point_cloud(latest_ply_path)
		_set_mode("Splat View")

func _on_splat_show_capture_bounds_toggled(pressed: bool) -> void:
	latest_ply_show_capture_bounds = pressed
	if latest_ply_path != "" and FileAccess.file_exists(latest_ply_path):
		_load_ply_point_cloud(latest_ply_path)
		_set_mode("Splat View")

func _choose_export_folder() -> void:
	if export_dialog != null:
		export_dialog.popup_centered_ratio(0.55)

func _set_export_folder(dir: String) -> void:
	export_root_path = dir
	_update_export_label()
	if status_label:
		status_label.text = "Export folder set: " + export_root_path

func _update_export_label() -> void:
	if export_path_label != null:
		export_path_label.text = "Export folder:\n" + export_root_path

func _toggle_inspector() -> void:
	_m68a_set_inspector_visible(not inspector_visible)

func _on_layout_selected(idx: int) -> void:
	if layout_option != null and idx >= 0 and idx < layout_option.item_count:
		_set_layout(layout_option.get_item_text(idx))
	_update_prediction()

func _apply_selected_camera_position(new_pos: Vector3) -> void:
	if cameras.is_empty():
		return
	new_pos.y = clamp(new_pos.y, 0.35, 3.85)
	var c = cameras[selected_index]
	c["position"] = new_pos
	c = _m67h_refresh_camera_layout_fields(c)
	c["mount"] = _mount_zone_for_angle(deg_to_rad(float(c["azimuth_deg"])), str(c["tier"]))
	cameras[selected_index] = c
	installation_mode = _m67h_installation_mode()
	var node = camera_nodes[selected_index] as Node3D
	if node != null:
		node.position = new_pos
		node.look_at(_m67h_camera_aim_target(c), Vector3.UP)
	_rebuild_camera_dropdown()
	_rebuild_overlays()
	_update_inspector()
	if edit_status_label != null:
		edit_status_label.text = "Edited " + str(c["id"]) + ": " + _meters_feet(float(c["focus_m"])) + " · %.2f px/cm" % float(c["px_cm"])

func _nudge_selected_camera(kind: String) -> void:
	if cameras.is_empty():
		return
	var c = cameras[selected_index]
	var pos: Vector3 = c["position"] as Vector3
	var horizontal = Vector3(pos.x, 0, pos.z)
	var radial = horizontal.normalized() if horizontal.length() > 0.001 else Vector3(1,0,0)
	if kind == "in":
		pos -= radial * 0.25
	elif kind == "out":
		pos += radial * 0.25
	elif kind == "up":
		pos.y += 0.15
	elif kind == "down":
		pos.y -= 0.15
	elif kind == "az_left" or kind == "az_right":
		var ang = atan2(pos.z, pos.x) + deg_to_rad(-2.0 if kind == "az_left" else 2.0)
		var r = horizontal.length()
		pos.x = cos(ang) * r
		pos.z = sin(ang) * r
	elif kind == "roll":
		c["portrait"] = not bool(c["portrait"])
		c = _m67h_refresh_camera_layout_fields(c)
		cameras[selected_index] = c
		var roll_node = camera_nodes[selected_index] as Node3D
		if roll_node != null:
			roll_node.look_at(_m67h_camera_aim_target(c), Vector3.UP)
		_rebuild_camera_dropdown()
		_rebuild_overlays()
		_update_inspector()
		return
	_apply_selected_camera_position(pos)

func _format_vec3(v: Vector3) -> String:
	return "X %.2fm · Y %.2fm · Z %.2fm" % [v.x, v.y, v.z]

func _layout_ui() -> void:
	var s = get_viewport().get_visible_rect().size
	if top_bar != null:
		top_bar.position = Vector2(0, 0)
		top_bar.size = Vector2(s.x, TOP_BAR_H)
	if left_panel != null:
		left_panel.position = Vector2(0, TOP_BAR_H)
		left_panel.size = Vector2(_m67c_left_panel_width(), max(1.0, s.y - TOP_BAR_H))
	if right_panel != null:
		right_panel.position = Vector2(s.x - RIGHT_PANEL_W, TOP_BAR_H)
		right_panel.size = Vector2(RIGHT_PANEL_W, max(1.0, s.y - TOP_BAR_H))
	if inspector_toggle_button != null:
		inspector_toggle_button.position = Vector2(s.x - RIGHT_PANEL_W - 112, TOP_BAR_H + 8) if inspector_visible else Vector2(s.x - 138, TOP_BAR_H + 8)
	if prev_cam_button != null:
		prev_cam_button.position = Vector2(_m67c_left_panel_width() + 12, s.y * 0.48)
	if next_cam_button != null:
		next_cam_button.position = Vector2(s.x - _right_panel_width() - 68, s.y * 0.48)
	if focus_readout_panel != null:
		focus_readout_panel.position = Vector2(s.x - _right_panel_width() - 590, s.y - 252)
	if m67b_splat_tools_panel != null:
		m67b_splat_tools_panel.position = Vector2(max(LEFT_PANEL_W + 24, s.x - _right_panel_width() - 318), TOP_BAR_H + 16)
	if comparison_panel != null:
		comparison_panel.position = Vector2(LEFT_PANEL_W + 24, TOP_BAR_H + 24)
		comparison_panel.size = Vector2(max(520.0, s.x - LEFT_PANEL_W - _right_panel_width() - 48), 335)
	# M66D layout camera POV and nav legend.
	_m66d_layout_camera_pov_preview(s)
	_m67f_layout_nav_legend()
	# Msplat terminal lives in its own Window in M3.5; no stage overlay layout needed.


func _set_mode(new_mode: String) -> void:
	mode = new_mode
	camera_pov_active = mode == "Camera POV"
	if comparison_panel != null:
		comparison_panel.visible = mode == "Comparison"
	if m67b_splat_tools_panel != null:
		m67b_splat_tools_panel.visible = mode == "Splat View"
	# Msplat is a separate window, not an overlay mode.
	if mode_label:
		mode_label.text = "Mode: " + mode
	# M66D camera POV preview panel visibility.
	if camera_pov_preview_panel != null:
		camera_pov_preview_panel.visible = camera_pov_active
	if camera_pov_active:
		_camera_pov()
	else:
		_rebuild_overlays()
	_apply_mode_visibility()
	_update_prediction()
	_update_inspector()
	_m67f_update_focus_legend()
	_m68a_update_camera_nav_ui()


func _m67b_toggle_analysis() -> void:
	if mode == "Comparison":
		_set_mode("Focus")
	else:
		_set_mode("Comparison")

func _m67b_build_render_dialog() -> void:
	if m67b_render_dialog != null:
		return
	m67b_render_dialog = Window.new()
	m67b_render_dialog.title = "Render Cameras"
	m67b_render_dialog.size = Vector2i(440, 245)
	m67b_render_dialog.min_size = Vector2i(420, 220)
	m67b_render_dialog.visible = false
	m67b_render_dialog.close_requested.connect(func(): m67b_render_dialog.visible = false)
	add_child(m67b_render_dialog)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012,0.04,0.045,0.98)))
	m67b_render_dialog.add_child(panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	_add_label(vb, "Render Cameras", 22, Color(0.68,1.0,0.82))
	_add_label(vb, "Choose output resolution. Frame policy is fixed: preserve camera frame, no crop, no squeeze.", 14, Color(0.82,0.93,0.89))
	_add_button(vb, "1080p / 1920×1080", func(): _m67b_render_from_dialog(Vector2i(1920, 1080)))
	_add_button(vb, "4K / 3840×2160", func(): _m67b_render_from_dialog(Vector2i(3840, 2160)))
	_add_button(vb, "Cancel", func(): m67b_render_dialog.visible = false)

func _m67b_build_splat_view_tools(root: Control, screen_size: Vector2) -> void:
	if m67b_splat_tools_panel != null:
		return
	m67b_splat_tools_panel = PanelContainer.new()
	m67b_splat_tools_panel.position = Vector2(max(LEFT_PANEL_W + 24, screen_size.x - _right_panel_width() - 318), TOP_BAR_H + 16)
	m67b_splat_tools_panel.size = Vector2(318, 320)
	m67b_splat_tools_panel.visible = false
	m67b_splat_tools_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	m67b_splat_tools_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012,0.04,0.045,0.92)))
	root.add_child(m67b_splat_tools_panel)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	m67b_splat_tools_panel.add_child(vb)
	_add_label(vb, "Splat View Tools", 18, Color(0.68,1.0,0.82))
	_add_button(vb, "Import PLY…", func(): _browse_ply_file())
	_add_button(vb, "Load Latest Splat", func(): _load_latest_msplat_result())
	_add_button(vb, "Fit To Splat", func(): _fit_to_loaded_splat())
	_add_button(vb, "Reset View", func(): _reset_splat_view())
	splat_show_bounds_toggle = CheckButton.new()
	splat_show_bounds_toggle.text = "Show PLY Bounds"
	splat_show_bounds_toggle.button_pressed = latest_ply_show_bounds
	splat_show_bounds_toggle.toggled.connect(func(pressed: bool): _on_splat_show_bounds_toggled(pressed))
	vb.add_child(splat_show_bounds_toggle)
	splat_show_capture_bounds_toggle = CheckButton.new()
	splat_show_capture_bounds_toggle.text = "Show Capture/Subject Bounds"
	splat_show_capture_bounds_toggle.button_pressed = latest_ply_show_capture_bounds
	splat_show_capture_bounds_toggle.toggled.connect(func(pressed: bool): _on_splat_show_capture_bounds_toggled(pressed))
	vb.add_child(splat_show_capture_bounds_toggle)
	_add_label(vb, "Debug point preview — not final anisotropic 3DGS rasterization.", 12, Color(0.82, 0.93, 0.89))

func _m67b_open_render_cams_dialog(selected_only: bool) -> void:
	m67b_render_selected_only = selected_only
	if m67b_render_dialog == null:
		_m67b_build_render_dialog()
	if m67b_render_dialog != null:
		m67b_render_dialog.title = "Render Selected Camera" if selected_only else "Render Cameras"
		m67b_render_dialog.popup_centered(Vector2i(440, 245))

func _m67b_render_from_dialog(size: Vector2i) -> void:
	if m67b_render_dialog != null:
		m67b_render_dialog.visible = false
	if m67b_render_selected_only:
		await _m67b_render_selected_camera_size(size)
	else:
		await _m67b_render_all_cameras_size(size)

func _m67b_render_tag(size: Vector2i) -> String:
	if size.x == 3840 and size.y == 2160:
		return "4k"
	return "1080p"

func _m67b_render_selected_camera_size(size: Vector2i) -> void:
	if cameras.is_empty():
		return
	var c: Dictionary = cameras[selected_index]
	var tag: String = _m67b_render_tag(size)
	var export_timestamp := _m68a_timestamp()
	var out_root: String = _m68a_make_timestamped_output_root("splatviz_render_selected_" + SPLATVIZ_EXPORT_TAG + "_" + tag, export_timestamp)
	var out_dir: String = out_root + "/images/" + str(c["id"])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path: String = out_dir + "/" + _camera_unique_filename(c)
	await _render_camera_to_path(c, path, size, true)
	_write_render_manifest(out_root, [c], size, true, export_timestamp)
	if status_label != null:
		status_label.text = "Rendered selected camera " + str(c["id"]) + " at " + str(size.x) + "×" + str(size.y) + ": " + path

func _m67b_render_all_cameras_size(size: Vector2i) -> void:
	var tag: String = _m67b_render_tag(size)
	var export_timestamp := _m68a_timestamp()
	var out_root: String = _m68a_make_timestamped_output_root("splatviz_render_all_" + SPLATVIZ_EXPORT_TAG + "_" + tag, export_timestamp)
	var root: String = out_root + "/images"
	DirAccess.make_dir_recursive_absolute(root)
	for i: int in range(cameras.size()):
		var c: Dictionary = cameras[i]
		var out_dir: String = root + "/" + str(c["id"])
		DirAccess.make_dir_recursive_absolute(out_dir)
		await _render_camera_to_path(c, out_dir + "/" + _camera_unique_filename(c), size, true)
	_write_render_manifest(out_root, cameras, size, true, export_timestamp)
	if status_label != null:
		status_label.text = "Rendered " + str(cameras.size()) + " cameras at " + str(size.x) + "×" + str(size.y) + " to: " + root

func _m67b_stamp() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [int(dt["year"]), int(dt["month"]), int(dt["day"]), int(dt["hour"]), int(dt["minute"]), int(dt["second"])]

func _m67b_ft(v_m: float) -> float:
	return v_m / FT_TO_M

func _m67b_csv_escape(v: String) -> String:
	return "\"" + v.replace("\"", "\"\"") + "\""

func _m67b_layout_camera_entries() -> Array:
	var entries: Array = []
	for i: int in range(cameras.size()):
		var c: Dictionary = cameras[i]
		var pos: Vector3 = c["position"] as Vector3
		var floor_dist: float = Vector2(pos.x, pos.z).length()
		var dist3d: float = pos.distance_to(TARGET)
		var tilt_deg: float = rad_to_deg(atan2(TARGET.y - pos.y, max(0.001, floor_dist)))
		entries.append({
			"camera_id": str(c["id"]),
			"tier": str(c.get("tier", "")),
			"lens": "Rokinon 24mm T5.6",
			"resolution_px": [1920, 1080],
			"hfov_deg": 55.7,
			"vfov_deg": 33.1,
			"position_m": [pos.x, pos.y, pos.z],
			"position_ft": [_m67b_ft(pos.x), _m67b_ft(pos.y), _m67b_ft(pos.z)],
			"height_from_floor_m": pos.y,
			"height_from_floor_ft": _m67b_ft(pos.y),
			"floor_distance_m": floor_dist,
			"floor_distance_ft": _m67b_ft(floor_dist),
			"distance_3d_m": dist3d,
			"distance_3d_ft": _m67b_ft(dist3d),
			"azimuth_deg": float(c.get("azimuth_deg", 0.0)),
			"tilt_pitch_deg": tilt_deg,
			"portrait_roll": bool(c.get("portrait", false)),
			"target_m": [TARGET.x, TARGET.y, TARGET.z],
			"construction_note": "Measure from camera sensor/film plane to subject target. Use exported X/Y/Z as SplatViz stage coordinates."
		})
	return entries

func _m67b_write_text(path: String, txt: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(txt)
		f.close()

func _m67b_export_layout_report() -> void:
	_prompt_external_layout_report()

func _m67b_layout_report_html(entries: Array, stamp: String) -> String:
	var html: String = "<!doctype html><html><head><meta charset='utf-8'><title>SplatViz Camera Layout</title>"
	html += "<style>body{font-family:-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif;background:#081112;color:#eafff1;margin:32px} .page{page-break-after:always;min-height:900px} table{border-collapse:collapse;width:100%;font-size:12px} td,th{border:1px solid #2a6666;padding:5px;text-align:left} h1,h2{color:#9fffc4}.card{border:1px solid #2a6666;padding:12px;margin:8px;border-radius:8px;display:inline-block;width:210px;vertical-align:top} svg{background:#041010;border:1px solid #2a6666}</style></head><body>"
	html += "<section class='page'><h1>" + SPLATVIZ_RELEASE_LABEL + " Camera Layout Report</h1><p>Created " + stamp + ". Layout: " + layout_name + ". Stage: %.2fm × %.2fm.</p>" % [STAGE_W_M, STAGE_D_M]
	html += "<p>Purpose: construction-facing camera placement record. Coordinates are SplatViz stage coordinates; measure camera placement from camera sensor/film plane.</p>"
	html += "<table><tr><th>Cam</th><th>Tier</th><th>Lens</th><th>X/Y/Z m</th><th>X/Y/Z ft</th><th>Height</th><th>Floor dist</th><th>3D dist</th><th>Az</th><th>Tilt</th></tr>"
	for e_any in entries:
		var e: Dictionary = e_any
		var pm: Array = e["position_m"]
		var pf: Array = e["position_ft"]
		html += "<tr><td>%s</td><td>%s</td><td>%s</td><td>%.2f / %.2f / %.2f</td><td>%.2f / %.2f / %.2f</td><td>%.2fm / %.2fft</td><td>%.2fm / %.2fft</td><td>%.2fm / %.2fft</td><td>%.1f°</td><td>%.1f°</td></tr>" % [str(e["camera_id"]), str(e["tier"]), str(e["lens"]), float(pm[0]), float(pm[1]), float(pm[2]), float(pf[0]), float(pf[1]), float(pf[2]), float(e["height_from_floor_m"]), float(e["height_from_floor_ft"]), float(e["floor_distance_m"]), float(e["floor_distance_ft"]), float(e["distance_3d_m"]), float(e["distance_3d_ft"]), float(e["azimuth_deg"]), float(e["tilt_pitch_deg"])]
	html += "</table></section>"
	html += "<section class='page'><h2>Blueprint Layout — Top View + Elevation</h2>" + _m67b_svg_top(entries) + "<br><br>" + _m67b_svg_elevation(entries) + "</section>"
	html += "<section class='page'><h2>Camera Contact Sheet / Rig Notes</h2>"
	for e_any in entries:
		var e: Dictionary = e_any
		html += "<div class='card'><b>%s</b><br>%s<br>Height %.2fm / %.2fft<br>Floor %.2fm / %.2fft<br>Az %.1f° · Tilt %.1f°</div>" % [str(e["camera_id"]), str(e["tier"]), float(e["height_from_floor_m"]), float(e["height_from_floor_ft"]), float(e["floor_distance_m"]), float(e["floor_distance_ft"]), float(e["azimuth_deg"]), float(e["tilt_pitch_deg"])]
	html += "</section></body></html>"
	return html

func _m67b_svg_top(entries: Array) -> String:
	var svg: String = "<svg width='900' height='560' viewBox='0 0 900 560'><text x='20' y='30' fill='#9fffc4'>Top View: X/Z camera positions around subject</text><rect x='120' y='70' width='660' height='420' fill='none' stroke='#1b8a8a'/><circle cx='450' cy='280' r='12' fill='#eafff1'/><text x='466' y='285' fill='#eafff1'>Subject</text>"
	for e_any in entries:
		var e: Dictionary = e_any
		var pm: Array = e["position_m"]
		var x: float = 450.0 + float(pm[0]) * 42.0
		var y: float = 280.0 + float(pm[2]) * 42.0
		svg += "<line x1='450' y1='280' x2='%.1f' y2='%.1f' stroke='#285f66' stroke-width='1'/><circle cx='%.1f' cy='%.1f' r='6' fill='#ffb02e'/><text x='%.1f' y='%.1f' fill='#eafff1' font-size='11'>%s</text>" % [x, y, x, y, x + 8.0, y + 4.0, str(e["camera_id"])]
	svg += "</svg>"
	return svg

func _m67b_svg_elevation(entries: Array) -> String:
	var svg: String = "<svg width='900' height='360' viewBox='0 0 900 360'><text x='20' y='30' fill='#9fffc4'>Side Elevation: floor distance vs height</text><line x1='60' y1='300' x2='840' y2='300' stroke='#1b8a8a'/><rect x='432' y='160' width='36' height='140' fill='none' stroke='#eafff1'/><text x='474' y='190' fill='#eafff1'>Subject</text>"
	for e_any in entries:
		var e: Dictionary = e_any
		var x: float = 450.0 + float(e["floor_distance_m"]) * 34.0
		var y: float = 300.0 - float(e["height_from_floor_m"]) * 70.0
		if x > 840.0:
			x = 840.0
		svg += "<circle cx='%.1f' cy='%.1f' r='5' fill='#ffb02e'/><text x='%.1f' y='%.1f' fill='#eafff1' font-size='10'>%s</text>" % [x, y, x + 7.0, y + 3.0, str(e["camera_id"])]
	svg += "</svg>"
	return svg


func _update_prediction() -> void:
	if prediction_label == null:
		return
	var count = cameras.size()
	var msg = "Prediction status: SplatViz hypotheses require gsplat validation. Msplat is a local run option only.\n"
	if count == 16:
		msg += "16 cameras: useful Msplat run, but weak for full-body performer hypothesis. Max angular gap ≈ 22.5°; target gap is ≤15° before calling a layout production-safe."
	elif count == 24:
		msg += "24 cameras: plausible baseline. Looks resolved visually, but validation still requires rendered stills + gsplat holdout tests."
	else:
		msg += "36 cameras: stronger angle-density candidate with low/mid/high tiers. Still check redundant same-neighborhood overlap and mount feasibility."
	prediction_label.text = msg

func _update_focus_readout() -> void:
	if focus_readout_panel == null or focus_readout_label == null:
		return
	var visible_modes = ["Focus", "Splat Viability", "Splat View"]
	focus_readout_panel.visible = visible_modes.has(mode)
	if cameras.is_empty() or not visible_modes.has(mode):
		return
	var c = cameras[selected_index]
	var fd = float(c["focus_m"])
	if mode == "Focus":
		focus_readout_label.text = "FOCUS READOUT  " + str(c["id"]) + "\n"
		focus_readout_label.text += "Color key: ORANGE too near · YELLOW acceptable · GREEN critical sharpness\n"
		focus_readout_label.text += "Distance: " + _meters_feet(fd) + "\n"
		focus_readout_label.text += "Critical sharpness band: " + _meters_feet(max(0.4, fd - 0.55)) + " to " + _meters_feet(fd + 0.55) + "\n"
		focus_readout_label.text += "DoF @ T5.6: 8 ft 3 in / 2.52 m to 46 ft 11 in / 14.30 m\n"
		focus_readout_label.text += "Target: eye plane / performer center; measure from KOMODO-X film plane."
	elif mode == "Splat Viability":
		var gap = _camera_gap_degrees()
		focus_readout_label.text = "SPLAT VIABILITY READOUT  " + str(c["id"]) + "\n"
		focus_readout_label.text += "Frustum key: selected camera is bright; neighbor / layout context is transparent.\n"
		focus_readout_label.text += "White cross-hatch = weak contribution sector; add/reassign view.\n"
		focus_readout_label.text += "Current max angular gap ≈ %.1f°. Target ≤ 15° for baseline production hypothesis.\n" % gap
		focus_readout_label.text += _redundancy_summary()
	else:
		focus_readout_label.text = "SPLAT VIEW\n"
		focus_readout_label.text += "Source robot, cameras, frustums, rig proxies, and focus overlays are hidden in this mode.\n"
		if latest_ply_path == "":
			focus_readout_label.text += "PLY: none loaded yet. Import a PLY or run Msplat, then Load Latest Splat.\n"
		else:
			focus_readout_label.text += "PLY: " + latest_ply_path + "\n"
			focus_readout_label.text += "Preview mode: " + latest_ply_preview_mode + "\n"
			focus_readout_label.text += "Count: " + str(latest_ply_valid_points) + " shown\n"
			focus_readout_label.text += _m68a_bounds_summary_lines("PLY bounds", latest_ply_bounds_full) + "\n"
			focus_readout_label.text += latest_ply_provenance_text + "\n"
		focus_readout_label.text += "Debug point preview — not final anisotropic 3DGS rasterization.\n"
		focus_readout_label.text += "Preview camera is fit-to-view; floor alignment is diagnostic only."


func _update_inspector() -> void:
	if cameras.is_empty() or inspector_label == null:
		return
	var c = cameras[selected_index]
	var fd = float(c["focus_m"])
	var text: String = ""
	if mode == "Focus":
		text += "FOCUS NOTES — " + str(c["id"]) + "\n\n"
		text += "Distance to subject\n" + _meters_feet(fd) + "\n\n"
		text += "Sensor / capture\nRED KOMODO-X 6K 16:9\n"
		text += "Lens: Rokinon DSX24-RF 24mm\n"
		text += "Roll: " + ("portrait" if bool(c["portrait"]) else "landscape") + " · hFOV " + ("33.09°" if bool(c["portrait"]) else "58.77°") + "\n"
		text += "Projected detail: %.2f px/cm\n\n" % float(c["px_cm"])
		text += "Recommended focus target\nEyes / performer center. Measure from KOMODO-X film plane.\n\n"
		text += "Optimal sharpness zone @ T5.6\n"
		text += "Near confidence edge: " + _meters_feet(max(0.4, fd - 0.55)) + "\n"
		text += "Far confidence edge: " + _meters_feet(fd + 0.55) + "\n"
		text += "Critical band width: 1.10m / 3.6ft\n\n"
		text += "Depth of Field @ T5.6\nNear: 8 ft 3 in / 2.52 m\nFar: 46 ft 11 in / 14.30 m\nHyperfocal: 19 ft 11 in / 6.07 m\n\n"
		text += "" + _resolution_table(fd) + "\n\n"
		text += _roll_rationale(c) + "\n\n"
		text += "Guidance\nMove inward only if the face/torso needs more critical detail; check camera/stand/truss shadow risk before moving closer."
	elif mode == "Splat Viability":
		text += "SPLAT VIABILITY — " + str(c["id"]) + "\n\n"
		text += "View mode\n" + ("All frustums" if splat_all_frustums else "Selected camera only") + "\n\n"
		text += "Camera\nTier: " + str(c["tier"]) + " · " + ("portrait" if bool(c["portrait"]) else "landscape") + "\n"
		text += "Distance: " + _meters_feet(fd) + "\nProjected detail: %.2f px/cm\n\n" % float(c["px_cm"])
		text += "Assessment\nStatus: prediction only — gsplat validation required. Frustums terminate at the subject so contribution does not cross the scene.\n\n"
		text += _roll_rationale(c) + "\n\n"
		text += "Redundancy\n" + _redundancy_summary() + "\n\n"
		if cameras.size() == 16:
			text += "Angle sufficiency\nWEAK for full-body performer hypothesis. Max angular gap ≈ 22.5°. Add low/up and high/down diversity before trusting this layout."
		elif cameras.size() == 24:
			text += "Angle sufficiency\nPlausible baseline. Looks more complete than 16, but still needs clean stills + gsplat holdout validation."
		else:
			text += "Angle sufficiency\nStrong run candidate. Use validation renders to find redundant same-neighborhood views and missed high/low zones."
	elif mode == "Edit Camera":
		text += "EDIT CAMERA — " + str(c["id"]) + "\n\n"
		text += "Position\n" + _format_vec3(c["position"] as Vector3) + "\n\n"
		text += "Distance / detail\n" + _meters_feet(fd) + "\nProjected detail: %.2f px/cm\n\n" % float(c["px_cm"])
		text += "Controls\nUse the Edit Camera buttons to move inward/outward, adjust azimuth, change height, or toggle portrait/landscape roll.\n\n"
		text += "Planning note\nEvery edit immediately updates focus distance, px/cm, frustum geometry, and the selected camera contribution. Next pass should add a 3D gizmo/drag handle."
	elif mode == "Camera POV":
		text += "CAMERA POV — " + str(c["id"]) + "\n\n"
		text += "The Camera POV preview uses the same camera transform, FOV, roll, and clean-view hiding as exported stills. If it differs from a PNG, treat that as a parity bug.\n\n"
		text += _m66d_camera_capture_summary(c, CLEAN_RENDER_SIZE) + "\n\n"
		text += "Quick navigation\nPrevious / Next buttons wrap camera order and stay at the left/right edges of the frame. Optional shortcuts: [ previous, ] next.\n\n"
		text += "Render output\n" + export_root_path + "/splatviz_clean_*_{timestamp}/images/C##/CAM##_frame_000001.png"
	elif mode == "Rigging / Lighting":
		text += "RIG / LIGHTING — " + str(c["id"]) + "\n\n"
		text += "Mount assumption: " + str(c["mount"]) + "\n"
		text += "Planning proxy only, not final rigging. Evaluate physical attachment, shadows, cable access, and whether moving inward creates lighting problems at T5.6 / ISO 800 / 90° shutter."
	elif mode == "Splat View":
		text += "SPLAT VIEW\n\n"
		text += "Purpose\nInspect an imported Msplat / PLY result on the same NOZ Stage #1 coordinate frame. The source robot is hidden so failed or empty PLY output is obvious.\n\n"
		text += "Loaded PLY\n" + (latest_ply_path if latest_ply_path != "" else "No PLY imported yet. Use Import PLY or Load Latest Splat.") + "\n\n"
		text += "PLY preview stats\n" + (latest_ply_summary if latest_ply_summary != "" else "No PLY stats yet.") + "\n\n"
		text += _m68a_bounds_summary_lines("PLY bounds", latest_ply_bounds_full) + "\n\n"
		if latest_ply_show_capture_bounds:
			text += _m68a_bounds_summary_lines("Capture/subject bounds", _m67h_capture_subject_bounds()) + "\n\n"
		text += "Provenance\n" + latest_ply_provenance_text + "\n\n"
		text += "Interpretation\nDebug point preview — not final anisotropic 3DGS rasterization. Use this view for workflow validation only, not quality judgment. Preview mode: " + latest_ply_preview_mode + ". Preview camera is fit-to-view; floor alignment is diagnostic only.\n\n"
		text += "Sparse / seed cloud\nMsplat is now producing non-zero Gaussians from the SplatViz-authored COLMAP binary sparse bridge. Next bridge: replace the synthetic sparse cloud with known-pose triangulation or COLMAP/GLOMAP for stronger validation."
	elif mode == "Msplat":
		_update_msplat_terminal_header()
		text += "MSPLAT TERMINAL\n\n"
		text += "Purpose\nRun a local Msplat reconstruction from SplatViz synthetic stills, then load splat.ply back onto the same stage.\n\n"
		text += "Dataset\n" + msplat_dataset_root + "\n\n"
		text += "Result\n" + msplat_result_root + "\n\n"
		text += "Workflow\n1. Export Dataset or Find Latest Dataset.\n2. Run Msplat.\n3. Watch train.log in the terminal window.\n4. Load Latest Splat when splat.ply appears.\n\n"
		text += "Validation note\nMsplat is a local reconstruction test. Production layout conclusions still need to track with gsplat."
	elif mode == "Comparison":
		text += "LAYOUT COMPARISON\n\n"
		text += "Status: prediction layer. Use clean renders plus msplat/gsplat validation before production conclusions.\n\n"
		text += "Decision criteria\n• Angular density and vertical tiering\n• Projected detail at selected resolution\n• Focus critical band vs performer motion\n• Mount/shadow feasibility\n• Candidate redundant same-tier neighbors\n\n"
		text += "Current recommendation\nTreat 24 cameras as baseline only after validation. Treat 5K as the first serious data-reduction test. Treat 4K as experimental until a solve confirms acceptable detail."
	else:
		text += "Inspector mode not assigned."
	inspector_label.text = text
	_update_focus_readout()


func _camera_gap_degrees() -> float:
	if cameras.is_empty():
		return 0.0
	return 360.0 / float(cameras.size())

func _resolution_table(fd: float) -> String:
	var px6 = _projected_px_cm(fd, false)
	var px5 = px6 * 5120.0 / 6144.0
	var px4 = px6 * 4096.0 / 6144.0
	var d5_equal6 = fd * 5120.0 / 6144.0
	var d4_equal6 = fd * 4096.0 / 6144.0
	var txt = "Resolution viability at current distance\n"
	txt += "6K 16:9: %.2f px/cm — reference detail\n" % px6
	txt += "5K 16:9: %.2f px/cm — likely viable test candidate; same detail if moved to %s\n" % [px5, _meters_feet(d5_equal6)]
	txt += "4K 16:9: %.2f px/cm — data saver, but requires solve validation; same detail if moved to %s\n" % [px4, _meters_feet(d4_equal6)]
	txt += "Moving closer raises detail but increases camera/stand/truss shadow risk at T5.6 / ISO 800 / 90° shutter."
	return txt

func _roll_rationale(c: Dictionary) -> String:
	var roll = "portrait" if bool(c["portrait"]) else "landscape"
	if roll == "portrait":
		return "Roll rationale: portrait prioritizes vertical body/face detail and standing motion margin, but narrows horizontal FOV and can reduce side-neighbor continuity."
	return "Roll rationale: landscape preserves horizontal parallax and crop safety for neighboring views, but gives less vertical pixel density on the body."

func _redundant_camera_indices() -> Array:
	var result: Array = []
	if cameras.size() < 30:
		return result
	# M2.8 heuristic: same-tier neighboring cameras inside about 12° are candidate redundant views.
	# They may still be useful for occlusion, so mark them as 'candidate redundant', not 'remove'.
	for i in range(cameras.size()):
		var j = (i + 1) % cameras.size()
		if str(cameras[i]["tier"]) == str(cameras[j]["tier"]):
			var a = abs(float(cameras[i]["azimuth_deg"]) - float(cameras[j]["azimuth_deg"]))
			if a > 180.0:
				a = 360.0 - a
			if a <= 12.0:
				if not result.has(i):
					result.append(i)
				if not result.has(j):
					result.append(j)
	return result

func _redundancy_summary() -> String:
	var r = _redundant_camera_indices()
	if r.is_empty():
		return "No candidate redundant same-tier neighbor pairs detected by the current heuristic."
	var ids: Array = []
	for idx in r:
		ids.append(str(cameras[int(idx)]["id"]))
	return "Candidate redundant same-tier neighbors: " + _join_strings(ids, ", ") + ". Reassign before deleting; redundancy can still protect hands, hair, instruments, and wardrobe occlusion."


func _join_strings(values: Array, sep: String) -> String:
	var out = ""
	for i in range(values.size()):
		if i > 0:
			out += sep
		out += str(values[i])
	return out

func _add_redundancy_markers() -> void:
	var inds = _redundant_camera_indices()
	if inds.is_empty():
		return
	var mat_redundant = _mat(Color(1.0, 0.18, 0.13, 0.95), false)
	for idx in inds:
		var c = cameras[int(idx)]
		var pos: Vector3 = c["position"] as Vector3
		var marker = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.16
		marker.mesh = sm
		marker.material_override = mat_redundant
		marker.position = pos + Vector3(0, 0.31, 0)
		marker.name = str(c["id"]) + " candidate redundant marker"
		overlay_root.add_child(marker)

func _m66e_refresh_after_camera_change() -> void:
	selected_index = clamp(selected_index, 0, max(0, cameras.size() - 1))
	if camera_option != null:
		camera_option.selected = selected_index
	_update_camera_highlight()
	_m68a_update_camera_nav_ui()
	if mode == "Camera POV":
		_camera_pov()
	else:
		_rebuild_overlays()
	_update_inspector()

func _select_next_camera() -> void:
	if cameras.is_empty():
		return
	selected_index = (selected_index + 1) % cameras.size()
	_m66e_refresh_after_camera_change()

func _select_prev_camera() -> void:
	if cameras.is_empty():
		return
	selected_index = (selected_index - 1 + cameras.size()) % cameras.size()
	_m66e_refresh_after_camera_change()

func _on_camera_selected(idx: int) -> void:
	if cameras.is_empty():
		return
	selected_index = clamp(idx, 0, cameras.size() - 1)
	_m66e_refresh_after_camera_change()

func _update_camera_highlight() -> void:
	for i in range(camera_nodes.size()):
		var holder: Node3D = camera_nodes[i]
		var body = holder.get_node_or_null(str(cameras[i]["id"]) + " body") as MeshInstance3D
		if body:
			body.material_override = mat_camera_selected if i == selected_index else mat_camera_body
		var label = holder.get_node_or_null(str(cameras[i]["id"]) + " label") as Label3D
		if label:
			# Default: selected camera only. Top/Rig views can still show labels through inspector selection.
			label.visible = i == selected_index or mode == "Rigging / Lighting"
	if camera_option:
		camera_option.selected = selected_index

func _try_select_camera(screen_pos: Vector2) -> void:
	var best = 99999.0
	var best_i = -1
	if orbit_camera == null or not orbit_camera.is_inside_tree():
		return
	for i in range(cameras.size()):
		var cpos: Vector3 = cameras[i]["position"] as Vector3
		if orbit_camera.is_position_behind(cpos):
			continue
		var sp = orbit_camera.unproject_position(cpos)
		var d = sp.distance_to(screen_pos)
		if d < best and d < 38.0:
			best = d
			best_i = i
	if best_i >= 0:
		selected_index = best_i
		_m66e_refresh_after_camera_change()

func _frame_selected_camera() -> void:
	if cameras.is_empty():
		return
	pivot = (cameras[selected_index]["position"] as Vector3).lerp(_m67h_camera_aim_target(cameras[selected_index]), 0.35)
	distance = 5.0
	_update_orbit_camera()

func _preset_perspective() -> void:
	pivot = Vector3(0, 1.1, 0)
	distance = 14.5
	yaw = deg_to_rad(-38)
	pitch = deg_to_rad(-34)
	_update_orbit_camera()

func _preset_top() -> void:
	pivot = Vector3(0, 0.8, 0)
	distance = 16.0
	yaw = deg_to_rad(0)
	pitch = deg_to_rad(-86)
	_update_orbit_camera()

func _preset_front() -> void:
	pivot = Vector3(0, 1.2, 0)
	distance = 12.0
	yaw = deg_to_rad(180)
	pitch = deg_to_rad(-8)
	_update_orbit_camera()

func _preset_eye_line() -> void:
	pivot = TARGET
	distance = 8.0
	yaw = deg_to_rad(-90)
	pitch = deg_to_rad(-2)
	_update_orbit_camera()

func _preset_truss() -> void:
	pivot = Vector3(0, 3.0, 0)
	distance = 12.0
	yaw = deg_to_rad(-28)
	pitch = deg_to_rad(-18)
	_update_orbit_camera()

func _m66d_capture_visibility_policy() -> Dictionary:
	return {
		"overlay": false,
		"stage_root": false,
		"camera_root": false,
		"rig_root": false,
		"performer_root": true,
		"splat_root": false,
		"focus_envelope": false
	}

func _m66d_scene_visibility_state() -> Dictionary:
	var state: Dictionary = {}
	state["overlay"] = overlay_root.visible if overlay_root != null else true
	state["stage_root"] = stage_root.visible if stage_root != null else true
	state["camera_root"] = camera_root.visible if camera_root != null else true
	state["rig_root"] = rig_root.visible if rig_root != null else true
	state["performer_root"] = performer_root.visible if performer_root != null else true
	state["splat_root"] = splat_root.visible if splat_root != null else false
	state["focus_envelope"] = focus_envelope_root.visible if focus_envelope_root != null else true
	return state

func _m66d_apply_scene_visibility(state: Dictionary) -> void:
	if overlay_root != null:
		overlay_root.visible = bool(state.get("overlay", true))
	if stage_root != null:
		stage_root.visible = bool(state.get("stage_root", true))
	if camera_root != null:
		camera_root.visible = bool(state.get("camera_root", true))
	if rig_root != null:
		rig_root.visible = bool(state.get("rig_root", true))
	if performer_root != null:
		performer_root.visible = bool(state.get("performer_root", true))
	if splat_root != null:
		splat_root.visible = bool(state.get("splat_root", false))
	if focus_envelope_root != null:
		focus_envelope_root.visible = bool(state.get("focus_envelope", true))

func _m66d_capture_vfov_deg(c: Dictionary) -> float:
	return CaptureMath.capture_vfov_deg(c)

func _m66d_capture_axes(c: Dictionary) -> Dictionary:
	return _m67h_capture_axes_from_target(c, _m67h_camera_aim_target(c))

func _m66d_capture_transform(c: Dictionary) -> Transform3D:
	return CaptureMath.capture_transform(c, _m67h_camera_aim_target(c))

func _m66d_capture_intrinsics(c: Dictionary, size: Vector2i) -> Dictionary:
	return CaptureMath.capture_intrinsics(c, size)

func _m66d_capture_roll_deg(c: Dictionary) -> float:
	return 90.0 if bool(c.get("portrait", false)) else 0.0

func _m66d_capture_config(c: Dictionary, size: Vector2i) -> Dictionary:
	var intr = _m66d_capture_intrinsics(c, size)
	var xform = _m66d_capture_transform(c)
	return {
		"fov_deg": float(intr["vfov"]),
		"keep_aspect": M66D_CAPTURE_KEEP_ASPECT,
		"near": M66D_CAPTURE_NEAR,
		"far": M66D_CAPTURE_FAR,
		"roll_deg": _m66d_capture_roll_deg(c),
		"viewport_size": [size.x, size.y],
		"viewport_aspect": float(size.x) / max(1.0, float(size.y)),
		"global_position": [xform.origin.x, xform.origin.y, xform.origin.z],
		"basis_x": [xform.basis.x.x, xform.basis.x.y, xform.basis.x.z],
		"basis_y": [xform.basis.y.x, xform.basis.y.y, xform.basis.y.z],
		"basis_z": [xform.basis.z.x, xform.basis.z.y, xform.basis.z.z],
		"fx": float(intr["fx"]),
		"fy": float(intr["fy"]),
		"cx": float(intr["cx"]),
		"cy": float(intr["cy"]),
		"aim_target_m": _m67h_vec3_to_array(_m67h_camera_aim_target(c)),
		"focus_target_m": _m67h_vec3_to_array(_m67h_camera_focus_target(c))
	}

func _m66d_prepare_capture_viewport(sv: SubViewport, size: Vector2i, update_mode: int) -> void:
	sv.size = size
	sv.render_target_update_mode = update_mode
	sv.world_3d = get_viewport().world_3d
	sv.disable_3d = false

func _m66d_apply_capture_camera(cam: Camera3D, c: Dictionary, size: Vector2i = CLEAN_RENDER_SIZE) -> void:
	var xform = _m66d_capture_transform(c)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.keep_aspect = M66D_CAPTURE_KEEP_ASPECT
	cam.near = M66D_CAPTURE_NEAR
	cam.far = M66D_CAPTURE_FAR
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	cam.frustum_offset = Vector2.ZERO
	cam.fov = _m66d_capture_vfov_deg(c)
	cam.global_transform = xform

func _m66d_capture_camera_state(cam: Camera3D, size: Vector2i) -> Dictionary:
	return {
		"fov_deg": cam.fov,
		"keep_aspect": cam.keep_aspect,
		"near": cam.near,
		"far": cam.far,
		"viewport_size": [size.x, size.y],
		"viewport_aspect": float(size.x) / max(1.0, float(size.y)),
		"global_position": [cam.global_transform.origin.x, cam.global_transform.origin.y, cam.global_transform.origin.z],
		"basis_x": [cam.global_transform.basis.x.x, cam.global_transform.basis.x.y, cam.global_transform.basis.x.z],
		"basis_y": [cam.global_transform.basis.y.x, cam.global_transform.basis.y.y, cam.global_transform.basis.y.z],
		"basis_z": [cam.global_transform.basis.z.x, cam.global_transform.basis.z.y, cam.global_transform.basis.z.z]
	}

func _m66d_compare_capture_states(a: Dictionary, b: Dictionary) -> Array:
	var mismatches: Array = []
	if abs(float(a.get("fov_deg", 0.0)) - float(b.get("fov_deg", 0.0))) > 0.0001:
		mismatches.append("fov_deg")
	if int(a.get("keep_aspect", -1)) != int(b.get("keep_aspect", -2)):
		mismatches.append("keep_aspect")
	if abs(float(a.get("near", 0.0)) - float(b.get("near", 0.0))) > 0.0001:
		mismatches.append("near")
	if abs(float(a.get("far", 0.0)) - float(b.get("far", 0.0))) > 0.0001:
		mismatches.append("far")
	if abs(float(a.get("viewport_aspect", 0.0)) - float(b.get("viewport_aspect", 0.0))) > 0.0001:
		mismatches.append("viewport_aspect")
	for key in ["global_position", "basis_x", "basis_y", "basis_z"]:
		var av: Array = a.get(key, [])
		var bv: Array = b.get(key, [])
		if av.size() != bv.size():
			mismatches.append(str(key))
			continue
		for i in range(av.size()):
			if abs(float(av[i]) - float(bv[i])) > 0.0001:
				mismatches.append(str(key))
				break
	return mismatches

func _m66d_update_camera_pov_preview() -> void:
	if cameras.is_empty() or camera_pov_render_camera == null:
		return
	var c: Dictionary = cameras[selected_index]
	_m66d_apply_capture_camera(camera_pov_render_camera, c, CLEAN_RENDER_SIZE)
	if camera_pov_subviewport != null:
		_m66d_prepare_capture_viewport(camera_pov_subviewport, CLEAN_RENDER_SIZE, SubViewport.UPDATE_ALWAYS)
	if camera_pov_texture_rect != null and camera_pov_subviewport != null:
		camera_pov_texture_rect.texture = camera_pov_subviewport.get_texture()

func _m66d_camera_capture_summary(c: Dictionary, size: Vector2i) -> String:
	var pos: Vector3 = c["position"] as Vector3
	var focus_target = _m67h_camera_focus_target(c)
	var aim_target = _m67h_camera_aim_target(c)
	var floor_dist: float = Vector2(pos.x - focus_target.x, pos.z - focus_target.z).length()
	var dist3: float = pos.distance_to(focus_target)
	var height_m: float = pos.y
	var intr: Dictionary = _m66d_capture_intrinsics(c, size)
	var fx: float = float(intr.get("fx", 0.0))
	var fy: float = float(intr.get("fy", 0.0))
	var hfov: float = float(intr.get("hfov", 0.0))
	var vfov: float = float(intr.get("vfov", 0.0))
	var az: float = fposmod(rad_to_deg(atan2(pos.z, pos.x)), 360.0)
	var horiz: float = Vector2(aim_target.x - pos.x, aim_target.z - pos.z).length()
	var tilt: float = rad_to_deg(atan2(aim_target.y - pos.y, max(0.0001, horiz)))
	var txt: String = "Lens: Rokinon 24mm T5.6\n"
	txt += "Configured render: %d×%d / 16:9\n" % [size.x, size.y]
	txt += "fx/fy: %.1f px / %.1f px · HFOV/VFOV %.1f° / %.1f°\n" % [fx, fy, hfov, vfov]
	txt += "Height from floor: " + _meters_feet(height_m) + "\n"
	txt += "Distance 3D: " + _meters_feet(dist3) + " · Floor distance: " + _meters_feet(floor_dist) + "\n"
	txt += "Azimuth: %.1f° · Tilt/Pitch: %.1f° · Roll: %s\n" % [az, tilt, ("90° portrait" if bool(c["portrait"]) else "0° landscape")]
	txt += "Position: X %.2fm / %.2fft · Y %.2fm / %.2fft · Z %.2fm / %.2fft\n" % [pos.x, pos.x * 3.28084, pos.y, pos.y * 3.28084, pos.z, pos.z * 3.28084]
	txt += "Aim target: X %.2fm · Y %.2fm · Z %.2fm · Focus target Y %.2fm" % [aim_target.x, aim_target.y, aim_target.z, focus_target.y]
	return txt

func _camera_pov() -> void:
	if cameras.is_empty():
		return
	for child in overlay_root.get_children():
		child.queue_free()
	if focus_envelope_root != null:
		focus_envelope_root.visible = false
	var c: Dictionary = cameras[selected_index]
	_m66d_apply_capture_camera(orbit_camera, c, CLEAN_RENDER_SIZE)
	_m66d_update_camera_pov_preview()
	if camera_pov_preview_panel != null:
		camera_pov_preview_panel.visible = true
	_m68a_update_camera_nav_ui()
	status_label.text = "Camera POV exact 16:9 preview for " + _m68a_selected_camera_status_text() + ". Use the centered preview as the parity reference for rendered PNGs."

func _save_view_png() -> void:
	var out_dir = export_root_path + "/splatviz_view_m61"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var path = out_dir + "/splatviz_view.png"
	var err = img.save_png(path)
	status_label.text = "Saved viewport PNG: " + path + " err=" + str(err)

func _camera_unique_filename(c: Dictionary) -> String:
	var cid = str(c["id"])
	var digits = cid
	if cid.begins_with("C"):
		digits = cid.substr(1)
	return "CAM" + digits + "_frame_000001.png"

func _camera_unique_filename_from_id(cid: String) -> String:
	var digits = cid
	if cid.begins_with("C"):
		digits = cid.substr(1)
	return "CAM" + digits + "_frame_000001.png"

func _render_source_selected_camera() -> void:
	if cameras.is_empty():
		return
	var c: Dictionary = cameras[selected_index]
	var export_timestamp := _m68a_timestamp()
	var out_root: String = _m68a_make_timestamped_output_root("splatviz_render_source_selected_" + SPLATVIZ_EXPORT_TAG + "_4k", export_timestamp)
	var out_dir: String = out_root + "/images/" + str(c["id"])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path: String = out_dir + "/" + _camera_unique_filename(c)
	await _render_camera_to_path(c, path, SOURCE_RENDER_SIZE, true)
	_write_render_manifest(out_root, [c], SOURCE_RENDER_SIZE, true, export_timestamp)
	status_label.text = "Rendered source 4K selected camera still: " + path

func _render_source_all_cameras() -> void:
	var export_timestamp := _m68a_timestamp()
	var out_root: String = _m68a_make_timestamped_output_root("splatviz_render_source_all_" + SPLATVIZ_EXPORT_TAG + "_4k", export_timestamp)
	var root_path: String = out_root + "/images"
	DirAccess.make_dir_recursive_absolute(root_path)
	for c_any in cameras:
		var c: Dictionary = c_any as Dictionary
		var out_dir: String = root_path + "/" + str(c["id"])
		DirAccess.make_dir_recursive_absolute(out_dir)
		await _render_camera_to_path(c, out_dir + "/" + _camera_unique_filename(c), SOURCE_RENDER_SIZE, true)
	_write_render_manifest(out_root, cameras, SOURCE_RENDER_SIZE, true, export_timestamp)
	status_label.text = "Rendered " + str(cameras.size()) + " source 4K lossless stills to: " + root_path

func _render_selected_camera() -> void:
	if cameras.is_empty():
		return
	var c = cameras[selected_index]
	var export_timestamp := _m68a_timestamp()
	var out_root = _m68a_make_timestamped_output_root("splatviz_render_selected_" + SPLATVIZ_EXPORT_TAG, export_timestamp)
	var out_dir = out_root + "/images/" + str(c["id"])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path = out_dir + "/" + _camera_unique_filename(c)
	await _render_camera_to_path(c, path, CLEAN_RENDER_SIZE, true)
	_write_render_manifest(out_root, [c], CLEAN_RENDER_SIZE, true, export_timestamp)
	status_label.text = "Rendered clean selected camera still: " + path

func _render_all_cameras() -> void:
	var export_timestamp := _m68a_timestamp()
	var out_root = _m68a_make_timestamped_output_root("splatviz_render_all_" + SPLATVIZ_EXPORT_TAG, export_timestamp)
	var root = out_root + "/images"
	DirAccess.make_dir_recursive_absolute(root)
	for c in cameras:
		var out_dir = root + "/" + str(c["id"])
		DirAccess.make_dir_recursive_absolute(out_dir)
		await _render_camera_to_path(c, out_dir + "/" + _camera_unique_filename(c), CLEAN_RENDER_SIZE, true)
	_write_render_manifest(out_root, cameras, CLEAN_RENDER_SIZE, true, export_timestamp)
	status_label.text = "Rendered " + str(cameras.size()) + " clean 1080p 16:9 stills to: " + root

func _m66d_render_capture_image(c: Dictionary, size: Vector2i, clean: bool) -> Dictionary:
	var visibility_state = _begin_clean_render_visibility() if clean else {}
	var sv = SubViewport.new()
	_m66d_prepare_capture_viewport(sv, size, SubViewport.UPDATE_ONCE)
	add_child(sv)
	var cam: Camera3D = Camera3D.new()
	sv.add_child(cam)
	_m66d_apply_capture_camera(cam, c, size)
	cam.current = true
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img = sv.get_texture().get_image()
	var capture_state = _m66d_capture_camera_state(cam, size)
	sv.queue_free()
	if clean:
		_end_clean_render_visibility(visibility_state)
	return {"image": img, "camera_state": capture_state}

func _m66d_capture_qc(path: String, img: Image) -> Dictionary:
	var analysis = _stills_frame_analysis(img)
	var status = str(analysis.get("status", "UNKNOWN"))
	if status.begins_with("FAIL") or status.begins_with("WARN"):
		push_warning("Capture QC " + path + ": " + status)
	return analysis

func _m66d_capture_qc_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": "MISSING"}
	var img = Image.load_from_file(path)
	if img == null:
		return {"status": "LOAD_FAILED"}
	return _m66d_capture_qc(path, img)

func _m66d_debug_validate_selected_capture_parity(out_dir: String = "") -> Dictionary:
	var result: Dictionary = {"ok": false, "camera_id": "", "mismatches": [], "output_dir": ""}
	if cameras.is_empty():
		return result
	var c: Dictionary = cameras[selected_index]
	var cam_id = str(c["id"])
	if out_dir == "":
		out_dir = export_root_path + "/splatviz_capture_parity_debug"
	DirAccess.make_dir_recursive_absolute(out_dir)
	result["camera_id"] = cam_id
	result["output_dir"] = out_dir

	var visibility_state = _begin_clean_render_visibility()
	_m66d_update_camera_pov_preview()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var reference_path = out_dir.path_join(cam_id + "_camera_pov_reference.png")
	var reference_img = camera_pov_subviewport.get_texture().get_image()
	reference_img.save_png(reference_path)
	var reference_state = _m66d_capture_camera_state(camera_pov_render_camera, CLEAN_RENDER_SIZE)

	var offscreen_clean = await _m66d_render_capture_image(c, CLEAN_RENDER_SIZE, false)
	var offscreen_clean_path = out_dir.path_join(cam_id + "_offscreen_clean_1920x1080.png")
	var offscreen_clean_img: Image = offscreen_clean.get("image")
	offscreen_clean_img.save_png(offscreen_clean_path)

	var report_render = await _m66d_render_capture_image(c, M67F_REPORT_CONTACT_RENDER_SIZE, false)
	var report_render_path = out_dir.path_join(cam_id + "_report_contact_1280x720.png")
	var report_render_img: Image = report_render.get("image")
	report_render_img.save_png(report_render_path)
	_end_clean_render_visibility(visibility_state)

	var clean_state = offscreen_clean.get("camera_state", {})
	var report_state = report_render.get("camera_state", {})
	var clean_mismatches = _m66d_compare_capture_states(reference_state, clean_state)
	var report_mismatches = _m66d_compare_capture_states(reference_state, report_state)
	result["clean_mismatches"] = clean_mismatches
	result["report_mismatches"] = report_mismatches
	result["reference_path"] = reference_path
	result["offscreen_clean_path"] = offscreen_clean_path
	result["report_render_path"] = report_render_path
	result["reference_state"] = reference_state
	result["offscreen_clean_state"] = clean_state
	result["report_render_state"] = report_state
	result["reference_qc"] = _m66d_capture_qc(reference_path, reference_img)
	result["offscreen_clean_qc"] = _m66d_capture_qc(offscreen_clean_path, offscreen_clean_img)
	result["report_render_qc"] = _m66d_capture_qc(report_render_path, report_render_img)
	result["camera_pov_panel_alpha"] = 0.0
	result["camera_pov_prev_button_pos"] = [camera_pov_prev_button.position.x, camera_pov_prev_button.position.y] if camera_pov_prev_button != null else []
	result["camera_pov_next_button_pos"] = [camera_pov_next_button.position.x, camera_pov_next_button.position.y] if camera_pov_next_button != null else []
	result["camera_pov_status_label_pos"] = [camera_pov_status_label.position.x, camera_pov_status_label.position.y] if camera_pov_status_label != null else []
	result["ok"] = clean_mismatches.is_empty() and report_mismatches.is_empty()
	var report_path = out_dir.path_join(cam_id + "_capture_parity.json")
	var f = FileAccess.open(report_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(result, "  "))
		f.close()
	result["report_path"] = report_path
	return result

func _render_camera_to_path(c: Dictionary, path: String, size: Vector2i, clean: bool) -> void:
	var render_result = await _m66d_render_capture_image(c, size, clean)
	var img: Image = render_result.get("image")
	img.save_png(path)
	_m66d_capture_qc(path, img)

func _begin_clean_render_visibility() -> Dictionary:
	var state: Dictionary = _m66d_scene_visibility_state()
	_m66d_apply_scene_visibility(_m66d_capture_visibility_policy())
	return state

func _end_clean_render_visibility(state: Dictionary) -> void:
	_m66d_apply_scene_visibility(state)

func _debug_node_path(n: Node) -> String:
	if n == null:
		return "<null>"
	var out = ""
	var cur: Node = n
	while cur != null and cur != self:
		out = "/" + str(cur.name) + out
		cur = cur.get_parent()
	return out if out != "" else "/" + str(n.name)

func _debug_bool_node_visible(label: String, n: Node, lines: Array) -> void:
	if n == null:
		lines.append(label + "=<null>")
		return
	lines.append(label + ".visible=" + str(n.visible))
	lines.append(label + ".visible_in_tree=" + str(n.is_visible_in_tree()))

func _debug_dump_visible_meshes_for_export(root: Node, lines: Array, label: String) -> void:
	if root == null:
		lines.append(label + "=<null>")
		return
	if root is MeshInstance3D:
		var mi = root as MeshInstance3D
		var aabb = mi.get_aabb()
		lines.append(label + " mesh=" + _debug_node_path(mi) + " visible=" + str(mi.visible) + " visible_in_tree=" + str(mi.is_visible_in_tree()) + " local_aabb_pos=" + str(aabb.position) + " local_aabb_size=" + str(aabb.size) + " global_pos=" + str(mi.global_position))
	for child in root.get_children():
		_debug_dump_visible_meshes_for_export(child, lines, label)

func _debug_dump_msplat_clean_render_state(dataset_root: String, tag: String) -> void:
	DirAccess.make_dir_recursive_absolute(dataset_root)
	var lines: Array = []
	lines.append(SPLATVIZ_RELEASE_LABEL + " clean render state debug: " + tag)
	lines.append("dataset_root=" + dataset_root)
	lines.append("before_clean_visibility")
	_debug_bool_node_visible("performer_root", performer_root, lines)
	_debug_bool_node_visible("robot_model_root", robot_model_root, lines)
	_debug_bool_node_visible("splat_root", splat_root, lines)
	var state = _begin_clean_render_visibility()
	lines.append("")
	lines.append("after_begin_clean_render_visibility")
	_debug_bool_node_visible("performer_root", performer_root, lines)
	_debug_bool_node_visible("robot_model_root", robot_model_root, lines)
	_debug_bool_node_visible("splat_root", splat_root, lines)
	if performer_root != null:
		var paabb = _global_aabb_for_node(performer_root)
		lines.append("performer_root.global_aabb_pos=" + str(paabb.position))
		lines.append("performer_root.global_aabb_size=" + str(paabb.size))
	if robot_model_root != null:
		var raabb = _global_aabb_for_node(robot_model_root)
		lines.append("robot_model_root.global_aabb_pos=" + str(raabb.position))
		lines.append("robot_model_root.global_aabb_size=" + str(raabb.size))
	lines.append("")
	lines.append("visible_meshes_under_performer_root")
	_debug_dump_visible_meshes_for_export(performer_root, lines, "performer")
	lines.append("")
	lines.append("visible_meshes_under_splat_root")
	_debug_dump_visible_meshes_for_export(splat_root, lines, "splat")
	_end_clean_render_visibility(state)
	var f = FileAccess.open(dataset_root + "/splatviz_visible_mesh_dump_" + SPLATVIZ_EXPORT_TAG + ".txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")
		f.close()

func _write_render_manifest(root_path: String, cams: Array, size: Vector2i, clean: bool, export_timestamp: String = "") -> void:
	DirAccess.make_dir_recursive_absolute(root_path)
	if export_timestamp == "":
		export_timestamp = _m68a_timestamp()
	var volume = _m67h_capture_volume()
	var counts = _m67h_qc_counts(cams)
	var volume_counts = _m67h_volume_qc_counts(cams)
	var cam_entries = []
	for c in cams:
		var pos: Vector3 = c["position"] as Vector3
		cam_entries.append({
			"camera_id": str(c["id"]),
			"image_path": "images/" + str(c["id"]) + "/" + _camera_unique_filename(c),
			"position_m": [pos.x, pos.y, pos.z],
			"aim_target_m": _m67h_vec3_to_array(_m67h_camera_aim_target(c)),
			"focus_target_m": _m67h_vec3_to_array(_m67h_camera_focus_target(c)),
			"focus_distance_m": float(c["focus_m"]),
			"tier": str(c["tier"]),
			"portrait_roll": bool(c["portrait"]),
			"lens": "Rokinon DSX24-RF 24mm T1.5",
			"body": "RED KOMODO-X proxy",
			"frame_qc_status": str(c.get("frame_qc_status", "UNKNOWN")),
			"frame_qc_reason": str(c.get("frame_qc_reason", "")),
			"frame_qc_recommendation": str(c.get("frame_qc_recommendation", "")),
			"frame_qc_margins": c.get("frame_qc_margins", {}),
			"capture_volume_center_m": _m67h_vec3_to_array(volume.get("center", TARGET)),
			"export_policy": _m67h_export_policy(c)
		})
	var manifest = {
		"splatviz_version": SPLATVIZ_RELEASE_LABEL,
		"app_release_label": SPLATVIZ_RELEASE_LABEL,
		"export_tag": SPLATVIZ_EXPORT_TAG,
		"export_timestamp": export_timestamp,
		"layout_profile": layout_name,
		"render_width": size.x,
		"render_height": size.y,
		"camera_count": cams.size(),
		"subject_qc_counts": counts,
		"volume_qc_counts": volume_counts,
		"render_type": "clean" if clean else "diagnostic",
		"export_root_path": root_path,
		"subject_asset": "SplatVizRobot.glb",
		"subject_height_m": ROBOT_HEIGHT_M,
		"subject_height_ft_in": "5 ft 11 in",
		"resolution_px": [size.x, size.y],
		"source_aspect_ratio": "16:9",
		"layout": layout_name,
		"installation_mode": installation_mode,
		"frame_qc_counts": counts,
		"capture_volume": {
			"center_m": _m67h_vec3_to_array(volume.get("center", TARGET)),
			"size_m": _m67h_vec3_to_array(volume.get("size", Vector3.ZERO)),
			"motion_margin_m": _m67h_vec3_to_array(volume.get("motion_margin", Vector3.ZERO)),
			"floor_included": true
		},
		"overlays_hidden_for_clean_render": clean,
		"stage_helpers_hidden_for_clean_render": clean,
		"validation_note": "Msplat is a local reconstruction run. Production conclusions require gsplat validation.",
		"cameras": cam_entries
	}
	var f = FileAccess.open(root_path + "/render_manifest.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(manifest, "  "))
		f.close()


func _msplat_input_path() -> String:
	var dataset = msplat_dataset_root if msplat_dataset_root != "" else export_root_path + "/splatviz_msplat_dataset_" + SPLATVIZ_EXPORT_TAG
	if FileAccess.file_exists(dataset + "/sparse/0/cameras.bin") and FileAccess.file_exists(dataset + "/sparse/0/images.bin") and FileAccess.file_exists(dataset + "/sparse/0/points3D.bin"):
		return dataset + "/sparse/0"
	return dataset

func _msplat_command_string() -> String:
	var home = OS.get_environment("HOME")
	var train_path = home + "/msplat-env/bin/msplat-train"
	var input_path = _msplat_input_path()
	var result = msplat_result_root if msplat_result_root != "" else export_root_path + "/splatviz_msplat_result_" + SPLATVIZ_EXPORT_TAG
	var ply = result + "/splatviz_" + SPLATVIZ_EXPORT_TAG + "_TIMESTAMP_msplat_" + str(msplat_num_iters) + "iter.ply"
	# --keep-crs keeps the trained splat in the input COLMAP coordinate frame
	# (metric, matching the rig) instead of Msplat's auto-normalized frame.
	# Required so the splat (a) stays in real-world coordinates for the blueprint
	# pipeline, (b) can be independently rendered/scored against the source stills,
	# and (c) trains with world-unit densification thresholds at true scale (which
	# also measured higher held-out PSNR than the normalized frame).
	return train_path + " --input " + input_path + " --output " + ply + " --num-iters " + str(msplat_num_iters) + " --keep-crs --save-every 500 --eval --test-every 8"

func _update_msplat_terminal_header() -> void:
	var home = OS.get_environment("HOME")
	if msplat_train_path == "":
		msplat_train_path = home + "/msplat-env/bin/msplat-train"
	if msplat_dataset_root == "":
		msplat_dataset_root = export_root_path + "/splatviz_msplat_dataset_" + SPLATVIZ_EXPORT_TAG
	if msplat_result_root == "":
		msplat_result_root = export_root_path + "/splatviz_msplat_result_" + SPLATVIZ_EXPORT_TAG
	if msplat_path_label:
		msplat_path_label.text = "msplat-train: " + msplat_train_path + "\nDataset: " + msplat_dataset_root + "\nResult: " + msplat_result_root
	if msplat_command_label:
		msplat_command_label.text = "Command: " + _msplat_command_string()

func _append_msplat_terminal(line: String) -> void:
	if msplat_terminal_label == null:
		return
	msplat_terminal_label.text += line + "\n"
	var max_chars = 32768
	if msplat_terminal_label.text.length() > max_chars:
		msplat_terminal_label.text = "… trimmed terminal output …\n" + msplat_terminal_label.text.substr(max(0, msplat_terminal_label.text.length() - max_chars), max_chars)
	if msplat_terminal_label is TextEdit:
		msplat_terminal_label.scroll_vertical = msplat_terminal_label.get_line_count()

func _clear_msplat_terminal() -> void:
	if msplat_terminal_label:
		msplat_terminal_label.text = "$ SplatViz Msplat terminal cleared.\n"

func _copy_msplat_command() -> void:
	DisplayServer.clipboard_set(_msplat_command_string())
	_append_msplat_terminal("$ Copied command to clipboard")

func _open_msplat_result_folder() -> void:
	_update_msplat_terminal_header()
	DirAccess.make_dir_recursive_absolute(msplat_result_root)
	OS.shell_open(msplat_result_root)
	_append_msplat_terminal("$ Opened result folder: " + msplat_result_root)

func _browse_msplat_dataset_folder() -> void:
	if msplat_dataset_dialog != null:
		msplat_dataset_dialog.current_dir = export_root_path
		msplat_dataset_dialog.popup_centered_ratio(0.62)

func _set_msplat_dataset_folder(dir: String) -> void:
	var chosen = dir.trim_suffix("/")
	var dataset = chosen
	var has_sparse = FileAccess.file_exists(chosen + "/sparse/0/images.bin") or FileAccess.file_exists(chosen + "/sparse/0/images.txt")
	var has_transforms = FileAccess.file_exists(chosen + "/transforms.json")
	var has_images = DirAccess.dir_exists_absolute(chosen + "/images")
	var chosen_is_images = chosen.ends_with("/images") or chosen.ends_with("\\images")
	if chosen_is_images:
		var parent = _path_parent(chosen)
		var base = _path_parent(parent)
		dataset = base + "/splatviz_msplat_dataset_from_images_" + SPLATVIZ_EXPORT_TAG
		_create_msplat_dataset_from_images(chosen, dataset)
		_append_msplat_terminal("$ Built Nerfstudio transforms.json dataset from clean images folder: " + dataset)
	elif not has_sparse and not has_transforms and has_images:
		dataset = chosen + "_msplat_dataset_" + SPLATVIZ_EXPORT_TAG
		_create_msplat_dataset_from_images(chosen + "/images", dataset)
		_append_msplat_terminal("$ Built Nerfstudio transforms.json dataset from selected render folder: " + dataset)
	elif not has_sparse and not has_transforms:
		_append_msplat_terminal("$ Warning: selected folder does not contain transforms.json or sparse/0/images.bin/images.txt. Select a SplatViz dataset root, COLMAP sparse dataset root, or clean images folder.")
	msplat_dataset_root = dataset
	msplat_result_root = _path_parent(dataset) + "/splatviz_msplat_result_" + SPLATVIZ_EXPORT_TAG
	msplat_log_path = msplat_result_root + "/train.log"
	var provenance := _m68a_manifest_info_for_path(dataset)
	var provenance_warning := str(provenance.get("warning", ""))
	if provenance_warning != "":
		_append_msplat_terminal("$ " + provenance_warning)
	_update_msplat_terminal_header()
	_refresh_msplat_terminal(false)

func _path_parent(path: String) -> String:
	var p = path.trim_suffix("/")
	var idx = p.rfind("/")
	if idx <= 0:
		return p
	return p.substr(0, idx)

func _create_msplat_dataset_from_images(images_root: String, dataset_root: String) -> void:
	var export_cameras = _m67h_prepare_dataset_export_cameras()
	if export_cameras.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dataset_root + "/images")
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0")
	var copied = 0
	for c in export_cameras:
		var cid = str(c["id"])
		var unique_name = _camera_unique_filename(c)
		var src = images_root + "/" + cid + "/" + unique_name
		if not FileAccess.file_exists(src):
			src = images_root + "/" + cid + "/frame_000001.png"
		if not FileAccess.file_exists(src):
			src = images_root + "/" + unique_name
		if not FileAccess.file_exists(src):
			src = images_root + "/" + cid + ".png"
		if not FileAccess.file_exists(src):
			continue
		var dst = dataset_root + "/images/" + unique_name
		_copy_binary_file(src, dst)
		copied += 1
	_debug_dump_msplat_camera_positions(dataset_root, "export_m58_pre_colmap_write")
	_write_colmap_dataset(dataset_root, export_cameras, CLEAN_RENDER_SIZE)
	_write_seed_point_cloud_ply(dataset_root, export_cameras, CLEAN_RENDER_SIZE)
	_mirror_images_to_colmap_sparse(dataset_root)
	_write_colmap_binary_dataset(dataset_root, export_cameras, CLEAN_RENDER_SIZE)
	_write_nerfstudio_transforms(dataset_root, export_cameras, CLEAN_RENDER_SIZE)
	_write_msplat_manifest(dataset_root, export_cameras, CLEAN_RENDER_SIZE)
	_append_msplat_terminal("$ Copied " + str(copied) + " camera images into dataset/images")
	if copied == 0:
		_append_msplat_terminal("$ Warning: no C## images found in " + images_root)

func _copy_binary_file(src: String, dst: String) -> void:
	var r = FileAccess.open(src, FileAccess.READ)
	if r == null:
		return
	var bytes = r.get_buffer(r.get_length())
	r.close()
	var w = FileAccess.open(dst, FileAccess.WRITE)
	if w == null:
		return
	w.store_buffer(bytes)
	w.close()

func _find_latest_msplat_dataset() -> void:
	DirAccess.make_dir_recursive_absolute(export_root_path)
	var dir = DirAccess.open(export_root_path)
	if dir == null:
		_append_msplat_terminal("$ Could not open export root: " + export_root_path)
		return
	var best = ""
	var best_score = -1
	dir.list_dir_begin()
	while true:
		var name = dir.get_next()
		if name == "":
			break
		if dir.current_is_dir() and name.find("msplat_dataset") >= 0:
			var path = export_root_path + "/" + name
			var t = FileAccess.get_modified_time(path + "/sparse/0/cameras.bin")
			if t == 0:
				t = FileAccess.get_modified_time(path + "/splatviz_msplat_manifest.json")
			if t == 0:
				t = FileAccess.get_modified_time(path + "/transforms.json")
			var score = int(t)
			if _msplat_dataset_has_colmap_sparse(path):
				score += 2000000000
			elif FileAccess.file_exists(path + "/transforms.json"):
				score += 1000000000
			if score >= best_score:
				best_score = score
				best = path
	dir.list_dir_end()
	if best == "":
		best = export_root_path + "/splatviz_msplat_dataset_" + SPLATVIZ_EXPORT_TAG
		_append_msplat_terminal("$ No prior dataset found. Defaulting to: " + best)
	else:
		_append_msplat_terminal("$ Found latest dataset: " + best)
	msplat_dataset_root = best
	msplat_result_root = export_root_path + "/splatviz_msplat_result_" + SPLATVIZ_EXPORT_TAG
	msplat_log_path = msplat_result_root + "/train.log"
	_update_msplat_terminal_header()
	_refresh_msplat_terminal(false)

func _parse_msplat_int_token(token: String) -> int:
	var cleaned = token.replace(",", "").replace("%", "").strip_edges()
	if cleaned.is_valid_int():
		return int(cleaned)
	return -1

func _update_msplat_progress_from_log(txt: String) -> void:
	if msplat_progress_bar == null or msplat_progress_label == null:
		return
	var last_step = 0
	var last_splats = -1
	var densify_count = 0
	var last_densified_from = -1
	var last_densified_to = -1
	var psnr = ""
	var ssim = ""
	var l1 = ""
	var exit_code = ""
	var target_iters = msplat_num_iters
	var saw_saved = txt.find("Saved ") >= 0
	var saw_finished = txt.find("SplatViz run finished") >= 0 or txt.find("splat_ply=present") >= 0
	var saw_traceback = txt.find("Traceback") >= 0 or txt.find("RuntimeError") >= 0
	var lines = txt.split("\n")
	for l in lines:
		var line = str(l).strip_edges()
		if line.find("target iterations") >= 0:
			var parts = line.split(" ", false)
			for part in parts:
				var v = _parse_msplat_int_token(str(part))
				if v > 0:
					target_iters = v
		if line.begins_with("step="):
			var after_step = line.substr(5).strip_edges()
			var pieces = after_step.split(" ", false)
			if pieces.size() > 0:
				var parsed_step = _parse_msplat_int_token(str(pieces[0]))
				if parsed_step > last_step:
					last_step = parsed_step
			var si = line.find("splats=")
			if si >= 0:
				var after_s = line.substr(si + 7).strip_edges()
				var spieces = after_s.split(" ", false)
				if spieces.size() > 0:
					var parsed_splats = _parse_msplat_int_token(str(spieces[0]))
					if parsed_splats >= 0:
						last_splats = parsed_splats
		elif line.begins_with("Densified:"):
			densify_count += 1
			var after_d = line.replace("Densified:", "").replace("gaussians", "").strip_edges()
			var sides = after_d.split("->", false)
			if sides.size() >= 2:
				var from_val = _parse_msplat_int_token(str(sides[0]))
				var to_val = _parse_msplat_int_token(str(sides[1]))
				if from_val >= 0:
					last_densified_from = from_val
				if to_val >= 0:
					last_densified_to = to_val
					last_splats = to_val
		elif line.begins_with("PSNR:"):
			psnr = line.replace("PSNR:", "").strip_edges()
		elif line.begins_with("SSIM:"):
			ssim = line.replace("SSIM:", "").strip_edges()
		elif line.begins_with("L1:"):
			l1 = line.replace("L1:", "").strip_edges()
		elif line.find("SplatViz run finished with exit code") >= 0:
			exit_code = line.replace("SplatViz run finished with exit code", "").strip_edges()

	if target_iters > 0:
		msplat_num_iters = target_iters
	if saw_finished:
		if msplat_running:
			msplat_final_refresh_ticks = max(msplat_final_refresh_ticks, 8)
		msplat_running = false
		msplat_progress_bar.value = 100
		msplat_progress_label.text = "Finished · exit " + (exit_code if exit_code != "" else "0")
		if last_splats >= 0:
			msplat_last_splats = last_splats
			msplat_progress_label.text += " · splats " + _format_int_commas(last_splats)
	elif saw_traceback:
		if msplat_running:
			msplat_final_refresh_ticks = max(msplat_final_refresh_ticks, 8)
		msplat_running = false
		msplat_progress_bar.value = 100
		msplat_progress_label.text = "Failed · inspect train.log"
	elif last_step > 0:
		msplat_last_phase = "training"
		msplat_last_step = last_step
		if last_splats >= 0:
			msplat_last_splats = last_splats
		var pct = clamp(float(last_step) / float(max(1, target_iters)) * 100.0, 0.0, 99.0 if not saw_saved else 100.0)
		msplat_progress_bar.value = pct
		msplat_progress_label.text = "Running · step %d / %d · %.1f%%" % [last_step, target_iters, pct]
		if last_splats >= 0:
			msplat_progress_label.text += " · splats " + _format_int_commas(last_splats)
	elif densify_count > 0:
		# M6.5A: Densification can be a long phase before msplat emits step= logs.
		# Do not pin the UI at 45%; show an activity estimate and keep the latest
		# Gaussian count visible so the user knows the trainer is still moving.
		var densify_pct = clamp(10.0 + float(densify_count) * 2.2, 10.0, 72.0)
		msplat_progress_bar.value = densify_pct
		msplat_last_phase = "densifying"
		msplat_progress_label.text = "Running · densifying"
		if last_densified_to >= 0:
			msplat_last_splats = last_densified_to
			msplat_progress_label.text += " · splats " + _format_int_commas(last_densified_to)
		msplat_progress_label.text += " · waiting for step logs"
	elif msplat_running:
		msplat_progress_bar.value = 4
		msplat_progress_label.text = "Running · preparing dataset / launching trainer"
	else:
		msplat_progress_bar.value = 0
		msplat_progress_label.text = "Idle · no active Msplat run"
	if psnr != "" or ssim != "":
		msplat_progress_label.text += " · PSNR " + psnr + " · SSIM " + ssim
	if l1 != "":
		msplat_progress_label.text += " · L1 " + l1

func _format_int_commas(v: int) -> String:
	var s = str(abs(v))
	var out = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count == 3 and i > 0:
			out = "," + out
			count = 0
	if v < 0:
		out = "-" + out
	return out

func _read_text_tail(path: String, max_bytes: int = 32768) -> Dictionary:
	var out: Dictionary = {"text": "", "size": 0}
	if path == "" or not FileAccess.file_exists(path):
		return out
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var total_len: int = int(f.get_length())
	var start: int = int(max(0, total_len - max_bytes))
	f.seek(start)
	var bytes: PackedByteArray = f.get_buffer(total_len - start)
	f.close()
	var txt: String = bytes.get_string_from_utf8()
	if start > 0:
		txt = "… tail of train.log …\n" + txt
	out["text"] = txt
	out["size"] = total_len
	return out

func _refresh_msplat_terminal(force: bool) -> void:
	if msplat_log_path == "":
		msplat_log_path = (msplat_result_root if msplat_result_root != "" else export_root_path + "/splatviz_msplat_result_" + SPLATVIZ_EXPORT_TAG) + "/train.log"
	if not FileAccess.file_exists(msplat_log_path):
		if force:
			_append_msplat_terminal("$ No train.log yet: " + msplat_log_path)
		return
	var tail: Dictionary = _read_text_tail(msplat_log_path, 32768)
	var txt: String = str(tail.get("text", ""))
	var byte_size: int = int(tail.get("size", txt.length()))
	if txt == "":
		return
	if byte_size != msplat_log_last_size:
		msplat_log_last_size = byte_size
		msplat_log_idle_seconds = 0.0
		msplat_stall_notice_shown = false
	else:
		msplat_log_idle_seconds += 0.5
	var full_txt = txt
	if msplat_terminal_label:
		msplat_terminal_label.text = "$ tail -f " + msplat_log_path + "\n" + txt
		if msplat_terminal_label is TextEdit:
			msplat_terminal_label.scroll_vertical = msplat_terminal_label.get_line_count()
	_update_msplat_progress_from_log(full_txt)
	_update_msplat_watchdog_status(full_txt)
	if full_txt.find("Gaussians: 0") >= 0 or full_txt.find("splats=       0") >= 0:
		# Keep this as a human-readable diagnosis in the terminal. A zero-Gaussian result means
		# the dataset was recognized, but the reconstruction had no usable seed splats/points.
		if msplat_status_label:
			msplat_status_label.text = "Msplat dataset loaded, but result has zero Gaussians. Use seeded dataset export; if still zero, audit the COLMAP sparse bridge."
	# M6.5A: never stop terminal refresh from file presence alone. The watchdog waits for
	# process exit plus final log markers, so the window remains truthful during long densify/eval phases.


func _msplat_health_path() -> String:
	var result = msplat_result_root if msplat_result_root != "" else export_root_path + "/splatviz_msplat_result_" + SPLATVIZ_EXPORT_TAG
	return result + "/msplat_health.txt"

func _parse_msplat_health_line() -> Dictionary:
	var path = _msplat_health_path()
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		return out
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var txt := f.get_as_text().strip_edges()
	f.close()
	if txt == "":
		return out
	var lines = txt.split("\n")
	var line = str(lines[lines.size() - 1]).strip_edges()
	for part in line.split(" ", false):
		var p = str(part)
		var eq = p.find("=")
		if eq > 0:
			var k = p.substr(0, eq)
			var v = p.substr(eq + 1)
			out[k] = v.strip_edges().trim_prefix("\"").trim_suffix("\"")
	return out

func _msplat_health_suffix() -> String:
	var h := _parse_msplat_health_line()
	if h.is_empty():
		return ""
	var suffix := ""
	if h.has("train_pid"):
		suffix += " · child PID " + str(h["train_pid"])
	if h.has("cpu"):
		suffix += " · CPU " + str(h["cpu"]) + "%"
	if h.has("mem"):
		suffix += " · mem " + str(h["mem"]) + "%"
	if h.has("state"):
		suffix += " · state " + str(h["state"])
	if h.has("phase"):
		var phase = str(h["phase"])
		if phase != "running":
			suffix += " · " + phase
	return suffix

func _apply_msplat_health_suffix() -> void:
	if msplat_progress_label == null:
		return
	var suffix := _msplat_health_suffix()
	if suffix == "":
		return
	var txt := msplat_progress_label.text
	var idx := txt.find(" · child PID ")
	if idx >= 0:
		txt = txt.substr(0, idx)
	msplat_progress_label.text = txt + suffix

func _poll_msplat_terminal(delta: float) -> void:
	# M6.5A: poll whenever a process is known, the terminal window is visible, or we owe
	# final refresh ticks. This avoids the previous stale 45% state caused by old log
	# markers or stopping before the process wrote the final eval block.
	var terminal_open = msplat_window != null and msplat_window.visible
	var process_alive = _msplat_process_alive()
	if process_alive:
		msplat_running = true
	if not msplat_running and not terminal_open and not (mode == "Msplat") and msplat_final_refresh_ticks <= 0:
		return
	msplat_poll_seconds += delta
	if msplat_poll_seconds < 0.5:
		return
	msplat_poll_seconds = 0.0
	_refresh_msplat_terminal(false)
	process_alive = _msplat_process_alive()
	if not process_alive and msplat_running:
		# Process disappeared before we saw final markers; keep refreshing briefly because
		# the shell wrapper may still be flushing exit code / splat_ply lines.
		msplat_running = false
		msplat_final_refresh_ticks = max(msplat_final_refresh_ticks, 8)
		if msplat_progress_label:
			msplat_progress_label.text = "Process ended · waiting for final log markers"
	if not msplat_running and msplat_final_refresh_ticks > 0:
		msplat_final_refresh_ticks -= 1

func _msplat_process_alive() -> bool:
	if msplat_process_id <= 0:
		return false
	return OS.is_process_running(msplat_process_id)

func _update_msplat_watchdog_status(full_txt: String) -> void:
	if msplat_progress_label == null:
		return
	var process_alive = _msplat_process_alive()
	var finished = full_txt.find("SplatViz run finished") >= 0 or full_txt.find("splat_ply=present") >= 0
	if finished:
		return
	var suffix = ""
	if msplat_process_id > 0:
		suffix += " · PID " + str(msplat_process_id)
	if msplat_log_idle_seconds >= 240.0 and process_alive:
		suffix += " · Finalizing/log quiet %.0fs" % msplat_log_idle_seconds
		if not msplat_stall_notice_shown:
			msplat_stall_notice_shown = true
			_append_msplat_terminal(("$ WARNING: Msplat process is alive but train.log has not changed for %.0fs. Use Open Result Folder / terminal kill if CPU is 0. " + SPLATVIZ_RELEASE_LABEL + " keeps the UI responsive with tail-only polling.") % msplat_log_idle_seconds)
	elif msplat_log_idle_seconds >= 5.0:
		suffix += " · no new log %.0fs" % msplat_log_idle_seconds
	elif process_alive:
		suffix += " · log live"
	if process_alive and msplat_progress_label.text.find("PID") < 0:
		msplat_progress_label.text += suffix
	elif (not process_alive) and msplat_running:
		msplat_progress_label.text += " · process not found"

func _export_msplat_dataset() -> void:
	if cameras.is_empty():
		return
	var export_cameras = _m67h_prepare_dataset_export_cameras()
	if export_cameras.is_empty():
		return
	_append_msplat_terminal("$ Exporting SplatViz synthetic dataset…")
	var export_timestamp := _m68a_timestamp()
	var dataset_root = _m68a_make_timestamped_output_root("splatviz_msplat_dataset_" + SPLATVIZ_EXPORT_TAG + "_1080p_" + _m68a_layout_profile_slug(), export_timestamp)
	msplat_dataset_root = dataset_root
	DirAccess.make_dir_recursive_absolute(dataset_root + "/images")
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0")
	_debug_dump_msplat_clean_render_state(dataset_root, "export_" + SPLATVIZ_EXPORT_TAG + "_before_render_loop")
	_append_msplat_terminal("$ " + SPLATVIZ_RELEASE_LABEL + " clean-render mesh dump: " + dataset_root + "/splatviz_visible_mesh_dump_" + SPLATVIZ_EXPORT_TAG + ".txt")
	for c in export_cameras:
		var img_path = dataset_root + "/images/" + _camera_unique_filename(c)
		await _render_camera_to_path(c, img_path, CLEAN_RENDER_SIZE, true)
	_write_colmap_dataset(dataset_root, export_cameras, CLEAN_RENDER_SIZE)
	_write_seed_point_cloud_ply(dataset_root, export_cameras, CLEAN_RENDER_SIZE)
	_mirror_images_to_colmap_sparse(dataset_root)
	_write_colmap_binary_dataset(dataset_root, export_cameras, CLEAN_RENDER_SIZE)
	_write_nerfstudio_transforms(dataset_root, export_cameras, CLEAN_RENDER_SIZE)
	_write_msplat_manifest(dataset_root, export_cameras, CLEAN_RENDER_SIZE, export_timestamp)
	_update_msplat_terminal_header()
	_append_msplat_terminal("$ Dataset ready: " + dataset_root)
	_append_msplat_terminal("$ Images: " + dataset_root + "/images")
	if m67h_last_dataset_unsafe_override_used:
		_append_msplat_terminal("$ Override note: FAIL/INVALID cameras were omitted from training export: " + ", ".join(PackedStringArray(m67h_last_dataset_omitted_camera_ids)))
	_append_msplat_terminal("$ transforms.json: " + dataset_root + "/transforms.json")
	_append_msplat_terminal("$ seed PLY: " + dataset_root + "/splatviz_seed_points.ply")
	_append_msplat_terminal("$ COLMAP binary sparse: " + dataset_root + "/sparse/0/cameras.bin + images.bin + points3D.bin")
	_append_msplat_terminal("$ Sparse note: points3D.bin is robot-only synthetic seed geometry authored by SplatViz; clean export forces performer visible and splat preview hidden.")
	if msplat_status_label:
		msplat_status_label.text = "Msplat dataset exported: " + dataset_root + " (" + str(export_cameras.size()) + " camera(s))"
	if status_label:
		status_label.text = "Exported Msplat/Nerfstudio synthetic dataset: " + dataset_root + " (" + str(export_cameras.size()) + " camera(s))"

func _debug_dump_msplat_camera_positions(dataset_root: String, tag: String) -> void:
	var lines: Array = []
	lines.append(SPLATVIZ_RELEASE_LABEL + " camera position debug: " + tag)
	lines.append("id,index,tier,portrait,pos_x,pos_y,pos_z,focus_m,azimuth_deg,qw,qx,qy,qz,tx,ty,tz")
	for c in cameras:
		var p: Vector3 = c["position"] as Vector3
		var pose: Array = _colmap_pose(c)
		lines.append("%s,%d,%s,%s,%.6f,%.6f,%.6f,%.6f,%.3f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f" % [
			str(c["id"]),
			int(c.get("index", 0)),
			str(c["tier"]),
			str(c["portrait"]),
			p.x, p.y, p.z,
			float(c["focus_m"]),
			float(c["azimuth_deg"]),
			float(pose[0]), float(pose[1]), float(pose[2]), float(pose[3]),
			float(pose[4]), float(pose[5]), float(pose[6])
		])
	var txt = "
".join(lines) + "
"
	print(txt)
	if dataset_root != "":
		DirAccess.make_dir_recursive_absolute(dataset_root)
		var f = FileAccess.open(dataset_root + "/splatviz_camera_position_debug_m61.txt", FileAccess.WRITE)
		if f != null:
			f.store_string(txt)
			f.close()
		DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0")
		var sf = FileAccess.open(dataset_root + "/sparse/0/splatviz_camera_position_debug_m61.txt", FileAccess.WRITE)
		if sf != null:
			sf.store_string(txt)
			sf.close()

func _msplat_dataset_has_colmap_sparse(path: String) -> bool:
	return path != "" and FileAccess.file_exists(path + "/sparse/0/cameras.bin") and FileAccess.file_exists(path + "/sparse/0/images.bin") and FileAccess.file_exists(path + "/sparse/0/points3D.bin")

func _msplat_dataset_has_seed(path: String) -> bool:
	return path != "" and FileAccess.file_exists(path + "/splatviz_seed_points.ply")

func _msplat_dataset_is_ready(path: String) -> bool:
	if path == "":
		return false
	# M6.5A requires the COLMAP binary sparse bridge before training. Nerfstudio transforms alone
	# loaded in Msplat but produced zero Gaussians, so treat it as incomplete for Run Msplat.
	if _msplat_dataset_has_colmap_sparse(path):
		return true
	if DirAccess.dir_exists_absolute(path + "/keyframes"):
		return true
	return false

func _ensure_msplat_dataset_current() -> void:
	if msplat_dataset_root == "":
		msplat_dataset_root = export_root_path + "/splatviz_msplat_dataset_" + SPLATVIZ_EXPORT_TAG
	# M6.5A: always rewrite SplatViz-authored COLMAP sparse metadata before training.
	# Older datasets could leave stale images.bin paths such as NAME=images/C##.png,
	# which Msplat resolves incorrectly. Rewriting every run keeps the M6.5A policy:
	# NAME=CAM##_frame_000001.png and image file located directly in sparse/0/.
	if DirAccess.dir_exists_absolute(msplat_dataset_root + "/images"):
		_append_msplat_terminal("$ Refreshing COLMAP sparse metadata in selected dataset:")
		_append_msplat_terminal("$ " + msplat_dataset_root)
		_rewrite_msplat_sparse_bridge(msplat_dataset_root)
	else:
		_append_msplat_terminal("$ No usable images folder found at selected dataset. Exporting fresh " + SPLATVIZ_RELEASE_LABEL + " dataset…")
		await _export_msplat_dataset()
	_update_msplat_terminal_header()

func _rewrite_msplat_sparse_bridge(dataset_root: String) -> void:
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0")
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0/images")
	# Rebuild all metadata that Msplat may inspect. These files are safe to overwrite.
	_debug_dump_msplat_camera_positions(dataset_root, "rewrite_m58_pre_colmap_write")
	_write_colmap_dataset(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_seed_point_cloud_ply(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_mirror_images_to_colmap_sparse(dataset_root)
	_write_colmap_binary_dataset(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_nerfstudio_transforms(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_msplat_manifest(dataset_root, cameras, CLEAN_RENDER_SIZE)
	var policy_path = dataset_root + "/sparse/0/splatviz_colmap_name_policy_m61.txt"
	var pf = FileAccess.open(policy_path, FileAccess.WRITE)
	if pf != null:
		pf.store_string(SPLATVIZ_RELEASE_LABEL + " COLMAP images.bin policy: NAME=CAM##_frame_000001.png; Msplat resolves to sparse/0/CAM##_frame_000001.png.\n")
		pf.close()
	_append_msplat_terminal("$ Sparse bridge refreshed: cameras.bin/images.bin/points3D.bin + sparse/0/CAM##_frame_000001.png")

func _write_msplat_dataset_listing(log_path: String) -> void:
	var f = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_string("\nDataset validation\n")
	f.store_string("dataset_root=" + msplat_dataset_root + "\n")
	f.store_string("transforms.json=" + str(FileAccess.file_exists(msplat_dataset_root + "/transforms.json")) + "\n")
	f.store_string("images_dir=" + str(DirAccess.dir_exists_absolute(msplat_dataset_root + "/images")) + "\n")
	f.store_string("seed_ply=" + str(FileAccess.file_exists(msplat_dataset_root + "/splatviz_seed_points.ply")) + "\n")
	f.store_string("colmap_cameras_bin=" + str(FileAccess.file_exists(msplat_dataset_root + "/sparse/0/cameras.bin")) + "\n")
	f.store_string("colmap_images_bin=" + str(FileAccess.file_exists(msplat_dataset_root + "/sparse/0/images.bin")) + "\n")
	f.store_string("colmap_points3D_bin=" + str(FileAccess.file_exists(msplat_dataset_root + "/sparse/0/points3D.bin")) + "\n")
	f.close()


func _run_msplat_longer() -> void:
	msplat_num_iters = max(msplat_num_iters, 10000)
	if msplat_iters_option != null:
		msplat_iters_option.selected = 2
	_update_msplat_terminal_header()
	_append_msplat_terminal("$ Run Longer requested: " + str(msplat_num_iters) + " iterations. This retrains from the dataset; msplat-train does not expose a resume flag in the current CLI.")
	await _run_msplat_smoke_test()

func _expected_msplat_image_names() -> Array:
	var names: Array = []
	for c in cameras:
		names.append(_camera_unique_filename(c))
	return names

func _validate_msplat_sparse_image_hierarchy(dataset_root: String) -> Dictionary:
	var input_path = dataset_root
	if FileAccess.file_exists(dataset_root + "/sparse/0/cameras.bin") and FileAccess.file_exists(dataset_root + "/sparse/0/images.bin") and FileAccess.file_exists(dataset_root + "/sparse/0/points3D.bin"):
		input_path = dataset_root + "/sparse/0"
	var expected = _expected_msplat_image_names()
	var resolved = 0
	var missing = 0
	var first_missing = ""
	for name in expected:
		var p = input_path + "/" + str(name)
		if FileAccess.file_exists(p):
			resolved += 1
		else:
			missing += 1
			if first_missing == "":
				first_missing = p
	return {"input_path": input_path, "expected": expected.size(), "resolved": resolved, "missing": missing, "first_missing": first_missing}

func _run_msplat_smoke_test() -> void:
	var home = OS.get_environment("HOME")
	msplat_train_path = home + "/msplat-env/bin/msplat-train"
	if msplat_dataset_root == "":
		msplat_dataset_root = export_root_path + "/splatviz_msplat_dataset_" + SPLATVIZ_EXPORT_TAG
	# M6.5A: do not run an older transforms-only dataset. Rebuild/export the sparse seed bridge first.
	await _ensure_msplat_dataset_current()
	if not _msplat_dataset_is_ready(msplat_dataset_root):
		_append_msplat_terminal("$ ERROR: dataset is still not Msplat-ready after rebuild/export.")
		_append_msplat_terminal("$ Expected sparse/0/cameras.bin, images.bin, and points3D.bin, or a supported Polycam keyframes folder.")
		return
	var hierarchy = _validate_msplat_sparse_image_hierarchy(msplat_dataset_root)
	_append_msplat_terminal("$ Dataset hierarchy check: resolved " + str(hierarchy.get("resolved", 0)) + "/" + str(hierarchy.get("expected", 0)) + " COLMAP image files in " + str(hierarchy.get("input_path", "")))
	if int(hierarchy.get("missing", 0)) > 0:
		_append_msplat_terminal("$ ERROR: missing COLMAP image file before launch: " + str(hierarchy.get("first_missing", "")))
		_append_msplat_terminal("$ Fix: export a fresh " + SPLATVIZ_RELEASE_LABEL + " dataset. Msplat resolves image names relative to sparse/0, so the PNGs must live directly beside cameras.bin/images.bin/points3D.bin.")
		return
	msplat_result_root = export_root_path + "/splatviz_msplat_result_" + SPLATVIZ_EXPORT_TAG
	DirAccess.make_dir_recursive_absolute(msplat_result_root)
	var script_path = msplat_result_root + "/run_msplat.zsh"
	var log_path = msplat_result_root + "/train.log"
	var ply_path = msplat_result_root + "/splatviz_" + SPLATVIZ_EXPORT_TAG + "_" + _m65a_timestamp() + "_msplat_" + str(msplat_num_iters) + "iter.ply"
	msplat_log_path = log_path
	# M6.5A: remove stale outputs before launching so the terminal never parses an old
	# splat_ply=present marker and stops polling a fresh run.
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)
	if FileAccess.file_exists(ply_path):
		DirAccess.remove_absolute(ply_path)
	var boot = FileAccess.open(log_path, FileAccess.WRITE)
	if boot != null:
		boot.store_string("SplatViz Msplat run\nlaunching...\n")
		boot.close()
	msplat_running = true
	msplat_process_id = -1
	msplat_final_refresh_ticks = 0
	msplat_log_last_size = 0
	msplat_log_idle_seconds = 0.0
	msplat_stall_notice_shown = false
	msplat_last_phase = "launching"
	msplat_last_step = 0
	msplat_last_splats = 0
	if msplat_progress_bar:
		msplat_progress_bar.value = 1
	if msplat_progress_label:
		msplat_progress_label.text = "Starting Msplat · preparing dataset / launching trainer…"
	_update_msplat_terminal_header()
	_append_msplat_terminal("$ Running Msplat")
	_append_msplat_terminal(_msplat_command_string())
	var script = "#!/bin/zsh\n"
	script += "set -e\n"
	script += "echo 'SplatViz Msplat run' > " + _shell_quote(log_path) + "\n"
	script += "date >> " + _shell_quote(log_path) + "\n"
	script += "echo '' >> " + _shell_quote(log_path) + "\n"
	script += "echo 'Dataset validation' >> " + _shell_quote(log_path) + "\n"
	script += "echo 'dataset_root='" + _shell_quote(msplat_dataset_root) + " >> " + _shell_quote(log_path) + "\n"
	script += "test -f " + _shell_quote(msplat_dataset_root + "/transforms.json") + " && echo 'transforms.json=present' >> " + _shell_quote(log_path) + " || echo 'transforms.json=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "test -d " + _shell_quote(msplat_dataset_root + "/images") + " && echo 'images_dir=present' >> " + _shell_quote(log_path) + " || echo 'images_dir=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "test -f " + _shell_quote(msplat_dataset_root + "/splatviz_seed_points.ply") + " && echo 'seed_ply=present' >> " + _shell_quote(log_path) + " || echo 'seed_ply=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "test -f " + _shell_quote(msplat_dataset_root + "/sparse/0/cameras.bin") + " && echo 'colmap_cameras_bin=present' >> " + _shell_quote(log_path) + " || echo 'colmap_cameras_bin=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "test -f " + _shell_quote(msplat_dataset_root + "/sparse/0/images.bin") + " && echo 'colmap_images_bin=present' >> " + _shell_quote(log_path) + " || echo 'colmap_images_bin=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "test -f " + _shell_quote(msplat_dataset_root + "/sparse/0/points3D.bin") + " && echo 'colmap_points3D_bin=present' >> " + _shell_quote(log_path) + " || echo 'colmap_points3D_bin=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "echo 'msplat_input_path='" + _shell_quote(_msplat_input_path()) + " >> " + _shell_quote(log_path) + "\n"
	script += "test -f " + _shell_quote(_msplat_input_path() + "/CAM01_frame_000001.png") + " && echo 'colmap_resolved_image_CAM01=present' >> " + _shell_quote(log_path) + " || echo 'colmap_resolved_image_CAM01=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "test -f " + _shell_quote(_msplat_input_path() + "/images/images/CAM01_frame_000001.png") + " && echo 'colmap_bad_double_images_path=present' >> " + _shell_quote(log_path) + " || echo 'colmap_bad_double_images_path=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "test -f " + _shell_quote(msplat_dataset_root + "/sparse/0/splatviz_colmap_name_policy_m61.txt") + " && echo 'colmap_name_policy=m61_CAM##_frame_000001.png' >> " + _shell_quote(log_path) + " || echo 'colmap_name_policy=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "echo 'colmap_quaternion_order=qw_qx_qy_qz' >> " + _shell_quote(log_path) + "\n"
	script += "test -f " + _shell_quote(msplat_dataset_root + "/sparse/0/splatviz_colmap_seed_audit_m61.txt") + " && cat " + _shell_quote(msplat_dataset_root + "/sparse/0/splatviz_colmap_seed_audit_m61.txt") + " >> " + _shell_quote(log_path) + " || echo 'colmap_seed_tracks_policy=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "python3 -c " + _shell_quote("import json; p='" + msplat_dataset_root + "/transforms.json'; d=json.load(open(p)); keys=[k for k in ('fl_x','fl_y','cx','cy') if k in d]; print('transforms_top_level_intrinsics=' + ('present:' + ','.join(keys) if keys else 'absent')); print('transforms_frame_count=' + str(len(d.get('frames', [])))); print('transforms_sample_frame_flx=' + ','.join([str(round(float(fr.get('fl_x', 0)),3)) for fr in d.get('frames', [])[:5]]))") + " >> " + _shell_quote(log_path) + " 2>/dev/null || echo 'transforms_audit_error=python_failed' >> " + _shell_quote(log_path) + "\n"
	var expected_names = _expected_msplat_image_names()
	script += "echo 'colmap_expected_image_count=" + str(expected_names.size()) + "' >> " + _shell_quote(log_path) + "\n"
	script += "resolved=0; missing=0; first_missing=''\n"
	for nm in expected_names:
		var direct_path = _msplat_input_path() + "/" + str(nm)
		script += "if [ -f " + _shell_quote(direct_path) + " ]; then resolved=$((resolved+1)); else missing=$((missing+1)); if [ -z \"$first_missing\" ]; then first_missing=" + _shell_quote(direct_path) + "; fi; fi\n"
	script += "echo 'colmap_resolved_image_count='${resolved} >> " + _shell_quote(log_path) + "\n"
	script += "echo 'colmap_missing_image_count='${missing} >> " + _shell_quote(log_path) + "\n"
	script += "if [ ${missing} -gt 0 ]; then echo 'first_missing_image='${first_missing} >> " + _shell_quote(log_path) + "; echo 'ERROR: image hierarchy invalid; refusing to run Msplat' >> " + _shell_quote(log_path) + "; exit 3; fi\n"
	script += "find " + _shell_quote(msplat_dataset_root + "/images") + " -maxdepth 1 -type f | head -5 >> " + _shell_quote(log_path) + " 2>/dev/null || true\n"
	script += "echo '' >> " + _shell_quote(log_path) + "\n"
	script += "if [ ! -x " + _shell_quote(msplat_train_path) + " ]; then echo 'Missing msplat-train at " + msplat_train_path + "' >> " + _shell_quote(log_path) + "; exit 2; fi\n"
	script += "echo 'Starting msplat-train with COLMAP-preferred input; target iterations " + str(msplat_num_iters) + "' >> " + _shell_quote(log_path) + "\n"
	script += "set +e\n"
	script += "export PYTHONUNBUFFERED=1
"
	script += "export PYTHONIOENCODING=utf-8
"
	script += "HEALTH=" + _shell_quote(msplat_result_root + "/msplat_health.txt") + "
"
	script += "echo 'phase=launching' > \"$HEALTH\"
"
	script += _shell_quote(msplat_train_path) + " --input " + _shell_quote(_msplat_input_path()) + " --output " + _shell_quote(ply_path) + " --num-iters " + str(msplat_num_iters) + " --save-every 500 --eval --test-every 8 >> " + _shell_quote(log_path) + " 2>&1 &
"
	script += "train_pid=$!
"
	script += "monitor_pid=''
"
	script += "( while kill -0 $train_pid 2>/dev/null; do now=$(date +%s); psline=$(ps -p $train_pid -o pid=,%cpu=,%mem=,state= 2>/dev/null | awk '{print $1\" \"$2\" \"$3\" \"$4}'); cpu=$(echo $psline | awk '{print $2}'); mem=$(echo $psline | awk '{print $3}'); state=$(echo $psline | awk '{print $4}'); log_size=$(stat -f %z " + _shell_quote(log_path) + " 2>/dev/null || echo 0); log_mtime=$(stat -f %m " + _shell_quote(log_path) + " 2>/dev/null || echo 0); ply_size=$(stat -f %z " + _shell_quote(ply_path) + " 2>/dev/null || echo 0); echo \"time=$now phase=running train_pid=$train_pid cpu=${cpu:-0.0} mem=${mem:-0.0} state=${state:-?} log_mtime=$log_mtime log_size=$log_size ply_size=$ply_size\" > \"$HEALTH\"; sleep 2; done ) &
"
	script += "monitor_pid=$!
"
	script += "wait $train_pid
"
	script += "ec=$?
"
	script += "if [ -n \"$monitor_pid\" ]; then kill $monitor_pid 2>/dev/null || true; fi
"
	script += "echo \"time=$(date +%s) phase=finalized train_pid=$train_pid cpu=0.0 mem=0.0 state=done log_mtime=$(stat -f %m " + _shell_quote(log_path) + " 2>/dev/null || echo 0) log_size=$(stat -f %z " + _shell_quote(log_path) + " 2>/dev/null || echo 0) ply_size=$(stat -f %z " + _shell_quote(ply_path) + " 2>/dev/null || echo 0) exit_code=$ec\" > \"$HEALTH\"
"
	script += "echo '' >> " + _shell_quote(log_path) + "\n"
	script += "echo 'SplatViz run finished with exit code '${ec} >> " + _shell_quote(log_path) + "\n"
	script += "test -f " + _shell_quote(ply_path) + " && echo 'splat_ply=present' >> " + _shell_quote(log_path) + " || echo 'splat_ply=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "exit $ec\n"
	var f = FileAccess.open(script_path, FileAccess.WRITE)
	if f != null:
		f.store_string(script)
		f.close()
	OS.execute("/bin/chmod", ["+x", script_path], [])
	var pid = OS.create_process("/bin/zsh", [script_path])
	msplat_process_id = pid
	_append_msplat_terminal("$ Started process PID " + str(pid))
	if msplat_status_label:
		msplat_status_label.text = "Msplat running. PID " + str(pid) + ". Log: " + log_path
	if status_label:
		status_label.text = "Started Msplat run. Load Latest Splat after splat.ply appears. Log: " + log_path


func _m65a_timestamp() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d_%02d-%02d-%02d" % [int(dt["year"]), int(dt["month"]), int(dt["day"]), int(dt["hour"]), int(dt["minute"]), int(dt["second"])]

func _m65a_find_latest_ply(root_path: String) -> String:
	var best: Dictionary = {"path": "", "time": -1}
	_m65a_scan_ply_dir(root_path, best, 0)
	return str(best.get("path", ""))

func _m65a_scan_ply_dir(dir_path: String, best: Dictionary, depth: int) -> void:
	if depth > 5 or dir_path == "":
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var p := dir_path.path_join(name)
		if dir.current_is_dir():
			# Skip bulky source image folders; result folders and filtered previews are useful.
			if name == "images" or name == "sparse" or name == "keyframes":
				continue
			_m65a_scan_ply_dir(p, best, depth + 1)
		elif name.to_lower().ends_with(".ply"):
			var t := int(FileAccess.get_modified_time(p))
			if t > int(best.get("time", -1)):
				best["time"] = t
				best["path"] = p
	dir.list_dir_end()

func _load_latest_msplat_result() -> void:
	_append_msplat_terminal("$ Loading latest timestamped splat preview…")
	if msplat_result_root == "":
		msplat_result_root = export_root_path
	var ply_path := _m65a_find_latest_ply(msplat_result_root)
	if ply_path == "":
		ply_path = _m65a_find_latest_ply(export_root_path)
	if ply_path == "" or not FileAccess.file_exists(ply_path):
		_append_msplat_terminal("$ No .ply result found under: " + msplat_result_root)
		if msplat_status_label:
			msplat_status_label.text = "No .ply result found. Run Msplat or import a PLY manually."
		if status_label:
			status_label.text = "No Msplat result found yet. Check train.log or import a PLY."
		return
	latest_ply_path = ply_path
	var count := _load_ply_point_cloud(ply_path)
	_set_mode("Splat View")
	_append_msplat_terminal("$ Loaded latest PLY by timestamp/mtime: " + ply_path)
	_append_msplat_terminal("$ Visible preview records: " + str(count) + " · " + latest_ply_summary)
	if msplat_status_label:
		msplat_status_label.text = "Loaded latest PLY: " + str(count) + " visible records"
	if status_label:
		status_label.text = "Loaded latest timestamped PLY: " + ply_path + " · " + latest_ply_summary

func _write_colmap_dataset(dataset_root: String, cams: Array, size: Vector2i) -> void:
	var cam_txt = "# SplatViz synthetic COLMAP cameras\n# CAMERA_ID, MODEL, WIDTH, HEIGHT, PARAMS[]\n"
	var img_txt = "# SplatViz synthetic COLMAP images\n# IMAGE_ID, QW, QX, QY, QZ, TX, TY, TZ, CAMERA_ID, NAME\n# POINTS2D[] left empty for synthetic Msplat run\n"
	for i in range(cams.size()):
		var c = cams[i]
		var camera_id = i + 1
		var image_id = i + 1
		var intr = _m66d_capture_intrinsics(c, size)
		var fx = float(intr["fx"])
		var fy = float(intr["fy"])
		var cx = float(intr["cx"])
		var cy = float(intr["cy"])
		cam_txt += "%d PINHOLE %d %d %.8f %.8f %.8f %.8f\n" % [camera_id, size.x, size.y, fx, fy, cx, cy]
		var pose = _colmap_pose(c)
		img_txt += "%d %.10f %.10f %.10f %.10f %.10f %.10f %.10f %d %s\n\n" % [image_id, pose[0], pose[1], pose[2], pose[3], pose[4], pose[5], pose[6], camera_id, _camera_unique_filename(c)]
	var f1 = FileAccess.open(dataset_root + "/sparse/0/cameras.txt", FileAccess.WRITE)
	if f1 != null:
		f1.store_string(cam_txt)
		f1.close()
	var f2 = FileAccess.open(dataset_root + "/sparse/0/images.txt", FileAccess.WRITE)
	if f2 != null:
		f2.store_string(img_txt)
		f2.close()
	var f3 = FileAccess.open(dataset_root + "/sparse/0/points3D.txt", FileAccess.WRITE)
	if f3 != null:
		f3.store_string("# Empty synthetic seed. Cameras are authored by SplatViz.\n")
		f3.close()


func _mirror_images_to_colmap_sparse(dataset_root: String) -> void:
	# M6.5A policy: COLMAP images.bin NAME is the unique flat filename, e.g.
	# CAM01_frame_000001.png. Msplat resolves NAME relative to the --input
	# sparse folder, so the file must exist directly in sparse/0/. Keep root
	# images/ for Nerfstudio/debug workflows and sparse/0/images/ only as a
	# compatibility mirror.
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0")
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0/images")
	for c in cameras:
		var unique_name = _camera_unique_filename(c)
		var src = dataset_root + "/images/" + unique_name
		var dst_direct = dataset_root + "/sparse/0/" + unique_name
		var dst_compat = dataset_root + "/sparse/0/images/" + unique_name
		if FileAccess.file_exists(src):
			_copy_binary_file(src, dst_direct)
			_copy_binary_file(src, dst_compat)

func _write_cstring(f: FileAccess, text: String) -> void:
	f.store_buffer(text.to_utf8_buffer())
	f.store_8(0)

func _write_colmap_binary_dataset(dataset_root: String, cams: Array, size: Vector2i) -> void:
	# Binary COLMAP sparse export for Msplat. This is authored from known SplatViz poses,
	# not triangulated by COLMAP/GLOMAP. M6.5A adds synthetic projected 2D tracks so
	# the COLMAP sparse model is internally coherent instead of a trackless point seed.
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0")
	var seed_ply = dataset_root + "/splatviz_seed_points.ply"
	var obs = _build_colmap_seed_observations(cams, seed_ply, size)
	_write_colmap_cameras_bin(dataset_root + "/sparse/0/cameras.bin", cams, size)
	_write_colmap_images_bin(dataset_root + "/sparse/0/images.bin", cams, obs.get("image_observations", []))
	_write_colmap_points3d_bin(dataset_root + "/sparse/0/points3D.bin", obs)
	_write_colmap_seed_audit(dataset_root, obs)

func _colmap_intrinsics_for(c: Dictionary, size: Vector2i) -> Dictionary:
	return _m66d_capture_intrinsics(c, size)

func _write_colmap_cameras_bin(path: String, cams: Array, size: Vector2i) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_64(cams.size())
	for i in range(cams.size()):
		var c = cams[i]
		var camera_id = i + 1
		var model_id = 1 # PINHOLE
		var intr = _colmap_intrinsics_for(c, size)
		f.store_32(camera_id)
		f.store_32(model_id)
		f.store_64(size.x)
		f.store_64(size.y)
		f.store_double(float(intr["fx"]))
		f.store_double(float(intr["fy"]))
		f.store_double(float(intr["cx"]))
		f.store_double(float(intr["cy"]))
	f.close()

func _write_colmap_images_bin(path: String, cams: Array, image_observations: Array) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_64(cams.size())
	for i in range(cams.size()):
		var c = cams[i]
		var image_id = i + 1
		var camera_id = i + 1
		var pose = _colmap_pose(c)
		f.store_32(image_id)
		f.store_double(float(pose[0])) # qw
		f.store_double(float(pose[1])) # qx
		f.store_double(float(pose[2])) # qy
		f.store_double(float(pose[3])) # qz
		f.store_double(float(pose[4])) # tx
		f.store_double(float(pose[5])) # ty
		f.store_double(float(pose[6])) # tz
		f.store_32(camera_id)
		_write_cstring(f, _camera_unique_filename(c))
		var obs: Array = []
		if i < image_observations.size():
			obs = image_observations[i]
		f.store_64(obs.size())
		for o in obs:
			f.store_double(float(o["x"]))
			f.store_double(float(o["y"]))
			f.store_64(int(o["point3d_id"]))
	f.close()

func _read_seed_ply_vertices(path: String) -> Array:
	var verts: Array = []
	if not FileAccess.file_exists(path):
		return verts
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return verts
	var txt = f.get_as_text()
	f.close()
	var in_body = false
	for l in txt.split("\n"):
		var line = str(l).strip_edges()
		if line == "end_header":
			in_body = true
			continue
		if not in_body or line == "":
			continue
		var p = line.split(" ", false)
		if p.size() >= 6:
			verts.append({"x": float(p[0]), "y": float(p[1]), "z": float(p[2]), "r": int(p[3]), "g": int(p[4]), "b": int(p[5])})
	return verts

func _write_colmap_points3d_bin(path: String, obs: Dictionary) -> void:
	var verts: Array = obs.get("kept_vertices", [])
	var tracks: Dictionary = obs.get("tracks", {})
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_64(verts.size())
	for i in range(verts.size()):
		var point_id = i + 1
		var v = verts[i]
		f.store_64(point_id) # POINT3D_ID
		f.store_double(float(v["x"]))
		f.store_double(float(v["y"]))
		f.store_double(float(v["z"]))
		f.store_8(int(v["r"]))
		f.store_8(int(v["g"]))
		f.store_8(int(v["b"]))
		f.store_double(0.0) # reprojection error unknown for synthetic seed
		var tr: Array = tracks.get(point_id, [])
		f.store_64(tr.size())
		for t in tr:
			f.store_32(int(t["image_id"]))
			f.store_32(int(t["point2d_idx"]))
	f.close()

func _project_seed_point_to_colmap_camera(c: Dictionary, p: Vector3, size: Vector2i) -> Dictionary:
	var axes = _m66d_capture_axes(c)
	var rel = p - (axes["position"] as Vector3)
	var xc = (axes["right"] as Vector3).dot(rel)
	var yc = -(axes["up"] as Vector3).dot(rel)
	var zc = (axes["forward"] as Vector3).dot(rel)
	if zc <= 0.05:
		return {}
	var intr = _colmap_intrinsics_for(c, size)
	var u = float(intr["fx"]) * xc / zc + float(intr["cx"])
	var v = float(intr["fy"]) * yc / zc + float(intr["cy"])
	if u < 0.0 or u >= float(size.x) or v < 0.0 or v >= float(size.y):
		return {}
	return {"x": u, "y": v}

func _build_colmap_seed_observations(cams: Array, seed_ply: String, size: Vector2i) -> Dictionary:
	var verts = _read_seed_ply_vertices(seed_ply)
	var temp_obs: Array = []
	for i in range(verts.size()):
		temp_obs.append([])
	for vi in range(verts.size()):
		var v = verts[vi]
		var p = Vector3(float(v["x"]), float(v["y"]), float(v["z"]))
		for ci in range(cams.size()):
			var pr = _project_seed_point_to_colmap_camera(cams[ci], p, size)
			if pr.has("x"):
				temp_obs[vi].append({"image_id": ci + 1, "x": float(pr["x"]), "y": float(pr["y"])})
	var id_map: Dictionary = {}
	var kept: Array = []
	for vi in range(verts.size()):
		# Keep only points with multi-view support so the COLMAP seed is coherent.
		if temp_obs[vi].size() >= 2:
			var point_id = kept.size() + 1
			id_map[vi] = point_id
			kept.append(verts[vi])
	var image_observations: Array = []
	for ci in range(cams.size()):
		image_observations.append([])
	var tracks: Dictionary = {}
	for pi in range(kept.size()):
		tracks[pi + 1] = []
	var total_obs = 0
	for vi in range(verts.size()):
		if not id_map.has(vi):
			continue
		var point_id = int(id_map[vi])
		for o in temp_obs[vi]:
			var image_id = int(o["image_id"])
			var img_idx = image_id - 1
			var point2d_idx = image_observations[img_idx].size()
			image_observations[img_idx].append({"x": float(o["x"]), "y": float(o["y"]), "point3d_id": point_id})
			tracks[point_id].append({"image_id": image_id, "point2d_idx": point2d_idx})
			total_obs += 1
	return {"source_vertices": verts.size(), "kept_vertices": kept, "image_observations": image_observations, "tracks": tracks, "total_observations": total_obs}

func _write_colmap_seed_audit(dataset_root: String, obs: Dictionary) -> void:
	var path = dataset_root + "/sparse/0/splatviz_colmap_seed_audit_m61.txt"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("colmap_seed_tracks_policy=m61_mesh_surface_rgb_sampled_seed_tracks\n")
	f.store_string("colmap_seed_source_vertices=" + str(obs.get("source_vertices", 0)) + "\n")
	f.store_string("colmap_seed_point3d_count=" + str((obs.get("kept_vertices", []) as Array).size()) + "\n")
	f.store_string("colmap_seed_observation_count=" + str(obs.get("total_observations", 0)) + "\n")
	f.store_string("colmap_pose_convention=" + SPLATVIZ_EXPORT_TAG + "_world_to_camera_rows_xright_ydown_zforward_mesh_surface_rgb_seed_clean_visibility_qw_qx_qy_qz\n")
	f.close()

func _append_seed_point(points: Array, x: float, y: float, z: float, r: int, g: int, b: int) -> void:
	points.append("%.5f %.5f %.5f %d %d %d" % [x, y, z, r, g, b])

func _seed_box(points: Array, center: Vector3, size: Vector3, r: int, g: int, b: int, steps_x: int, steps_y: int, steps_z: int) -> void:
	var hx = size.x * 0.5
	var hy = size.y * 0.5
	var hz = size.z * 0.5
	for ix in range(steps_x):
		var tx = float(ix) / float(max(1, steps_x - 1))
		var x = center.x - hx + tx * size.x
		for iy in range(steps_y):
			var ty = float(iy) / float(max(1, steps_y - 1))
			var y = center.y - hy + ty * size.y
			_append_seed_point(points, x, y, center.z - hz, r, g, b)
			_append_seed_point(points, x, y, center.z + hz, r, g, b)
	for ix in range(steps_x):
		var tx2 = float(ix) / float(max(1, steps_x - 1))
		var x2 = center.x - hx + tx2 * size.x
		for iz in range(steps_z):
			var tz = float(iz) / float(max(1, steps_z - 1))
			var z = center.z - hz + tz * size.z
			_append_seed_point(points, x2, center.y - hy, z, r, g, b)
			_append_seed_point(points, x2, center.y + hy, z, r, g, b)
	for iy in range(steps_y):
		var ty2 = float(iy) / float(max(1, steps_y - 1))
		var y2 = center.y - hy + ty2 * size.y
		for iz in range(steps_z):
			var tz2 = float(iz) / float(max(1, steps_z - 1))
			var z2 = center.z - hz + tz2 * size.z
			_append_seed_point(points, center.x - hx, y2, z2, r, g, b)
			_append_seed_point(points, center.x + hx, y2, z2, r, g, b)

func _seed_sphere(points: Array, center: Vector3, radius: float, r: int, g: int, b: int, rings: int, segments: int) -> void:
	for i in range(rings):
		var v = float(i) / float(max(1, rings - 1))
		var theta = v * PI
		var sy = cos(theta)
		var sr = sin(theta)
		for j in range(segments):
			var u = float(j) / float(segments)
			var phi = u * TAU
			var x = center.x + cos(phi) * sr * radius
			var y = center.y + sy * radius
			var z = center.z + sin(phi) * sr * radius
			_append_seed_point(points, x, y, z, r, g, b)


const M63_SEED_SAMPLES_PER_TRIANGLE := 4
const M63_SEED_MIN_OBS := 6
const M63_SEED_BACKFACE_DOT_MIN := -0.3
const M63_SEED_MAX_POINTS := 20000
# Minimum acceptable bounding-box span (meters) for the seed cloud. Anything
# below this is treated as a degenerate origin-only cloud and flagged loudly.
const SEED_MIN_BBOX_SPAN_M := 0.05
const M63_MIN_SEED_POINTS := 1000

func _write_seed_point_cloud_ply(dataset_root: String, cams: Array, size: Vector2i) -> Array:
	var candidates: Array = _collect_mesh_surface_samples_m61()
	var raw_count: int = candidates.size()
	var rgb_stats: Dictionary = {}
	var filtered: Array = []
	var points: Array = []
	var obs_hist: Array = []
	var seed_source: String = "mesh_surface_rgb_sampled"

	if raw_count >= 1000:
		filtered = _filter_seed_by_visibility_rgb_m61(candidates, cams, size, dataset_root, rgb_stats)
		if filtered.size() > M63_SEED_MAX_POINTS:
			filtered = _stride_cap_seed_candidates_m61(filtered, M63_SEED_MAX_POINTS)
		for item_v in filtered:
			var item: Dictionary = item_v as Dictionary
			var p: Vector3 = item["p"] as Vector3
			var col: Color = item["color"] as Color
			# NOTE: append structured points, not pre-formatted strings.
			# _write_seed_points_ply_m61 / _write_seed_diagnostics_m61 re-read each
			# element via _seed_point_pos_m61 / _seed_point_color_m61, which only
			# understand Vector3 or Dictionary. A String falls through and collapses
			# to Vector3.ZERO + default grey, which silently wrote 20k origin points.
			points.append({"p": p, "color": col})
			obs_hist.append(int(item["obs"]))

	# If mesh traversal failed completely, fall back to the previous proxy writer so export remains usable.
	# If mesh traversal succeeds but produces too few visible points, do NOT hide that with a fallback;
	# the M63 diagnostics gate should fail loudly instead.
	if raw_count < 1000 or points.size() == 0:
		seed_source = "proxy_fallback"
		_write_seed_point_cloud_ply_proxy(dataset_root)
		var fallback_points: Array = _read_seed_ply_vertices(dataset_root + "/splatviz_seed_points.ply")
		_write_seed_diagnostics_m61(dataset_root, seed_source, raw_count, fallback_points.size(), fallback_points, [], rgb_stats)
		return fallback_points

	_write_seed_points_ply_m61(dataset_root, points)
	_write_seed_diagnostics_m61(dataset_root, seed_source, raw_count, points.size(), points, obs_hist, rgb_stats)
	return points

func _collect_mesh_surface_samples_m61() -> Array:
	var samples: Array = []
	var root_node: Node = null
	if robot_model_root != null:
		root_node = robot_model_root
	elif performer_root != null:
		root_node = performer_root
	if root_node == null:
		return samples
	_collect_mesh_surface_samples_from_node_m61(root_node, samples)
	return samples

func _collect_mesh_surface_samples_from_node_m61(node: Node, samples: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			_collect_mesh_surface_samples_from_mesh_m61(mi, samples)
	for child in node.get_children():
		_collect_mesh_surface_samples_from_node_m61(child, samples)

func _collect_mesh_surface_samples_from_mesh_m61(mi: MeshInstance3D, samples: Array) -> void:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return
	for si in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(si)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		if arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.size() < 3:
			continue

		var normals: PackedVector3Array
		if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] != null:
			normals = arrays[Mesh.ARRAY_NORMAL]
		else:
			normals = PackedVector3Array()

		var indices: PackedInt32Array
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		else:
			indices = PackedInt32Array()

		if indices.size() >= 3:
			var tri_count: int = int(indices.size() / 3)
			for ti in range(tri_count):
				var ia := int(indices[ti * 3 + 0])
				var ib := int(indices[ti * 3 + 1])
				var ic := int(indices[ti * 3 + 2])
				if ia < 0 or ib < 0 or ic < 0 or ia >= verts.size() or ib >= verts.size() or ic >= verts.size():
					continue
				_add_triangle_seed_samples_m61(mi, verts, normals, ia, ib, ic, samples)
		else:
			var tri_count_unindexed: int = int(verts.size() / 3)
			for ti in range(tri_count_unindexed):
				_add_triangle_seed_samples_m61(mi, verts, normals, ti * 3 + 0, ti * 3 + 1, ti * 3 + 2, samples)

func _add_triangle_seed_samples_m61(mi: MeshInstance3D, verts: PackedVector3Array, normals: PackedVector3Array, ia: int, ib: int, ic: int, samples: Array) -> void:
	var wa: Vector3 = mi.global_transform * verts[ia]
	var wb: Vector3 = mi.global_transform * verts[ib]
	var wc: Vector3 = mi.global_transform * verts[ic]
	var face_normal: Vector3 = (wb - wa).cross(wc - wa).normalized()

	if normals.size() > ia and normals.size() > ib and normals.size() > ic:
		var na: Vector3 = (mi.global_transform.basis * normals[ia]).normalized()
		var nb: Vector3 = (mi.global_transform.basis * normals[ib]).normalized()
		var nc: Vector3 = (mi.global_transform.basis * normals[ic]).normalized()
		var avg_n: Vector3 = (na + nb + nc).normalized()
		if avg_n.length() > 0.001:
			face_normal = avg_n

	if face_normal.length() < 0.001:
		return

	var bary: Array = [
		Vector3(0.333333, 0.333333, 0.333334),
		Vector3(0.600000, 0.200000, 0.200000),
		Vector3(0.200000, 0.600000, 0.200000),
		Vector3(0.200000, 0.200000, 0.600000),
	]
	for i in range(M63_SEED_SAMPLES_PER_TRIANGLE):
		var w: Vector3 = bary[i % bary.size()] as Vector3
		var p: Vector3 = wa * w.x + wb * w.y + wc * w.z
		samples.append({"p": p, "n": face_normal})

func _seed_camera_image_name(c: Dictionary) -> String:
	return _camera_unique_filename(c)

func _filter_seed_by_visibility_rgb_m61(candidates: Array, cams: Array, size: Vector2i, dataset_root: String, stats: Dictionary) -> Array:
	var cam_data: Array = []
	for c in cams:
		var img: Image = Image.new()
		var img_ok: bool = false
		var img_path: String = dataset_root + "/images/" + _seed_camera_image_name(c)
		if FileAccess.file_exists(img_path):
			var err: Error = img.load(img_path)
			img_ok = err == OK
		cam_data.append({"c": c, "img": img, "img_ok": img_ok})

	var imgs_loaded: int = 0
	for cd_v in cam_data:
		var cd: Dictionary = cd_v as Dictionary
		if bool(cd["img_ok"]):
			imgs_loaded += 1
	stats["images_loaded_for_rgb"] = "%d/%d" % [imgs_loaded, cam_data.size()]

	var filtered: Array = []
	for cand_v in candidates:
		var cand: Dictionary = cand_v as Dictionary
		var p: Vector3 = cand["p"] as Vector3
		var n: Vector3 = cand["n"] as Vector3
		var obs: int = 0
		var cr: float = 0.0
		var cg: float = 0.0
		var cb: float = 0.0
		var color_hits: int = 0

		for cd_v in cam_data:
			var cd: Dictionary = cd_v as Dictionary
			var cam: Dictionary = cd["c"] as Dictionary
			var uv: Dictionary = _project_seed_point_to_colmap_camera(cam, p, size)
			if uv.is_empty():
				continue

			if n.length() > 0.001:
				var cam_pos: Vector3 = cam["position"] as Vector3
				var to_cam: Vector3 = (cam_pos - p).normalized()
				if n.dot(to_cam) < M63_SEED_BACKFACE_DOT_MIN:
					continue

			if bool(cd["img_ok"]):
				var img: Image = cd["img"] as Image
				var px: int = int(clamp(int(round(float(uv["x"]))), 0, img.get_width() - 1))
				var py: int = int(clamp(int(round(float(uv["y"]))), 0, img.get_height() - 1))
				var sample: Color = img.get_pixel(px, py)
				if not _seed_rgb_sample_valid(sample):
					continue
				cr += sample.r
				cg += sample.g
				cb += sample.b
				color_hits += 1
				obs += 1
			else:
				obs += 1

		if obs >= M63_SEED_MIN_OBS:
			var col: Color = Color(0.72, 0.78, 0.76)
			if color_hits > 0:
				col = Color(cr / float(color_hits), cg / float(color_hits), cb / float(color_hits))
			filtered.append({"p": p, "n": n, "obs": obs, "color": col})
	return filtered

func _seed_rgb_sample_valid(c: Color) -> bool:
	# Reject the dark teal-black render background from the clean images.
	# This is safer than luma rejection because dark robot details may be valid.
	if c.r < 0.04 and c.g < 0.12 and c.b < 0.14:
		return false
	# Reject red projection-audit dots if an overlay image is accidentally sampled.
	if c.r > 0.80 and c.g < 0.25 and c.b < 0.25:
		return false
	return true

func _stride_cap_seed_candidates_m61(items: Array, max_count: int) -> Array:
	if items.size() <= max_count:
		return items
	var capped: Array = []
	var step: float = float(items.size()) / float(max_count)
	for i in range(max_count):
		var idx: int = int(floor(float(i) * step))
		idx = clamp(idx, 0, items.size() - 1)
		capped.append(items[idx])
	return capped

func _write_seed_points_ply_m61(dataset_root: String, points: Array) -> void:
	var f := FileAccess.open(dataset_root + "/splatviz_seed_points.ply", FileAccess.WRITE)
	if f == null:
		push_warning("Could not write " + SPLATVIZ_RELEASE_LABEL + " seed PLY")
		return
	f.store_string("ply\n")
	f.store_string("format ascii 1.0\n")
	f.store_string("element vertex %d\n" % points.size())
	f.store_string("property float x\n")
	f.store_string("property float y\n")
	f.store_string("property float z\n")
	f.store_string("property uchar red\n")
	f.store_string("property uchar green\n")
	f.store_string("property uchar blue\n")
	f.store_string("end_header\n")
	for sp in points:
		var p: Vector3 = _seed_point_pos_m61(sp)
		var col: Color = _seed_point_color_m61(sp)
		f.store_string("%.6f %.6f %.6f %d %d %d\n" % [p.x, p.y, p.z, int(round(col.r * 255.0)), int(round(col.g * 255.0)), int(round(col.b * 255.0))])
	f.close()

func _seed_point_pos_m61(sp: Variant) -> Vector3:
	if sp is Vector3:
		return sp as Vector3
	if sp is Dictionary:
		var d: Dictionary = sp as Dictionary
		if d.has("p"):
			return d["p"] as Vector3
		if d.has("pos"):
			return d["pos"] as Vector3
		if d.has("position"):
			return d["position"] as Vector3
		if d.has("x") and d.has("y") and d.has("z"):
			return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
		if d.has("–") and d.has("y") and d.has("z"):
			return Vector3(float(d["–"]), float(d["y"]), float(d["z"]))
	return Vector3.ZERO

func _seed_point_color_m61(sp: Variant) -> Color:
	if sp is Dictionary:
		var d: Dictionary = sp as Dictionary
		if d.has("color"):
			return d["color"] as Color
		if d.has("r") and d.has("g") and d.has("b"):
			return Color(float(d["r"]) / 255.0, float(d["g"]) / 255.0, float(d["b"]) / 255.0)
		if d.has("red") and d.has("green") and d.has("blue"):
			return Color(float(d["red"]) / 255.0, float(d["green"]) / 255.0, float(d["blue"]) / 255.0)
	return Color(0.72, 0.78, 0.76)

func _write_seed_diagnostics_m61(dataset_root: String, seed_source: String, raw_count: int, kept_count: int, points: Array, obs_hist: Array, rgb_stats: Dictionary) -> void:
	var f := FileAccess.open(dataset_root + "/splatviz_seed_diagnostics_m61.txt", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(SPLATVIZ_RELEASE_LABEL + " seed diagnostics\n")
	f.store_string("seed_source=%s\n" % seed_source)
	f.store_string("rgb_sampling=enabled_clean_render_pngs\n")
	f.store_string("images_loaded_for_rgb=%s\n" % str(rgb_stats.get("images_loaded_for_rgb", "unknown")))
	f.store_string("raw_candidates=%d\n" % raw_count)
	f.store_string("kept_after_visibility=%d\n" % kept_count)
	f.store_string("min_required_obs=%d\n" % M63_SEED_MIN_OBS)

	var obs_sum: int = 0
	var obs_max: int = 0
	for o in obs_hist:
		var oi: int = int(o)
		obs_sum += oi
		if oi > obs_max:
			obs_max = oi
	var obs_mean: float = 0.0
	if obs_hist.size() > 0:
		obs_mean = float(obs_sum) / float(obs_hist.size())
	f.store_string("obs_per_point_mean=%.3f\n" % obs_mean)
	f.store_string("obs_per_point_max=%d\n" % obs_max)

	var mn: Vector3 = Vector3(1.0e20, 1.0e20, 1.0e20)
	var mx: Vector3 = Vector3(-1.0e20, -1.0e20, -1.0e20)
	for sp in points:
		var p: Vector3 = _seed_point_pos_m61(sp)
		mn.x = min(mn.x, p.x); mn.y = min(mn.y, p.y); mn.z = min(mn.z, p.z)
		mx.x = max(mx.x, p.x); mx.y = max(mx.y, p.y); mx.z = max(mx.z, p.z)
	if points.size() > 0:
		var span: Vector3 = mx - mn
		f.store_string("bbox_min=%.6f,%.6f,%.6f\n" % [mn.x, mn.y, mn.z])
		f.store_string("bbox_max=%.6f,%.6f,%.6f\n" % [mx.x, mx.y, mx.z])
		f.store_string("bbox_span=%.6f,%.6f,%.6f\n" % [span.x, span.y, span.z])
		# Guard: a seed cloud with no spatial extent hands Msplat an empty geometric
		# prior and produces "cut"/degenerate splats. Fail loudly instead of shipping it.
		var max_span: float = max(span.x, max(span.y, span.z))
		if max_span < SEED_MIN_BBOX_SPAN_M:
			f.store_string("seed_health=DEGENERATE_ZERO_EXTENT\n")
			push_error("SplatViz seed PLY is degenerate: bbox span %.6f m < %.3f m (origin-only cloud). Msplat will not reconstruct correctly." % [max_span, SEED_MIN_BBOX_SPAN_M])
		else:
			f.store_string("seed_health=OK\n")
	else:
		f.store_string("bbox_span=0,0,0\n")
		f.store_string("seed_health=DEGENERATE_NO_POINTS\n")
		push_error("SplatViz seed PLY has zero points.")
	f.close()

func _write_seed_point_cloud_ply_proxy(dataset_root: String) -> void:
	# Msplat accepted the Nerfstudio transforms in M3.5 but initialized zero Gaussians.
	# This synthetic point cloud gives the trainer deterministic initial geometry in the same
	# coordinate system as the SplatViz cameras. It is not ground truth; it is a smoke-test seed.
	var points: Array = []
	# white/blue robot proxy at 5 ft 11 in centered on stage
	_seed_box(points, Vector3(0.0, 1.03, 0.0), Vector3(0.46, 0.62, 0.22), 232, 238, 232, 18, 22, 8) # torso
	_seed_sphere(points, Vector3(0.0, 1.53, 0.0), 0.18, 235, 240, 235, 18, 32) # head
	_seed_box(points, Vector3(-0.33, 1.02, 0.0), Vector3(0.13, 0.58, 0.13), 232, 238, 232, 8, 20, 6) # left arm
	_seed_box(points, Vector3(0.33, 1.02, 0.0), Vector3(0.13, 0.58, 0.13), 232, 238, 232, 8, 20, 6) # right arm
	_seed_sphere(points, Vector3(-0.33, 0.66, 0.0), 0.075, 16, 18, 18, 10, 16)
	_seed_sphere(points, Vector3(0.33, 0.66, 0.0), 0.075, 16, 18, 18, 10, 16)
	_seed_box(points, Vector3(-0.12, 0.38, 0.0), Vector3(0.13, 0.62, 0.13), 232, 238, 232, 8, 20, 6) # left leg
	_seed_box(points, Vector3(0.12, 0.38, 0.0), Vector3(0.13, 0.62, 0.13), 232, 238, 232, 8, 20, 6) # right leg
	_seed_box(points, Vector3(-0.12, 0.04, 0.05), Vector3(0.20, 0.08, 0.25), 232, 238, 232, 8, 5, 10)
	_seed_box(points, Vector3(0.12, 0.04, 0.05), Vector3(0.20, 0.08, 0.25), 232, 238, 232, 8, 5, 10)
	# blue high-frequency details for reconstruction sanity checks
	_seed_box(points, Vector3(-0.065, 1.56, -0.17), Vector3(0.05, 0.035, 0.02), 0, 92, 255, 5, 4, 2)
	_seed_box(points, Vector3(0.065, 1.56, -0.17), Vector3(0.05, 0.035, 0.02), 0, 92, 255, 5, 4, 2)
	_seed_box(points, Vector3(0.0, 1.08, -0.12), Vector3(0.22, 0.20, 0.02), 0, 92, 255, 10, 8, 2)
	_seed_sphere(points, Vector3(0.0, 0.94, -0.13), 0.055, 0, 92, 255, 8, 16)
	# M6.5A: floor/platform seed removed. Seed points are robot-only to prevent stage-plane floaters.
	var ply = "ply\nformat ascii 1.0\n"
	ply += "comment SplatViz synthetic seed point cloud for Msplat initialization\n"
	ply += "element vertex " + str(points.size()) + "\n"
	ply += "property float x\nproperty float y\nproperty float z\n"
	ply += "property uchar red\nproperty uchar green\nproperty uchar blue\n"
	ply += "end_header\n"
	for line in points:
		ply += str(line) + "\n"
	var f = FileAccess.open(dataset_root + "/splatviz_seed_points.ply", FileAccess.WRITE)
	if f != null:
		f.store_string(ply)
		f.close()

func _write_nerfstudio_transforms(dataset_root: String, cams: Array, size: Vector2i) -> void:
	var frames: Array = []
	for c in cams:
		var fd = float(c["focus_m"])
		var intr = _m66d_capture_intrinsics(c, size)
		frames.append({
			"file_path": "images/" + _camera_unique_filename(c),
			"fl_x": float(intr["fx"]),
			"fl_y": float(intr["fy"]),
			"cx": float(intr["cx"]),
			"cy": float(intr["cy"]),
			"w": size.x,
			"h": size.y,
			"camera_id": str(c["id"]),
			"splatviz_tier": str(c["tier"]),
			"splatviz_focus_distance_m": fd,
			"transform_matrix": _nerfstudio_transform(c)
		})
	# M6.5A: do not write top-level fl_x/fl_y/cx/cy. Mixed portrait/landscape cameras
	# have per-frame intrinsics, and duplicate top-level intrinsics created a conflict
	# in downstream loaders/audits. Each frame now carries the render-matched focal length.
	var doc = {
		"camera_model": "PINHOLE",
		"w": size.x,
		"h": size.y,
		"aabb_scale": 8,
		"orientation_override": "none",
		"ply_file_path": "splatviz_seed_points.ply",
		"pointcloud_path": "splatviz_seed_points.ply",
		"splatviz_seed_point_cloud": "splatviz_seed_points.ply",
		"splatviz_version": SPLATVIZ_RELEASE_LABEL,
		"app_release_label": SPLATVIZ_RELEASE_LABEL,
		"export_tag": SPLATVIZ_EXPORT_TAG,
		"splatviz_intrinsics_policy": "No top-level intrinsics; per-frame fl_x/fl_y/cx/cy match the exact Godot render camera for each view.",
		"splatviz_note": "Synthetic Nerfstudio-style transforms authored by SplatViz; " + SPLATVIZ_RELEASE_LABEL + " uses robot-only seed points; production conclusions require gsplat validation.",
		"frames": frames
	}
	var f = FileAccess.open(dataset_root + "/transforms.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(doc, "  "))
		f.close()

func _nerfstudio_transform(c: Dictionary) -> Array:
	var axes = _m66d_capture_axes(c)
	var pos = axes["position"] as Vector3
	var right = axes["right"] as Vector3
	var up = axes["up"] as Vector3
	var z_axis = axes["back"] as Vector3
	return [
		[right.x, up.x, z_axis.x, pos.x],
		[right.y, up.y, z_axis.y, pos.y],
		[right.z, up.z, z_axis.z, pos.z],
		[0.0, 0.0, 0.0, 1.0]
	]

func _write_msplat_manifest(dataset_root: String, cams: Array, size: Vector2i, export_timestamp: String = "") -> void:
	if export_timestamp == "":
		export_timestamp = _m68a_timestamp()
	var volume = _m67h_capture_volume()
	var counts = _m67h_qc_counts(cams)
	var volume_counts = _m67h_volume_qc_counts(cams)
	var entries = []
	for c in cams:
		var pos: Vector3 = c["position"] as Vector3
		entries.append({
			"camera_id": str(c["id"]),
			"image": "images/" + _camera_unique_filename(c),
			"position_m": [pos.x, pos.y, pos.z],
			"aim_target_m": _m67h_vec3_to_array(_m67h_camera_aim_target(c)),
			"focus_target_m": _m67h_vec3_to_array(_m67h_camera_focus_target(c)),
			"focus_distance_m": float(c["focus_m"]),
			"tier": str(c["tier"]),
			"portrait_roll": bool(c["portrait"]),
			"projected_px_cm": float(c["px_cm"]),
			"frame_qc_status": str(c.get("frame_qc_status", "UNKNOWN")),
			"frame_qc_reason": str(c.get("frame_qc_reason", "")),
			"frame_qc_margins": c.get("frame_qc_margins", {}),
			"frame_qc_recommendation": str(c.get("frame_qc_recommendation", "")),
			"export_policy": _m67h_export_policy(c)
		})
	var manifest = {
		"splatviz_version": SPLATVIZ_RELEASE_LABEL,
		"app_release_label": SPLATVIZ_RELEASE_LABEL,
		"export_tag": SPLATVIZ_EXPORT_TAG,
		"export_timestamp": export_timestamp,
		"layout_profile": layout_name,
		"render_width": size.x,
		"render_height": size.y,
		"camera_count": cams.size(),
		"subject_qc_counts": counts,
		"volume_qc_counts": volume_counts,
		"dataset_type": "nerfstudio_transforms_plus_colmap_binary_sparse",
		"dataset_root": dataset_root,
		"images": "images/CAM##_frame_000001.png",
		"nerfstudio_transforms": "transforms.json",
		"seed_point_cloud": "splatviz_seed_points.ply",
		"resolution_px": [size.x, size.y],
		"layout": layout_name,
		"installation_mode": installation_mode,
		"frame_qc_counts": counts,
		"unsafe_override_used": m67h_last_dataset_unsafe_override_used,
		"omitted_camera_ids": m67h_last_dataset_omitted_camera_ids,
		"capture_volume": {
			"center_m": _m67h_vec3_to_array(volume.get("center", TARGET)),
			"size_m": _m67h_vec3_to_array(volume.get("size", Vector3.ZERO)),
			"motion_margin_m": _m67h_vec3_to_array(volume.get("motion_margin", Vector3.ZERO)),
			"floor_included": true
		},
		"subject_asset": "SplatVizRobot.glb",
		"validation_note": "Msplat is a local Msplat run. Production conclusions still require gsplat validation.",
		"cameras": entries
	}
	var f = FileAccess.open(dataset_root + "/splatviz_msplat_manifest.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(manifest, "  "))
		f.close()

func _colmap_pose(c: Dictionary) -> Array:
	var axes = _m66d_capture_axes(c)
	var pos = axes["position"] as Vector3
	var z = axes["forward"] as Vector3
	var x = axes["right"] as Vector3
	var y = -(axes["up"] as Vector3)
	var r00 = x.x; var r01 = x.y; var r02 = x.z
	var r10 = y.x; var r11 = y.y; var r12 = y.z
	var r20 = z.x; var r21 = z.y; var r22 = z.z
	var q = _quat_from_rotation_rows(r00,r01,r02,r10,r11,r12,r20,r21,r22)
	var tx = -(r00 * pos.x + r01 * pos.y + r02 * pos.z)
	var ty = -(r10 * pos.x + r11 * pos.y + r12 * pos.z)
	var tz = -(r20 * pos.x + r21 * pos.y + r22 * pos.z)
	# COLMAP images.bin requires quaternion order QW, QX, QY, QZ.
	# Keep this as an explicit array so Vector4 component order cannot be misread.
	return [q[0], q[1], q[2], q[3], tx, ty, tz]

func _quat_from_rotation_rows(r00: float, r01: float, r02: float, r10: float, r11: float, r12: float, r20: float, r21: float, r22: float) -> Array:
	var tr = r00 + r11 + r22
	var qw = 1.0
	var qx = 0.0
	var qy = 0.0
	var qz = 0.0
	if tr > 0.0:
		var s = sqrt(tr + 1.0) * 2.0
		qw = 0.25 * s
		qx = (r21 - r12) / s
		qy = (r02 - r20) / s
		qz = (r10 - r01) / s
	elif r00 > r11 and r00 > r22:
		var s = sqrt(1.0 + r00 - r11 - r22) * 2.0
		qw = (r21 - r12) / s
		qx = 0.25 * s
		qy = (r01 + r10) / s
		qz = (r02 + r20) / s
	elif r11 > r22:
		var s = sqrt(1.0 + r11 - r00 - r22) * 2.0
		qw = (r02 - r20) / s
		qx = (r01 + r10) / s
		qy = 0.25 * s
		qz = (r12 + r21) / s
	else:
		var s = sqrt(1.0 + r22 - r00 - r11) * 2.0
		qw = (r10 - r01) / s
		qx = (r02 + r20) / s
		qy = (r12 + r21) / s
		qz = 0.25 * s
	var mag = sqrt(qw * qw + qx * qx + qy * qy + qz * qz)
	if mag > 0.000001:
		qw /= mag
		qx /= mag
		qy /= mag
		qz /= mag
	return [qw, qx, qy, qz]

func _shell_quote(path: String) -> String:
	return "'" + path.replace("'", "'\\''") + "'"


func _m65a_is_finite_float(v: float) -> bool:
	if v != v:
		return false
	if absf(v) > 100000000.0:
		return false
	return true

func _m65a_sigmoid(x: float) -> float:
	if x >= 0.0:
		var z := exp(-x)
		return 1.0 / (1.0 + z)
	var z2 := exp(x)
	return z2 / (1.0 + z2)

func _m65a_clamp01(v: float) -> float:
	return clamp(v, 0.0, 1.0)

func _m65a_sh_dc_to_color(vals: Dictionary) -> Color:
	if vals.has("f_dc_0") and vals.has("f_dc_1") and vals.has("f_dc_2"):
		var c0 := 0.2820947918
		var r := _m65a_clamp01(0.5 + c0 * float(vals.get("f_dc_0", 0.0)))
		var g := _m65a_clamp01(0.5 + c0 * float(vals.get("f_dc_1", 0.0)))
		var b := _m65a_clamp01(0.5 + c0 * float(vals.get("f_dc_2", 0.0)))
		return Color(r, g, b, 1.0)
	if vals.has("red") and vals.has("green") and vals.has("blue"):
		return Color(float(vals.get("red", 180.0)) / 255.0, float(vals.get("green", 180.0)) / 255.0, float(vals.get("blue", 180.0)) / 255.0, 1.0)
	return Color(0.78, 0.92, 1.0, 1.0)

func _m65a_percentile(values: Array, pct: float) -> float:
	var vals: Array = []
	for v in values:
		var f := float(v)
		if _m65a_is_finite_float(f):
			vals.append(f)
	if vals.is_empty():
		return 0.0
	vals.sort()
	var k := int(round(float(vals.size() - 1) * pct / 100.0))
	k = clamp(k, 0, vals.size() - 1)
	return float(vals[k])

func _m65a_robust_bbox(points: Array, lo_pct: float, hi_pct: float) -> Dictionary:
	var xs: Array = []
	var ys: Array = []
	var zs: Array = []
	for item in points:
		var p: Vector3 = item["p"] as Vector3
		xs.append(p.x)
		ys.append(p.y)
		zs.append(p.z)
	var min_p := Vector3(_m65a_percentile(xs, lo_pct), _m65a_percentile(ys, lo_pct), _m65a_percentile(zs, lo_pct))
	var max_p := Vector3(_m65a_percentile(xs, hi_pct), _m65a_percentile(ys, hi_pct), _m65a_percentile(zs, hi_pct))
	return {"min": min_p, "max": max_p, "span": max_p - min_p, "center": (min_p + max_p) * 0.5}

func _m65a_make_ply_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	return mat

func _m66e_is_finite(v: float) -> bool:
	return not is_nan(v) and not is_inf(v) and absf(v) < 100000000.0

func _m66e_sigmoid(x: float) -> float:
	if not _m66e_is_finite(x):
		return 0.0
	if x >= 0.0:
		var z: float = exp(-x)
		return 1.0 / (1.0 + z)
	var z2: float = exp(x)
	return z2 / (1.0 + z2)

func _m66e_clamp01(v: float) -> float:
	return clamp(v, 0.0, 1.0)

func _m66e_sh_dc_to_color(vals: Dictionary) -> Color:
	# 3DGS/msplat PLYs normally store SH DC, not red/green/blue.
	# Approximate color from DC term: rgb = clamp(0.5 + C0 * f_dc).
	if vals.has("f_dc_0") and vals.has("f_dc_1") and vals.has("f_dc_2"):
		var c0: float = 0.2820947918
		var r: float = _m66e_clamp01(0.5 + c0 * float(vals.get("f_dc_0", 0.0)))
		var g: float = _m66e_clamp01(0.5 + c0 * float(vals.get("f_dc_1", 0.0)))
		var b: float = _m66e_clamp01(0.5 + c0 * float(vals.get("f_dc_2", 0.0)))
		return Color(r, g, b, 1.0)
	if vals.has("red") and vals.has("green") and vals.has("blue"):
		return Color(float(vals.get("red", 180.0)) / 255.0, float(vals.get("green", 180.0)) / 255.0, float(vals.get("blue", 180.0)) / 255.0, 1.0)
	return Color(0.78, 0.92, 1.0, 1.0)

func _m66e_percentile(vals: Array, frac: float) -> float:
	var clean: Array = []
	for v_any in vals:
		var v: float = float(v_any)
		if _m66e_is_finite(v):
			clean.append(v)
	if clean.is_empty():
		return 0.0
	clean.sort()
	var idx: int = int(clamp(round(float(clean.size() - 1) * frac), 0.0, float(clean.size() - 1)))
	return float(clean[idx])

func _m66e_points_from_records(records: Array) -> Array:
	var pts: Array = []
	for r_any in records:
		var r: Dictionary = r_any as Dictionary
		pts.append(r.get("p"))
	return pts

func _m66e_bounds(points: Array, lo_frac: float, hi_frac: float) -> Dictionary:
	var xs: Array = []
	var ys: Array = []
	var zs: Array = []
	for p_any in points:
		var p: Vector3 = p_any as Vector3
		xs.append(p.x)
		ys.append(p.y)
		zs.append(p.z)
	var mn: Vector3 = Vector3(_m66e_percentile(xs, lo_frac), _m66e_percentile(ys, lo_frac), _m66e_percentile(zs, lo_frac))
	var mx: Vector3 = Vector3(_m66e_percentile(xs, hi_frac), _m66e_percentile(ys, hi_frac), _m66e_percentile(zs, hi_frac))
	return {"min": mn, "max": mx, "span": mx - mn, "center": (mn + mx) * 0.5}

func _m66e_gaussian_blob_texture() -> Texture2D:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var dx: float = (float(x) + 0.5) / 64.0 * 2.0 - 1.0
			var dy: float = (float(y) + 0.5) / 64.0 * 2.0 - 1.0
			var r2: float = dx * dx + dy * dy
			var a: float = clamp(exp(-r2 * 4.0), 0.0, 1.0)
			if r2 > 1.0:
				a = 0.0
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

func _m66e_make_gaussian_sprite_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.albedo_texture = _m66e_gaussian_blob_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	# Avoid enum parse fragility: 1 is BILLBOARD_ENABLED in Godot 4 BaseMaterial3D.
	mat.set("billboard_mode", 1)
	mat.set("billboard_keep_scale", true)
	return mat
func _m66e_ref_line_material(col: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _m66e_ref_line_instance(points: PackedVector3Array, col: Color, label: String) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	mi.material_override = _m66e_ref_line_material(col)
	return mi

func _m68a_ply_ascii_values(row: PackedStringArray, props: Array) -> Dictionary:
	var vals: Dictionary = {}
	var count: int = min(row.size(), props.size())
	for i in range(count):
		var prop: Dictionary = props[i] as Dictionary
		vals[str(prop.get("name", ""))] = row[i]
	return vals

func _m68a_vec3_bounds_text(v: Vector3) -> String:
	return "(" + _m67g_num(v.x, 3) + ", " + _m67g_num(v.y, 3) + ", " + _m67g_num(v.z, 3) + ")"

func _m66e_add_reference_floor_and_bbox(focus_min: Vector3, focus_max: Vector3, robust_min: Vector3, robust_max: Vector3) -> void:
	# Diagnostic preview reference helper. It does not modify PLY data.
	if splat_root == null:
		return
	var stale: Array = []
	for child in splat_root.get_children():
		if str(child.name).begins_with("M66E reference"):
			stale.append(child)
	for old_any in stale:
		var old_node: Node = old_any as Node
		old_node.queue_free()

	var root: Node3D = Node3D.new()
	root.name = "M66E reference floor and focus bbox"
	splat_root.add_child(root)

	var span: Vector3 = robust_max - robust_min
	var margin_x: float = max(0.35, span.x * 0.28)
	var margin_z: float = max(0.35, span.z * 0.28)
	var min_x: float = robust_min.x - margin_x
	var max_x: float = robust_max.x + margin_x
	var min_z: float = robust_min.z - margin_z
	var max_z: float = robust_max.z + margin_z
	var floor_y: float = focus_min.y - max(0.08, max(span.y * 0.08, 0.12))
	var step: float = max(0.25, max(span.x, span.z) / 12.0)
	var grid_pts: PackedVector3Array = PackedVector3Array()
	var x: float = min_x
	while x <= max_x + 0.001:
		grid_pts.append(Vector3(x, floor_y, min_z))
		grid_pts.append(Vector3(x, floor_y, max_z))
		x += step
	var z: float = min_z
	while z <= max_z + 0.001:
		grid_pts.append(Vector3(min_x, floor_y, z))
		grid_pts.append(Vector3(max_x, floor_y, z))
		z += step
	root.add_child(_m66e_ref_line_instance(grid_pts, Color(0.20, 0.85, 0.95, 0.45), "M66E reference floor grid"))
	if latest_ply_show_bounds:
		var a: Vector3 = focus_min
		var b: Vector3 = focus_max
		var c000: Vector3 = Vector3(a.x, a.y, a.z)
		var c100: Vector3 = Vector3(b.x, a.y, a.z)
		var c010: Vector3 = Vector3(a.x, b.y, a.z)
		var c110: Vector3 = Vector3(b.x, b.y, a.z)
		var c001: Vector3 = Vector3(a.x, a.y, b.z)
		var c101: Vector3 = Vector3(b.x, a.y, b.z)
		var c011: Vector3 = Vector3(a.x, b.y, b.z)
		var c111: Vector3 = Vector3(b.x, b.y, b.z)
		var focus_box_pts: PackedVector3Array = PackedVector3Array([
			c000, c100, c100, c110, c110, c010, c010, c000,
			c001, c101, c101, c111, c111, c011, c011, c001,
			c000, c001, c100, c101, c110, c111, c010, c011
		])
		root.add_child(_m66e_ref_line_instance(focus_box_pts, Color(0.38, 0.95, 1.0, 0.78), "M68A2 focus bbox"))
		if not latest_ply_bounds_full.is_empty():
			var full_min: Vector3 = latest_ply_bounds_full.get("min", focus_min)
			var full_max: Vector3 = latest_ply_bounds_full.get("max", focus_max)
			var full_box: PackedVector3Array = _box_lines((full_min + full_max) * 0.5, full_max - full_min)
			root.add_child(_m66e_ref_line_instance(full_box, Color(1.0, 0.72, 0.18, 0.86), "M68A2 full PLY bounds"))
	if latest_ply_show_capture_bounds:
		var subject := _m67h_capture_subject_bounds()
		var subject_center: Vector3 = subject.get("center", TARGET)
		var subject_size: Vector3 = subject.get("size", Vector3.ZERO)
		if subject_size.length() > 0.001:
			var capture_box: PackedVector3Array = _box_lines(subject_center, subject_size)
			root.add_child(_m66e_ref_line_instance(capture_box, Color(0.27, 1.0, 0.46, 0.84), "M68A2 capture subject bounds"))

func _load_ply_point_cloud(path: String) -> int:
	# M66E: color/opacity-aware Gaussian sprite preview.
	# This is closer than center-point boxes: it decodes SH/DC color + opacity and renders
	# soft billboards. It is still a lightweight QC preview, not a full anisotropic 3DGS rasterizer.
	latest_ply_summary = ""
	latest_ply_valid_points = 0
	latest_ply_bounds_full = {}
	latest_ply_bounds_focus = {}
	latest_ply_preview_mode = "No PLY loaded"
	latest_ply_provenance_text = "No manifest found; provenance unknown."
	latest_ply_auto_fit_camera = false
	if splat_root == null:
		latest_ply_summary = "No splat_root available."
		return 0
	for child in splat_root.get_children():
		child.queue_free()

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		latest_ply_summary = "Could not open PLY."
		return 0

	var vertex_count: int = 0
	var format_line: String = "ascii"
	var props: Array = []
	var current_element: String = ""
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.begins_with("format "):
			format_line = line
		elif line.begins_with("element "):
			var parts: PackedStringArray = line.split(" ", false)
			if parts.size() >= 2:
				current_element = String(parts[1])
			if current_element == "vertex" and parts.size() >= 3:
				vertex_count = int(parts[2])
		elif current_element == "vertex" and line.begins_with("property "):
			var pparts: PackedStringArray = line.split(" ", false)
			if pparts.size() >= 3 and pparts[1] != "list":
				props.append({"type": String(pparts[1]), "name": String(pparts[2])})
		elif line == "end_header":
			break
	if vertex_count <= 0:
		latest_ply_summary = "Debug point preview unavailable. PLY header did not declare a valid vertex count."
		f.close()
		return 0
	if format_line.find("ascii") < 0 and format_line.find("binary_little_endian") < 0:
		latest_ply_summary = "Debug point preview unavailable. Unsupported PLY format: " + format_line + ". Supported: ascii and binary_little_endian."
		f.close()
		return 0

	var max_points: int = 180000
	var stride: int = max(1, int(ceil(float(max(1, vertex_count)) / float(max_points))))
	var raw_records: Array = []
	var alpha_values: Array = []
	var invalid_count: int = 0
	var sampled_count: int = 0

	if format_line.find("binary_little_endian") >= 0:
		f.big_endian = false
		for i in range(vertex_count):
			var vals: Dictionary = _read_ply_vertex_binary(f, props)
			if i % stride != 0:
				continue
			sampled_count += 1
			var p: Vector3 = Vector3(float(vals.get("x", 0.0)), float(vals.get("y", 0.0)), float(vals.get("z", 0.0)))
			if not _is_valid_ply_point(p):
				invalid_count += 1
				continue
			var op: float = float(vals.get("opacity", 0.0)) if vals.has("opacity") else 4.0
			var alpha: float = _m66e_sigmoid(op)
			var col: Color = _m66e_sh_dc_to_color(vals)
			raw_records.append({"p": p, "alpha": alpha, "color": col})
			alpha_values.append(alpha)
	else:
		for i in range(vertex_count):
			if f.eof_reached():
				break
			var row: PackedStringArray = f.get_line().strip_edges().replace("\t", " ").split(" ", false)
			if i % stride != 0:
				continue
			sampled_count += 1
			if row.size() < 3:
				invalid_count += 1
				continue
			var vals_ascii: Dictionary = _m68a_ply_ascii_values(row, props)
			var p_ascii: Vector3 = Vector3(float(vals_ascii.get("x", row[0])), float(vals_ascii.get("y", row[1])), float(vals_ascii.get("z", row[2])))
			if not _is_valid_ply_point(p_ascii):
				invalid_count += 1
				continue
			var col_ascii: Color = _m66e_sh_dc_to_color(vals_ascii)
			var alpha_ascii: float = 1.0
			if vals_ascii.has("opacity"):
				alpha_ascii = _m66e_sigmoid(float(vals_ascii.get("opacity", 0.0)))
			raw_records.append({"p": p_ascii, "alpha": alpha_ascii, "color": col_ascii})
			alpha_values.append(alpha_ascii)
	f.close()

	if raw_records.is_empty():
		latest_ply_summary = "Debug point preview unavailable. Every sampled vertex was invalid or NaN. Vertex/Gaussian count: " + str(vertex_count)
		return 0

	var alpha_p50: float = _m66e_percentile(alpha_values, 0.50)
	var alpha_p75: float = _m66e_percentile(alpha_values, 0.75)
	var selected_records: Array = []
	for r_any in raw_records:
		var r: Dictionary = r_any as Dictionary
		if float(r.get("alpha", 1.0)) >= alpha_p50:
			selected_records.append(r)
	if selected_records.size() < 800:
		selected_records = raw_records
		alpha_p50 = 0.0

	var selected_points: Array = _m66e_points_from_records(selected_records)
	var focus: Dictionary = _m66e_bounds(selected_points, 0.05, 0.95)
	var robust: Dictionary = _m66e_bounds(selected_points, 0.01, 0.99)
	var full: Dictionary = _m66e_bounds(_m66e_points_from_records(raw_records), 0.0, 1.0)
	var focus_min: Vector3 = focus["min"] as Vector3
	var focus_max: Vector3 = focus["max"] as Vector3
	var robust_min: Vector3 = robust["min"] as Vector3
	var robust_max: Vector3 = robust["max"] as Vector3
	var full_span: Vector3 = full["span"] as Vector3
	var robust_span: Vector3 = robust["span"] as Vector3
	var focus_span: Vector3 = focus["span"] as Vector3
	var visible_records: Array = selected_records

	var focus_center: Vector3 = (focus_min + focus_max) * 0.5
	var focus_diag: float = max(0.001, focus_span.length())
	var sprite_size: float = clamp(focus_diag / sqrt(float(max(1, visible_records.size()))) * 0.38, 0.0045, 0.045)

	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(sprite_size, sprite_size)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = visible_records.size()
	var out_i: int = 0
	for vr_any in visible_records:
		var vr: Dictionary = vr_any as Dictionary
		var q: Vector3 = vr["p"] as Vector3
		var c: Color = vr["color"] as Color
		var a: float = clamp(float(vr.get("alpha", 1.0)) * 1.15, 0.18, 1.0)
		mm.set_instance_transform(out_i, Transform3D(Basis(), q))
		mm.set_instance_color(out_i, Color(c.r, c.g, c.b, a))
		out_i += 1
	mm.visible_instance_count = out_i

	var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
	inst.name = "M66E SH/DC color Gaussian sprite preview"
	inst.multimesh = mm
	inst.material_override = _m66e_make_gaussian_sprite_material()
	splat_root.add_child(inst)

	_m66e_add_reference_floor_and_bbox(focus_min, focus_max, robust_min, robust_max)

	pivot = focus_center
	distance = max(1.15, focus_diag * 1.55)
	yaw = deg_to_rad(-32.0)
	pitch = deg_to_rad(-10.0)
	latest_ply_bounds_full = full
	latest_ply_bounds_focus = focus
	latest_ply_preview_mode = "Original Coordinates"
	latest_ply_auto_fit_camera = true
	var provenance := _m68a_manifest_info_for_path(path)
	latest_ply_provenance_text = str(provenance.get("summary", "No manifest found; provenance unknown."))
	var provenance_warning := str(provenance.get("warning", ""))
	if provenance_warning != "":
		latest_ply_provenance_text += "\n" + provenance_warning
	_update_orbit_camera()

	latest_ply_valid_points = out_i
	var invalid_est: int = int(round(float(invalid_count) * float(stride)))
	latest_ply_summary = "Debug point preview — not final anisotropic 3DGS rasterization. Status: loaded."
	latest_ply_summary += " Vertex/Gaussian count: " + str(vertex_count)
	latest_ply_summary += " · sampled " + str(sampled_count)
	latest_ply_summary += " · finite xyz " + str(raw_records.size())
	latest_ply_summary += " · shown " + str(out_i)
	latest_ply_summary += " · invalid/NaN skipped≈" + str(invalid_est)
	latest_ply_summary += " · bounds min " + _m68a_vec3_bounds_text(full.get("min", Vector3.ZERO))
	latest_ply_summary += " max " + _m68a_vec3_bounds_text(full.get("max", Vector3.ZERO))
	latest_ply_summary += " · focus 5-95 " + _vec3_short(focus_span)
	latest_ply_summary += " · sprite " + _m67g_num(sprite_size, 4) + "m"
	latest_ply_summary += " · format " + ("binary_little_endian" if format_line.find("binary_little_endian") >= 0 else "ascii")
	latest_ply_summary += " · preview mode " + latest_ply_preview_mode
	return out_i

func _is_valid_ply_point(p: Vector3) -> bool:
	if p.x != p.x or p.y != p.y or p.z != p.z:
		return false
	if absf(p.x) > 100000.0 or absf(p.y) > 100000.0 or absf(p.z) > 100000.0:
		return false
	return true

func _vec3_short(v: Vector3) -> String:
	return "%.3f×%.3f×%.3fm" % [v.x, v.y, v.z]

func _read_ply_vertex_binary(f: FileAccess, props: Array) -> Dictionary:
	var vals: Dictionary = {}
	for p in props:
		var t := str(p["type"])
		var n := str(p["name"])
		var v := 0.0
		if t == "float" or t == "float32":
			v = f.get_float()
		elif t == "double" or t == "float64":
			v = f.get_double()
		elif t == "uchar" or t == "uint8":
			v = float(f.get_8())
		elif t == "char" or t == "int8":
			v = float(f.get_8())
		elif t == "ushort" or t == "uint16":
			v = float(f.get_16())
		elif t == "short" or t == "int16":
			v = float(f.get_16())
		elif t == "uint" or t == "uint32" or t == "int" or t == "int32":
			v = float(f.get_32())
		else:
			v = f.get_float()
		vals[n] = v
	return vals


func _meters_feet(m: float) -> String:
	var ft = m / FT_TO_M
	return "%.2fm / %.1fft" % [m, ft]

func _add_box(pos: Vector3, size: Vector3, material: Material, parent: Node, name: String) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.name = name
	parent.add_child(mi)
	return mi

func _add_sphere(pos: Vector3, radius: float, material: Material, parent: Node, name: String) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	mi.name = name
	parent.add_child(mi)
	return mi

func _add_cylinder(pos: Vector3, radius: float, height: float, material: Material, parent: Node, name: String) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	mi.name = name
	parent.add_child(mi)
	return mi

func _line_mesh(points: PackedVector3Array) -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh

func _box_lines(center: Vector3, size: Vector3) -> PackedVector3Array:
	var hx = size.x / 2.0
	var hy = size.y / 2.0
	var hz = size.z / 2.0
	var p = [
		center + Vector3(-hx,-hy,-hz), center + Vector3(hx,-hy,-hz),
		center + Vector3(hx,-hy,hz), center + Vector3(-hx,-hy,hz),
		center + Vector3(-hx,hy,-hz), center + Vector3(hx,hy,-hz),
		center + Vector3(hx,hy,hz), center + Vector3(-hx,hy,hz)
	]
	return PackedVector3Array([
		p[0],p[1], p[1],p[2], p[2],p[3], p[3],p[0],
		p[4],p[5], p[5],p[6], p[6],p[7], p[7],p[4],
		p[0],p[4], p[1],p[5], p[2],p[6], p[3],p[7]
	])

func _add_label3d(text: String, pos: Vector3, color: Color) -> void:
	var l = Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 36
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	overlay_root.add_child(l)


# -----------------------------------------------------------------------------
# M66A Still Viewer — passive disk browser for clean renders / overlays / masks.
# -----------------------------------------------------------------------------
func _build_stills_panel(root: Control, screen_size: Vector2) -> void:
	stills_window = Window.new()
	stills_window.title = "SplatViz Still Viewer"
	stills_window.size = Vector2i(1420, 900)
	stills_window.min_size = Vector2i(1100, 720)
	stills_window.visible = false
	stills_window.close_requested.connect(func(): stills_window.visible = false)
	add_child(stills_window)

	stills_panel_root = Control.new()
	stills_panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stills_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	stills_window.add_child(stills_panel_root)

	var bg: PanelContainer = PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.add_theme_stylebox_override("panel", _panel_style(Color(0.010, 0.026, 0.028, 1.0)))
	stills_panel_root.add_child(bg)

	var title: Label = Label.new()
	title.text = "Still Viewer — Analysis"
	title.position = Vector2(24, 18)
	title.size = Vector2(260, 38)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.68, 1.0, 0.82))
	stills_panel_root.add_child(title)

	# M66C still viewer close button: quick return to main SplatViz UI.
	var stills_close_button: Button = Button.new()
	stills_close_button.text = "×"
	stills_close_button.position = Vector2(1356, 18)
	stills_close_button.size = Vector2(42, 34)
	stills_close_button.add_theme_font_size_override("font_size", 20)
	stills_close_button.focus_mode = Control.FOCUS_NONE
	stills_close_button.pressed.connect(func(): stills_window.visible = false)
	stills_panel_root.add_child(stills_close_button)

	var desc: Label = Label.new()
	desc.text = "Browse stills with fixed capture/framing analysis. Metadata is read from disk when available."
	desc.position = Vector2(24, 58)
	desc.size = Vector2(980, 28)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.78, 0.94, 0.86))
	stills_panel_root.add_child(desc)

	_add_abs_button(stills_panel_root, "Browse Folder…", Vector2(24, 96), Vector2(170, 38), func(): _browse_stills_folder())
	_add_abs_button(stills_panel_root, "‹ Prev", Vector2(204, 96), Vector2(120, 38), func(): _stills_prev())
	_add_abs_button(stills_panel_root, "Next ›", Vector2(334, 96), Vector2(120, 38), func(): _stills_next())
	_add_abs_button(stills_panel_root, "Open PNG in Finder", Vector2(464, 96), Vector2(170, 38), func(): _stills_open_current_in_finder())
	var stills_view_mode_label: Label = Label.new()
	stills_view_mode_label.text = ""
	stills_view_mode_label.position = Vector2(464, 103)
	stills_view_mode_label.size = Vector2(1, 1)
	stills_view_mode_label.add_theme_font_size_override("font_size", 13)
	stills_view_mode_label.add_theme_color_override("font_color", Color(0.70, 0.84, 0.78))
	stills_panel_root.add_child(stills_view_mode_label)

	stills_camera_option = OptionButton.new()
	stills_camera_option.position = Vector2(650, 96)
	stills_camera_option.size = Vector2(340, 38)
	stills_camera_option.add_theme_font_size_override("font_size", 14)
	stills_camera_option.item_selected.connect(func(idx: int): _stills_jump_to_camera_option(idx))
	stills_panel_root.add_child(stills_camera_option)

	stills_folder_label = Label.new()
	stills_folder_label.text = "Folder: not selected"
	stills_folder_label.position = Vector2(24, 140)
	stills_folder_label.size = Vector2(980, 26)
	stills_folder_label.add_theme_font_size_override("font_size", 13)
	stills_folder_label.add_theme_color_override("font_color", Color(0.70, 0.84, 0.78))
	stills_folder_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stills_panel_root.add_child(stills_folder_label)

	stills_title_label = Label.new()
	stills_title_label.text = "No still loaded"
	stills_title_label.position = Vector2(24, 170)
	stills_title_label.size = Vector2(1280, 34)
	stills_title_label.add_theme_font_size_override("font_size", 16)
	stills_title_label.add_theme_color_override("font_color", Color(0.92, 1.0, 0.92))
	stills_panel_root.add_child(stills_title_label)

	var image_frame: PanelContainer = PanelContainer.new()
	image_frame.position = Vector2(24, 218)
	image_frame.size = Vector2(1372, 368)
	image_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	image_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.0, 0.010, 0.012, 1.0)))
	stills_panel_root.add_child(image_frame)

	stills_image_rect = TextureRect.new()
	stills_image_rect.position = Vector2(10, 10)
	stills_image_rect.size = Vector2(1352, 348)
	stills_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stills_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# M66C no-crop still preview guarantee: preserve aspect ratio; letterbox instead of cropping.
	image_frame.add_child(stills_image_rect)

	var meta_panel: PanelContainer = PanelContainer.new()
	meta_panel.position = Vector2(24, 602)
	meta_panel.size = Vector2(1372, 250)
	meta_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	meta_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.040, 0.045, 0.96)))
	stills_panel_root.add_child(meta_panel)

	var meta_scroll: ScrollContainer = ScrollContainer.new()
	meta_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	meta_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	meta_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	meta_panel.add_child(meta_scroll)

	stills_meta_label = Label.new()
	stills_meta_label.custom_minimum_size = Vector2(1340, 0)
	stills_meta_label.add_theme_font_size_override("font_size", 16)
	stills_meta_label.add_theme_color_override("font_color", Color(0.92, 1.0, 0.92))
	stills_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stills_meta_label.text = "STILL ANALYSIS\n\nBrowse a folder of PNG/JPG stills. Core camera and crop values remain fixed in this panel."
	meta_scroll.add_child(stills_meta_label)

	stills_status_label = Label.new()
	stills_status_label.text = "Idle"
	stills_status_label.position = Vector2(24, 858)
	stills_status_label.size = Vector2(1350, 26)
	stills_status_label.add_theme_font_size_override("font_size", 13)
	stills_status_label.add_theme_color_override("font_color", Color(0.70, 0.84, 0.78))
	stills_panel_root.add_child(stills_status_label)

func _open_stills_window() -> void:
	if stills_window == null:
		return
	stills_window.visible = true
	stills_window.grab_focus()
	if stills_folder_path == "" and export_root_path != "":
		var latest_images: String = _stills_find_latest_images_folder(export_root_path)
		if latest_images != "":
			_stills_set_folder(latest_images)

func _stills_open_current_in_finder() -> void:
	if stills_images.is_empty():
		return
	var idx: int = clamp(stills_index, 0, stills_images.size() - 1)
	var p: String = stills_images[idx]
	if FileAccess.file_exists(p):
		OS.shell_open(p)
		_stills_set_status("Opened source PNG in Finder/Preview: " + p.get_file())
	else:
		_stills_set_status("Source PNG missing: " + p)

func _browse_stills_folder() -> void:
	if stills_folder_dialog == null:
		return
	if stills_folder_path != "":
		stills_folder_dialog.current_dir = stills_folder_path
	elif export_root_path != "":
		stills_folder_dialog.current_dir = export_root_path
	stills_folder_dialog.popup_centered_ratio(0.72)

func _stills_set_folder(dir_path: String) -> void:
	stills_folder_path = dir_path
	_stills_scan_images(dir_path)
	_stills_load_metadata_for_folder(dir_path)
	var provenance := _m68a_manifest_info_for_path(dir_path)
	stills_provenance_text = str(provenance.get("summary", "No manifest found; provenance unknown."))
	var provenance_warning := str(provenance.get("warning", ""))
	if provenance_warning != "":
		stills_provenance_text += "\n" + provenance_warning
	stills_index = 0
	_stills_populate_camera_option()
	_stills_show_current()

func _stills_find_latest_images_folder(root_path: String) -> String:
	var best_path := ""
	var best_time := -1
	var direct_candidates := [
		root_path.path_join("images"),
		root_path.path_join("camera_contact_renders"),
		root_path.path_join("camera_qc_diagnostics"),
		root_path.path_join("renders")
	]
	for candidate_any in direct_candidates:
		var candidate := str(candidate_any)
		if DirAccess.dir_exists_absolute(candidate):
			var mt_direct := int(FileAccess.get_modified_time(candidate))
			if mt_direct > best_time:
				best_time = mt_direct
				best_path = candidate
	var da: DirAccess = DirAccess.open(root_path)
	if da == null:
		return ""
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		if da.current_is_dir() and not name.begins_with("."):
			var candidate: String = root_path.path_join(name).path_join("images")
			if DirAccess.dir_exists_absolute(candidate):
				var mt := int(FileAccess.get_modified_time(candidate))
				if mt > best_time:
					best_time = mt
					best_path = candidate
		name = da.get_next()
	da.list_dir_end()
	return best_path

func _stills_candidate_search_roots(dir_path: String) -> Array[String]:
	var roots: Array[String] = []
	roots.append(dir_path)
	for child in ["images", "camera_contact_renders", "camera_qc_diagnostics", "renders"]:
		var candidate := dir_path.path_join(child)
		if DirAccess.dir_exists_absolute(candidate):
			roots.append(candidate)
	return roots

func _stills_collect_images_recursive(dir_path: String, out: Array[String], seen: Dictionary, depth: int = 0) -> void:
	if depth > 8:
		return
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	while true:
		var name := da.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var full_path := dir_path.path_join(name)
		if da.current_is_dir():
			_stills_collect_images_recursive(full_path, out, seen, depth + 1)
			continue
		var lower := name.to_lower()
		if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
			if not seen.has(full_path):
				seen[full_path] = true
				out.append(full_path)
	da.list_dir_end()

func _stills_scan_images(dir_path: String) -> void:
	stills_images.clear()
	stills_discovery_root = dir_path
	if DirAccess.open(dir_path) == null:
		_stills_set_status("Folder not readable: " + dir_path)
		return
	var seen: Dictionary = {}
	for root_any in _stills_candidate_search_roots(dir_path):
		_stills_collect_images_recursive(str(root_any), stills_images, seen)
	stills_images.sort_custom(func(a: String, b: String) -> bool:
		return _stills_sort_key(a) < _stills_sort_key(b)
	)
	_stills_set_status("Loaded " + str(stills_images.size()) + " stills from " + dir_path)

func _stills_sort_key(path: String) -> String:
	var cam_id: String = _stills_camera_id_from_text(path)
	var rel_path := path.trim_prefix(stills_folder_path).trim_prefix("/")
	if cam_id != "":
		return cam_id + "_" + _m68a_natural_sort_key(rel_path)
	return "ZZZ_" + _m68a_natural_sort_key(rel_path)

func _stills_populate_camera_option() -> void:
	if stills_camera_option == null:
		return
	stills_camera_option.clear()
	for i in range(stills_images.size()):
		var path: String = stills_images[i]
		var cam_id: String = _stills_camera_id_from_text(path)
		var rel_path := path.trim_prefix(stills_folder_path).trim_prefix("/")
		var label := ""
		if cam_id != "":
			label = cam_id + " · " + rel_path
		else:
			label = str(i + 1) + " · " + rel_path
		stills_camera_option.add_item(label)
	if stills_images.size() > 0:
		stills_camera_option.selected = clamp(stills_index, 0, stills_images.size() - 1)

func _stills_jump_to_camera_option(idx: int) -> void:
	if idx < 0 or idx >= stills_images.size():
		return
	stills_index = idx
	_stills_show_current()

func _stills_prev() -> void:
	if stills_images.is_empty():
		return
	stills_index = (stills_index - 1 + stills_images.size()) % stills_images.size()
	_stills_show_current()

func _stills_next() -> void:
	if stills_images.is_empty():
		return
	stills_index = (stills_index + 1) % stills_images.size()
	_stills_show_current()

func _stills_toggle_zoom() -> void:
	# M66A2: Fit/1:1 toggle removed. Always show centered full-frame stills.
	stills_zoom_1to1 = false
	if stills_image_rect != null:
		stills_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stills_show_current()

func _stills_show_current() -> void:
	if stills_images.is_empty():
		if stills_image_rect != null:
			stills_image_rect.texture = null
		if stills_title_label != null:
			stills_title_label.text = "No stills in folder"
		if stills_meta_label != null:
			stills_meta_label.text = "STILL VIEWER\n\nNo PNG/JPG images found."
		return
	stills_index = clamp(stills_index, 0, stills_images.size() - 1)
	var path: String = stills_images[stills_index]
	var img: Image = Image.new()
	var err: int = img.load(path)
	if err != OK:
		_stills_set_status("Failed to load image: " + path)
		return
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	stills_image_rect.texture = tex
	var cam_id: String = _stills_camera_id_from_text(path)
	if stills_title_label != null:
		stills_title_label.text = str(stills_index + 1) + "/" + str(stills_images.size()) + " · " + (cam_id if cam_id != "" else "Still") + " · " + path.get_file()
	if stills_folder_label != null:
		var warning := _m68a_release_warning_for_path(path)
		stills_folder_label.text = "Folder: " + _m68a_trimmed_path(stills_folder_path, 112) + "\nStill: " + _m68a_trimmed_path(path, 112)
		if stills_provenance_text != "":
			stills_folder_label.text += "\n" + stills_provenance_text
		if warning != "" and stills_folder_label.text.find(warning) < 0:
			stills_folder_label.text += "\n" + warning
	if stills_camera_option != null and stills_camera_option.item_count == stills_images.size():
		stills_camera_option.selected = stills_index
	if stills_meta_label != null:
		stills_meta_label.text = _stills_metadata_text(path, img)

func _stills_set_status(msg: String) -> void:
	if stills_status_label != null:
		stills_status_label.text = msg

func _stills_load_metadata_for_folder(dir_path: String) -> void:
	stills_metadata = {"by_cam": {}, "by_image": {}, "sources": []}
	var candidates: Array[String] = []
	candidates.append(dir_path.path_join("metadata.json"))
	candidates.append(dir_path.path_join("transforms.json"))
	candidates.append(dir_path.get_base_dir().path_join("metadata.json"))
	candidates.append(dir_path.get_base_dir().path_join("transforms.json"))
	for root_any in _stills_candidate_search_roots(dir_path):
		var root := str(root_any)
		candidates.append(root.path_join("metadata.json"))
		candidates.append(root.path_join("transforms.json"))
		candidates.append(root.get_base_dir().path_join("metadata.json"))
		candidates.append(root.get_base_dir().path_join("transforms.json"))

	var da: DirAccess = DirAccess.open(dir_path)
	if da != null:
		da.list_dir_begin()
		var name: String = da.get_next()
		while name != "":
			if not da.current_is_dir():
				var lower: String = name.to_lower()
				if lower.begins_with("splatviz_still_metadata") and lower.ends_with(".json"):
					candidates.append(dir_path.path_join(name))
			name = da.get_next()
		da.list_dir_end()

	for c in candidates:
		if FileAccess.file_exists(c):
			_stills_ingest_metadata_json(c)

func _stills_ingest_metadata_json(path: String) -> void:
	var txt: String = FileAccess.get_file_as_string(path)
	if txt == "":
		return
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed as Dictionary
	var sources: Array = stills_metadata["sources"] as Array
	sources.append(path.get_file())
	stills_metadata["sources"] = sources

	if d.has("cameras"):
		var cams_v: Variant = d["cameras"]
		if typeof(cams_v) == TYPE_ARRAY:
			var cams: Array = cams_v as Array
			for cam_v in cams:
				if typeof(cam_v) == TYPE_DICTIONARY:
					var cam: Dictionary = cam_v as Dictionary
					_stills_register_camera_metadata(cam)

	if d.has("frames"):
		_stills_ingest_transforms_metadata(d, path.get_file())

func _stills_ingest_transforms_metadata(d: Dictionary, source_name: String) -> void:
	var frames_v: Variant = d.get("frames", [])
	if typeof(frames_v) != TYPE_ARRAY:
		return
	var frames: Array = frames_v as Array
	var top_w: int = int(d.get("w", 0))
	var top_h: int = int(d.get("h", 0))
	var top_fx_v: Variant = d.get("fl_x", d.get("fx", d.get("fl_–", d.get("f–", null))))
	var top_fy_v: Variant = d.get("fl_y", d.get("fy", null))
	for frame_v in frames:
		if typeof(frame_v) != TYPE_DICTIONARY:
			continue
		var frame: Dictionary = frame_v as Dictionary
		var file_path: String = str(frame.get("file_path", frame.get("image", frame.get("file", ""))))
		var cam_id: String = _stills_camera_id_from_text(file_path)
		var meta: Dictionary = {}
		meta["source_metadata"] = source_name
		meta["image_file"] = file_path.get_file()
		meta["id"] = cam_id
		meta["lens_name"] = STILL_VIEWER_LENS_NAME
		meta["width"] = int(frame.get("w", top_w))
		meta["height"] = int(frame.get("h", top_h))
		var fx_v: Variant = frame.get("fl_x", frame.get("fx", frame.get("fl_–", frame.get("f–", top_fx_v))))
		var fy_v: Variant = frame.get("fl_y", frame.get("fy", top_fy_v))
		if fx_v != null:
			meta["fx_px"] = float(fx_v)
		if fy_v != null:
			meta["fy_px"] = float(fy_v)
		_stills_add_transform_position(meta, frame)
		_stills_register_camera_metadata(meta)

func _stills_add_transform_position(meta: Dictionary, frame: Dictionary) -> void:
	var mat_v: Variant = frame.get("transform_matrix", frame.get("transform_matri–", null))
	if typeof(mat_v) != TYPE_ARRAY:
		return
	var mat: Array = mat_v as Array
	if mat.size() < 3:
		return
	var row0_v: Variant = mat[0]
	var row1_v: Variant = mat[1]
	var row2_v: Variant = mat[2]
	if typeof(row0_v) != TYPE_ARRAY or typeof(row1_v) != TYPE_ARRAY or typeof(row2_v) != TYPE_ARRAY:
		return
	var row0: Array = row0_v as Array
	var row1: Array = row1_v as Array
	var row2: Array = row2_v as Array
	if row0.size() < 4 or row1.size() < 4 or row2.size() < 4:
		return
	var pos := Vector3(float(row0[3]), float(row1[3]), float(row2[3]))
	_stills_fill_position_metrics(meta, pos)

func _stills_fill_position_metrics(meta: Dictionary, pos: Vector3) -> void:
	var target := TARGET
	var to_target: Vector3 = target - pos
	var floor_vec := Vector2(to_target.x, to_target.z)
	var floor_dist: float = floor_vec.length()
	var dist_3d: float = to_target.length()
	var azimuth: float = rad_to_deg(atan2(to_target.z, to_target.x))
	var elevation: float = rad_to_deg(atan2(to_target.y, floor_dist))
	meta["pos_m"] = {"x": pos.x, "y": pos.y, "z": pos.z}
	meta["pos_ft"] = {"x": _m_to_ft(pos.x), "y": _m_to_ft(pos.y), "z": _m_to_ft(pos.z)}
	meta["height_floor_m"] = pos.y
	meta["height_floor_ft"] = _m_to_ft(pos.y)
	meta["dist_3d_m"] = dist_3d
	meta["dist_3d_ft"] = _m_to_ft(dist_3d)
	meta["dist_floor_m"] = floor_dist
	meta["dist_floor_ft"] = _m_to_ft(floor_dist)
	meta["azimuth_deg"] = azimuth
	meta["tilt_pitch_deg"] = elevation

func _stills_register_camera_metadata(meta: Dictionary) -> void:
	var cam_id := ""
	if meta.has("id"):
		cam_id = _stills_camera_id_from_text(str(meta["id"]))
	if cam_id == "" and meta.has("name"):
		cam_id = _stills_camera_id_from_text(str(meta["name"]))
	if cam_id == "" and meta.has("image_file"):
		cam_id = _stills_camera_id_from_text(str(meta["image_file"]))
	if cam_id != "":
		var by_cam: Dictionary = stills_metadata["by_cam"] as Dictionary
		by_cam[cam_id] = meta
		stills_metadata["by_cam"] = by_cam
	var image_key := ""
	if meta.has("image_file"):
		image_key = str(meta["image_file"]).get_file()
	elif meta.has("clean_path"):
		image_key = str(meta["clean_path"]).get_file()
	if image_key != "":
		var by_image: Dictionary = stills_metadata["by_image"] as Dictionary
		by_image[image_key] = meta
		stills_metadata["by_image"] = by_image

func _stills_lookup_metadata(path: String) -> Dictionary:
	var by_image: Dictionary = stills_metadata.get("by_image", {}) as Dictionary
	var image_key: String = path.get_file()
	if by_image.has(image_key):
		return by_image[image_key] as Dictionary
	var cam_id: String = _stills_camera_id_from_text(image_key)
	var by_cam: Dictionary = stills_metadata.get("by_cam", {}) as Dictionary
	if cam_id != "" and by_cam.has(cam_id):
		return by_cam[cam_id] as Dictionary
	return {}

func _stills_metadata_text(path: String, img: Image) -> String:
	var meta: Dictionary = _stills_lookup_metadata(path)
	var cam_id: String = _stills_camera_id_from_text(path)
	if cam_id == "" and meta.has("id"):
		cam_id = str(meta["id"])
	if cam_id == "":
		cam_id = "N/A"

	var loaded_w: int = img.get_width()
	var loaded_h: int = img.get_height()
	var loaded_aspect: String = _stills_aspect_string(loaded_w, loaded_h)
	var cfg_w: int = int(meta.get("width", meta.get("w", 0)))
	var cfg_h: int = int(meta.get("height", meta.get("h", 0)))
	var cfg_res: String = "N/A"
	if cfg_w > 0 and cfg_h > 0:
		cfg_res = str(cfg_w) + "×" + str(cfg_h) + " / " + _stills_aspect_string(cfg_w, cfg_h)

	var lens_name: String = _stills_lens_name(meta)
	var fx_s: String = _fmt_meta_float(meta, ["fx_px", "fx", "fl_x", "fx_p–", "f–", "fl_–"], " px", 1)
	var fy_s: String = _fmt_meta_float(meta, ["fy_px", "fy_p–", "fy", "fl_y"], " px", 1)
	var hfov_s: String = _stills_fov_string(meta, loaded_w, "fx_px", "fl_x")
	var vfov_s: String = _stills_fov_string(meta, loaded_h, "fy_px", "fl_y")
	var height_s: String = _fmt_m_ft(meta, "height_floor_m", "height_floor_ft")
	var d3_s: String = _fmt_m_ft(meta, "dist_3d_m", "dist_3d_ft")
	var df_s: String = _fmt_m_ft(meta, "dist_floor_m", "dist_floor_ft")
	var az_s: String = _fmt_meta_float(meta, ["azimuth_deg", "azimuth", "bearing_deg"], "°", 1)
	var tilt_s: String = _fmt_meta_float(meta, ["tilt_pitch_deg", "pitch_deg", "tilt_deg"], "°", 1)
	var roll_s: String = _fmt_meta_float(meta, ["roll_deg", "roll"], "°", 1)
	var pos_s: String = _stills_position_compact(meta)
	var analysis: Dictionary = _stills_frame_analysis(img)

	var sources_s: String = "N/A"
	if stills_metadata.has("sources"):
		var sources: Array = stills_metadata["sources"] as Array
		if sources.size() > 0:
			sources_s = ", ".join(PackedStringArray(sources))

	var bbox_s: String = str(analysis.get("bbox", analysis.get("bbo–", "N/A")))
	var coverage_s: String = str(analysis.get("coverage", "N/A"))
	var offset_s: String = str(analysis.get("offset", "N/A"))
	var margins_s: String = str(analysis.get("margins", "N/A"))
	var crop_s: String = str(analysis.get("status", "UNKNOWN"))

	var text: String = "PROVENANCE\n"
	text += stills_provenance_text + "\n"
	var warning := _m68a_release_warning_for_path(path)
	if warning != "" and text.find(warning) < 0:
		text += warning + "\n"
	text += "Path: " + _m68a_trimmed_path(path, 120) + "\n\n"
	text += "CAMERA / CAPTURE CONFIG\n"
	text += cam_id + "    Lens: " + lens_name + "    Roll: " + roll_s + "\n"
	text += "Configured render: " + cfg_res + "    Loaded PNG: " + str(loaded_w) + "×" + str(loaded_h) + " / " + loaded_aspect + "\n"
	text += "fx/fy: " + fx_s + " / " + fy_s + "    HFOV/VFOV: " + hfov_s + " / " + vfov_s + "\n"
	text += "Height: " + height_s + "    Dist 3D: " + d3_s + "    Floor dist: " + df_s + "\n"
	text += "Azimuth: " + az_s + "    Tilt/Pitch: " + tilt_s + "    Position: " + pos_s + "\n"
	text += "\nIMAGE / FRAMING ANALYSIS\n"
	text += "Subject/foreground bbox: " + bbox_s + "    Coverage: " + coverage_s + "    Center offset: " + offset_s + "\n"
	text += "Margins: " + margins_s + "    Crop status: " + crop_s + "\n"
	text += "File: " + path.get_file() + "    Index: " + str(stills_index + 1) + " / " + str(stills_images.size()) + "    Metadata: " + sources_s
	if meta.is_empty():
		text += "    Camera metadata: N/A"
	return text

func _stills_frame_analysis(img: Image) -> Dictionary:
	# M66C analysis only: estimates source-image foreground bbox, likely body bbox,
	# floor/platform edge contact, and source-crop risk. It never modifies the still.
	var w: int = img.get_width()
	var h: int = img.get_height()
	var result: Dictionary = {
		"bbox": "N/A",
		"coverage": "N/A",
		"offset": "N/A",
		"margins": "N/A",
		"status": "UNKNOWN"
	}
	if w <= 0 or h <= 0:
		return result

	var fg_min_x: int = w
	var fg_min_y: int = h
	var fg_max_x: int = -1
	var fg_max_y: int = -1
	var body_min_x: int = w
	var body_min_y: int = h
	var body_max_x: int = -1
	var body_max_y: int = -1
	var floor_edge_hits: int = 0
	var body_edge_hits: int = 0
	var edge_margin: int = 18
	var step_x: int = max(1, int(w / 640))
	var step_y: int = max(1, int(h / 360))

	for y in range(0, h, step_y):
		for x in range(0, w, step_x):
			var c: Color = img.get_pixel(x, y)
			var bg: bool = c.r < 0.04 and c.g < 0.12 and c.b < 0.14
			if bg:
				continue
			fg_min_x = min(fg_min_x, x)
			fg_min_y = min(fg_min_y, y)
			fg_max_x = max(fg_max_x, x)
			fg_max_y = max(fg_max_y, y)

			# Floor/platform in current synthetic stills is near-white and usually in the lower half.
			# Excluding this class prevents a floor-plane edge from being reported as a cropped robot body.
			var maxc: float = max(c.r, max(c.g, c.b))
			var minc: float = min(c.r, min(c.g, c.b))
			var near_white_floor: bool = y > int(float(h) * 0.50) and c.r > 0.72 and c.g > 0.72 and c.b > 0.68 and (maxc - minc) < 0.20
			var body_like: bool = not near_white_floor
			var near_edge: bool = x <= edge_margin or x >= w - edge_margin or y <= edge_margin or y >= h - edge_margin
			if near_white_floor and near_edge:
				floor_edge_hits += 1
			if body_like:
				body_min_x = min(body_min_x, x)
				body_min_y = min(body_min_y, y)
				body_max_x = max(body_max_x, x)
				body_max_y = max(body_max_y, y)
				if near_edge:
					body_edge_hits += 1

	if fg_max_x < 0:
		result["status"] = "UNKNOWN — no foreground detected"
		return result

	var bbox_w: int = max(1, fg_max_x - fg_min_x + step_x)
	var bbox_h: int = max(1, fg_max_y - fg_min_y + step_y)
	var coverage: float = 100.0 * float(bbox_w * bbox_h) / max(1.0, float(w * h))
	var center_x: float = (float(fg_min_x) + float(fg_max_x)) * 0.5
	var center_y: float = (float(fg_min_y) + float(fg_max_y)) * 0.5
	var offset_x: int = int(round(center_x - float(w) * 0.5))
	var offset_y: int = int(round(center_y - float(h) * 0.5))
	var margin_l: int = fg_min_x
	var margin_r: int = max(0, w - fg_max_x)
	var margin_t: int = fg_min_y
	var margin_b: int = max(0, h - fg_max_y)

	var fg_touches: Array[String] = []
	if margin_l <= edge_margin:
		fg_touches.append("LEFT")
	if margin_r <= edge_margin:
		fg_touches.append("RIGHT")
	if margin_t <= edge_margin:
		fg_touches.append("TOP")
	if margin_b <= edge_margin:
		fg_touches.append("BOTTOM")

	var body_touches: Array[String] = []
	if body_max_x >= 0:
		if body_min_x <= edge_margin:
			body_touches.append("LEFT")
		if w - body_max_x <= edge_margin:
			body_touches.append("RIGHT")
		if body_min_y <= edge_margin:
			body_touches.append("TOP")
		if h - body_max_y <= edge_margin:
			body_touches.append("BOTTOM")

	result["bbox"] = "x=%d y=%d w=%d h=%d px" % [fg_min_x, fg_min_y, bbox_w, bbox_h]
	result["coverage"] = str(snappedf(coverage, 0.1)) + "% of loaded frame"
	result["offset"] = "x=%+d px, y=%+d px" % [offset_x, offset_y]
	result["margins"] = "L=%d R=%d T=%d B=%d px" % [margin_l, margin_r, margin_t, margin_b]

	var preview_s: String = "Preview: no-crop aspect fit"
	if body_touches.size() > 0:
		result["status"] = "FAIL — subject/body likely touches " + ",".join(PackedStringArray(body_touches)) + " source edge(s). Open PNG in Finder to confirm camera/render crop. " + preview_s
	elif fg_touches.size() > 0 and floor_edge_hits > 0:
		result["status"] = "WARN — floor/platform touches " + ",".join(PackedStringArray(fg_touches)) + " source edge(s); body appears clear. " + preview_s
	elif fg_touches.size() > 0:
		result["status"] = "WARN — foreground touches " + ",".join(PackedStringArray(fg_touches)) + " source edge(s). " + preview_s
	else:
		result["status"] = "PASS — source foreground clear of edges. " + preview_s
	return result

func _stills_position_compact(meta: Dictionary) -> String:
	if not meta.has("pos_m"):
		return "N/A"
	var pos_v: Variant = meta["pos_m"]
	if typeof(pos_v) != TYPE_DICTIONARY:
		return "N/A"
	var pos: Dictionary = pos_v as Dictionary
	var x: float = float(pos.get("x", pos.get("–", 0.0)))
	var y: float = float(pos.get("y", 0.0))
	var z: float = float(pos.get("z", 0.0))
	return "X=" + str(snappedf(x, 0.001)) + "m/" + str(snappedf(_m_to_ft(x), 0.01)) + "ft " + \
		"Y=" + str(snappedf(y, 0.001)) + "m/" + str(snappedf(_m_to_ft(y), 0.01)) + "ft " + \
		"Z=" + str(snappedf(z, 0.001)) + "m/" + str(snappedf(_m_to_ft(z), 0.01)) + "ft"

func _stills_foreground_edge_warning(img: Image) -> String:
	# Synthetic render heuristic: foreground is anything not matching the dark teal background.
	# If foreground touches image borders, it may be a real camera crop, not a Still Viewer crop.
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 0 or h <= 0:
		return "N/A"
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	var step_x: int = max(1, int(w / 320))
	var step_y: int = max(1, int(h / 180))
	for y in range(0, h, step_y):
		for x in range(0, w, step_x):
			var c: Color = img.get_pixel(x, y)
			var bg: bool = c.r < 0.04 and c.g < 0.12 and c.b < 0.14
			if not bg:
				min_x = min(min_x, x)
				min_y = min(min_y, y)
				max_x = max(max_x, x)
				max_y = max(max_y, y)
	if max_x < 0:
		return "No foreground detected"
	var margin: int = 12
	var touches: Array[String] = []
	if min_x <= margin:
		touches.append("left")
	if max_x >= w - margin:
		touches.append("right")
	if min_y <= margin:
		touches.append("top")
	if max_y >= h - margin:
		touches.append("bottom")
	var bbox_s: String = "fg bbox x=%d..%d y=%d..%d" % [min_x, max_x, min_y, max_y]
	if touches.size() > 0:
		return "WARN touches " + ",".join(PackedStringArray(touches)) + " — likely camera/render crop if also visible in Finder. " + bbox_s
	return "OK centered foreground. " + bbox_s

func _stills_lens_name(meta: Dictionary) -> String:
	if meta.has("lens_name"):
		return str(meta["lens_name"])
	if meta.has("lens"):
		var lens_v: Variant = meta["lens"]
		if typeof(lens_v) == TYPE_DICTIONARY:
			var lens: Dictionary = lens_v as Dictionary
			if lens.has("name"):
				return str(lens["name"])
		elif typeof(lens_v) == TYPE_STRING:
			return str(lens_v)
	return STILL_VIEWER_LENS_NAME

func _stills_fov_string(meta: Dictionary, pixels: int, key_a: String, key_b: String) -> String:
	var f_v: Variant = null
	if meta.has(key_a):
		f_v = meta[key_a]
	elif meta.has(key_b):
		f_v = meta[key_b]
	elif key_a == "fx_px" and meta.has("fx"):
		f_v = meta["fx"]
	elif key_a == "fx_px" and meta.has("f–"):
		f_v = meta["f–"]
	elif key_a == "fy_px" and meta.has("fy"):
		f_v = meta["fy"]
	if f_v == null:
		return "N/A"
	var f: float = float(f_v)
	if f <= 0.001:
		return "N/A"
	var fov: float = rad_to_deg(2.0 * atan(float(pixels) / (2.0 * f)))
	return str(snappedf(fov, 0.1)) + "°"

func _fmt_meta_float(meta: Dictionary, keys: Array[String], suffix: String, decimals: int) -> String:
	for key in keys:
		if meta.has(key):
			var v: float = float(meta[key])
			var step: float = pow(10.0, -decimals)
			return str(snappedf(v, step)) + suffix
	return "N/A"

func _fmt_m_ft(meta: Dictionary, m_key: String, ft_key: String) -> String:
	var m_val: float = NAN
	var ft_val: float = NAN
	if meta.has(m_key):
		m_val = float(meta[m_key])
	if meta.has(ft_key):
		ft_val = float(meta[ft_key])
	elif is_finite(m_val):
		ft_val = _m_to_ft(m_val)
	if not is_finite(m_val) and not is_finite(ft_val):
		return "N/A"
	if not is_finite(m_val):
		m_val = ft_val / 3.280839895
	if not is_finite(ft_val):
		ft_val = _m_to_ft(m_val)
	return str(snappedf(m_val, 0.001)) + " m / " + str(snappedf(ft_val, 0.01)) + " ft"

func _stills_position_string(meta: Dictionary) -> String:
	if not meta.has("pos_m"):
		return "N/A"
	var pos_v: Variant = meta["pos_m"]
	if typeof(pos_v) != TYPE_DICTIONARY:
		return "N/A"
	var pos: Dictionary = pos_v as Dictionary
	var x: float = float(pos.get("x", pos.get("–", 0.0)))
	var y: float = float(pos.get("y", 0.0))
	var z: float = float(pos.get("z", 0.0))
	return "X=" + str(snappedf(x, 0.001)) + " m / " + str(snappedf(_m_to_ft(x), 0.01)) + " ft" + \
		"\nY=" + str(snappedf(y, 0.001)) + " m / " + str(snappedf(_m_to_ft(y), 0.01)) + " ft" + \
		"\nZ=" + str(snappedf(z, 0.001)) + " m / " + str(snappedf(_m_to_ft(z), 0.01)) + " ft"

func _m_to_ft(m: float) -> float:
	return m * 3.280839895

func _stills_aspect_string(w: int, h: int) -> String:
	if w <= 0 or h <= 0:
		return "N/A"
	var g: int = _stills_gcd(w, h)
	return str(w / g) + ":" + str(h / g)

func _stills_gcd(a: int, b: int) -> int:
	var x: int = abs(a)
	var y: int = abs(b)
	while y != 0:
		var t: int = y
		y = x % y
		x = t
	return max(1, x)

func _stills_camera_id_from_text(text: String) -> String:
	var rx := RegEx.new()
	var err: int = rx.compile("CAM\\d{1,3}|C\\d{1,3}")
	if err != OK:
		return ""
	var m: RegExMatch = rx.search(text.to_upper())
	if m == null:
		return ""
	var raw: String = m.get_string()
	if raw.begins_with("CAM"):
		var n1: int = int(raw.substr(3))
		return "CAM" + str(n1).pad_zeros(2)
	if raw.begins_with("C"):
		var n2: int = int(raw.substr(1))
		return "CAM" + str(n2).pad_zeros(2)
	return raw

# -----------------------------------------------------------------------------
# M67B — Roadmap Recenter: project history ledger + 1080p-first layout export
# -----------------------------------------------------------------------------

func _m67a_project_root() -> String:
	var p: String = ProjectSettings.globalize_path("res://")
	if p.ends_with("/"):
		p = p.substr(0, p.length() - 1)
	return p.get_base_dir()

func _m67a_history_path() -> String:
	return _m67a_project_root() + "/splatviz_project_history.json"

func _m67a_layout_export_dir() -> String:
	return _layout_report_default_root()

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
		return Vector3(float(d.get("–", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))
	if typeof(v) == TYPE_ARRAY:
		var a: Array = v as Array
		if a.size() >= 3:
			return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO

func _m67a_camera_position(c: Dictionary) -> Vector3:
	var direct: Variant = _m67a_value(c, ["position", "pos", "world_position", "origin", "camera_position"], null)
	if direct != null:
		return _m67a_vec3_from_variant(direct)
	return Vector3(float(_m67a_value(c, ["–", "pos_–", "world_–"], 0.0)), float(_m67a_value(c, ["y", "height", "pos_y", "world_y"], 0.0)), float(_m67a_value(c, ["z", "pos_z", "world_z"], 0.0)))

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
	var fx: float = float(_m67a_value(c, ["fx", "fl_x", "focal_x", "f–", "fl_–", "focal_–"], 1817.8))
	var fy: float = float(_m67a_value(c, ["fy", "fl_y", "focal_y"], fx))
	var hfov: float = float(_m67a_value(c, ["hfov", "hfov_deg"], 2.0 * rad_to_deg(atan(float(width) / max(0.0001, 2.0 * fx)))))
	var vfov: float = float(_m67a_value(c, ["vfov", "vfov_deg"], 2.0 * rad_to_deg(atan(float(height) / max(0.0001, 2.0 * fy)))))
	return {"camera": name, "index": idx + 1, "tier": tier, "lens": lens, "resolution": str(width) + "x" + str(height), "width_px": width, "height_px": height, "fx_px": fx, "fy_px": fy, "hfov_deg": hfov, "vfov_deg": vfov, "x_m": pos.x, "y_height_m": pos.y, "z_m": pos.z, "x_ft": _m67a_feet(pos.x), "height_ft": _m67a_feet(pos.y), "z_ft": _m67a_feet(pos.z), "distance_3d_m": dist3, "distance_3d_ft": _m67a_feet(dist3), "floor_distance_m": floor_dist, "floor_distance_ft": _m67a_feet(floor_dist), "azimuth_deg": azimuth, "tilt_pitch_deg": tilt, "target_x_m": target.x, "target_y_m": target.y, "target_z_m": target.z, "construction_note": "Place camera at listed X/Y/Z relative to SplatViz stage origin; verify target/framing with Camera POV before build."}

func _m67a_csv_escape(v: Variant) -> String:
	var t: String = str(v).replace("\"", "\"\"")
	return "\"" + t + "\""

func _m67a_export_camera_layout() -> void:
	_prompt_external_layout_report()

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
	var rec: Dictionary = {"timestamp": Time.get_datetime_string_from_system(false, true), "source": source, "app_version": SPLATVIZ_RELEASE_LABEL, "export_root_path": str(get("export_root_path")), "msplat_dataset_root": str(get("msplat_dataset_root")), "msplat_result_root": str(get("msplat_result_root")), "msplat_log_path": str(get("msplat_log_path")), "latest_ply_path": str(get("latest_ply_path")), "latest_ply_summary": str(get("latest_ply_summary")), "resolution_policy": "1080p-first; 4K only for smoke/source tests unless profile capacity allows", "frame_policy": "scale-only; no crop; no squeeze"}
	var runs: Array = hist["runs"] as Array
	runs.append(rec)
	hist["runs"] = runs
	hist["latest"] = rec
	_m67a_save_history(hist)

# -----------------------------------------------------------------------------
# M67B1 — Analysis toggle + discoverable Export Tools
# -----------------------------------------------------------------------------

func _m67a1_toggle_analysis() -> void:
	if mode == "Comparison" and comparison_panel != null and comparison_panel.visible:
		_set_mode("Focus")
		if comparison_panel != null:
			comparison_panel.visible = false
		if status_label != null:
			status_label.text = "Analysis cleared. Click Analysis again to reopen the breakdown."
		return
	_set_mode("Comparison")
	if comparison_panel != null:
		comparison_panel.visible = true
	if status_label != null:
		status_label.text = "Analysis breakdown open. Click Analysis again to clear it."

func _m67a1_project_root() -> String:
	var p: String = ProjectSettings.globalize_path("res://")
	if p.ends_with("/"):
		p = p.substr(0, p.length() - 1)
	return p.get_base_dir()

func _m67a1_layout_exports_dir() -> String:
	if has_method("_m67a_layout_export_dir"):
		return str(call("_m67a_layout_export_dir"))
	return _layout_report_default_root()

func _m67a1_history_path() -> String:
	if has_method("_m67a_history_path"):
		return str(call("_m67a_history_path"))
	return _m67a1_project_root() + "/splatviz_project_history.json"

func _m67a1_export_camera_layout_safe() -> void:
	if has_method("_m67a_export_camera_layout"):
		call("_m67a_export_camera_layout")
		if status_label != null:
			status_label.text = "Choose an external destination folder for the layout report."
		return
	if status_label != null:
		status_label.text = "Export Camera Layout is not installed. Re-run the current " + SPLATVIZ_RELEASE_LABEL + " package."

func _m67a1_record_snapshot_safe() -> void:
	if has_method("_m67a_record_run_snapshot"):
		call("_m67a_record_run_snapshot", "m67a1_export_tools")
		if status_label != null:
			status_label.text = "Recorded project history snapshot."
		return
	if status_label != null:
		status_label.text = "Project history recorder is not installed. Re-run the current " + SPLATVIZ_RELEASE_LABEL + " package."

func _m67a1_open_history_safe() -> void:
	var path: String = _m67a1_history_path()
	if not FileAccess.file_exists(path) and has_method("_m67a_record_run_snapshot"):
		call("_m67a_record_run_snapshot", "m67a1_create_history")
	OS.shell_open(path)

func _m67a1_open_layout_exports_safe() -> void:
	var dir: String = _m67a1_layout_exports_dir()
	OS.shell_open(dir)

func _m67a1_open_export_tools() -> void:
	var win: Window = get_node_or_null("M67B1_Export_Tools_Window") as Window
	if win == null:
		win = Window.new()
		win.name = "M67B1_Export_Tools_Window"
		win.title = "SplatViz Export Tools"
		win.size = Vector2i(520, 430)
		win.min_size = Vector2i(480, 360)
		win.close_requested.connect(func(): win.visible = false)
		add_child(win)
		var panel: PanelContainer = PanelContainer.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_theme_stylebox_override("panel", _panel_style(Color(0.010, 0.026, 0.028, 1.0)))
		win.add_child(panel)
		var vb: VBoxContainer = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 10)
		panel.add_child(vb)
		_add_label(vb, "Export Tools", 24, Color(0.68, 1.0, 0.82))
		_add_label(vb, "User-facing layout reports are written to the folder you choose. Internal project history lives under Help > Diagnostics.", 14, Color(0.82, 0.93, 0.89))
		_add_button(vb, "Export Layout Report…", func(): _prompt_external_layout_report())
		_add_button(vb, "Open Last Layout Report Folder", func(): _m67f_open_layout_report_folder())
		_add_button(vb, "Choose SplatViz Export Folder…", func(): _choose_export_folder())
		_add_label(vb, "Frame policy: preserve camera frame, scale only, no crop, no squeeze.", 13, Color(0.78, 0.94, 0.86))
	win.visible = true
	win.popup_centered(Vector2i(520, 430))
	if status_label != null:
		status_label.text = "Export Tools opened. Use Export Camera Layout for rigger/build CSV + JSON."

func _m67c_left_panel_width() -> float:
	if left_panel_collapsed_m67c:
		return 0.0
	return clamp(left_panel_width_m67c, 260.0, 520.0)

func _m67c_init_left_panel_controls() -> void:
	if ui_layer == null:
		return
	var root = ui_layer.get_child(0) if ui_layer.get_child_count() > 0 else null
	if root == null:
		return
	if left_panel_toggle_button_m67c == null:
		left_panel_toggle_button_m67c = Button.new()
		left_panel_toggle_button_m67c.text = "‹"
		left_panel_toggle_button_m67c.tooltip_text = "Collapse / restore left rail"
		left_panel_toggle_button_m67c.size = Vector2(34, 30)
		left_panel_toggle_button_m67c.focus_mode = Control.FOCUS_NONE
		left_panel_toggle_button_m67c.mouse_filter = Control.MOUSE_FILTER_STOP
		left_panel_toggle_button_m67c.pressed.connect(func(): _m67c_toggle_left_panel())
		root.add_child(left_panel_toggle_button_m67c)
	if left_panel_narrow_button_m67c == null:
		left_panel_narrow_button_m67c = Button.new()
		left_panel_narrow_button_m67c.text = "−"
		left_panel_narrow_button_m67c.tooltip_text = "Narrow left rail"
		left_panel_narrow_button_m67c.size = Vector2(30, 30)
		left_panel_narrow_button_m67c.focus_mode = Control.FOCUS_NONE
		left_panel_narrow_button_m67c.mouse_filter = Control.MOUSE_FILTER_STOP
		left_panel_narrow_button_m67c.pressed.connect(func(): _m67c_resize_left_panel(-40.0))
		root.add_child(left_panel_narrow_button_m67c)
	if left_panel_wide_button_m67c == null:
		left_panel_wide_button_m67c = Button.new()
		left_panel_wide_button_m67c.text = "+"
		left_panel_wide_button_m67c.tooltip_text = "Widen left rail"
		left_panel_wide_button_m67c.size = Vector2(30, 30)
		left_panel_wide_button_m67c.focus_mode = Control.FOCUS_NONE
		left_panel_wide_button_m67c.mouse_filter = Control.MOUSE_FILTER_STOP
		left_panel_wide_button_m67c.pressed.connect(func(): _m67c_resize_left_panel(40.0))
		root.add_child(left_panel_wide_button_m67c)
	_m67c_update_left_panel_controls()

func _m67c_update_left_panel_controls() -> void:
	var s = get_viewport().get_visible_rect().size
	var w = _m67c_left_panel_width()
	if left_panel != null:
		left_panel.visible = not left_panel_collapsed_m67c
		left_panel.position = Vector2(0, TOP_BAR_H)
		left_panel.size = Vector2(w, max(1.0, s.y - TOP_BAR_H))
	if left_panel_toggle_button_m67c != null:
		left_panel_toggle_button_m67c.text = "›" if left_panel_collapsed_m67c else "‹"
		left_panel_toggle_button_m67c.position = Vector2(w + 6, TOP_BAR_H + 8)
	if left_panel_narrow_button_m67c != null:
		left_panel_narrow_button_m67c.visible = not left_panel_collapsed_m67c
		left_panel_narrow_button_m67c.position = Vector2(w + 44, TOP_BAR_H + 8)
	if left_panel_wide_button_m67c != null:
		left_panel_wide_button_m67c.visible = not left_panel_collapsed_m67c
		left_panel_wide_button_m67c.position = Vector2(w + 78, TOP_BAR_H + 8)
	if prev_cam_button != null:
		prev_cam_button.position = Vector2(w + 12, s.y * 0.48)

func _m67c_toggle_left_panel() -> void:
	left_panel_collapsed_m67c = not left_panel_collapsed_m67c
	_m67c_update_left_panel_controls()
	_update_orbit_camera()

func _m67c_resize_left_panel(delta: float) -> void:
	left_panel_collapsed_m67c = false
	left_panel_width_m67c = clamp(left_panel_width_m67c + delta, 260.0, 520.0)
	_m67c_update_left_panel_controls()
	_update_orbit_camera()

func _m67c_init_layout_report_dialog() -> void:
	if layout_report_dialog_m67c != null:
		return
	layout_report_dialog_m67c = FileDialog.new()
	layout_report_dialog_m67c.title = "Choose Camera Layout Report Export Folder"
	layout_report_dialog_m67c.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	layout_report_dialog_m67c.access = FileDialog.ACCESS_FILESYSTEM
	layout_report_dialog_m67c.current_dir = _layout_report_default_root()
	layout_report_dialog_m67c.dir_selected.connect(func(dir): await _export_layout_report_to_dir(dir))
	add_child(layout_report_dialog_m67c)

func _m67c_choose_layout_report_folder() -> void:
	_prompt_external_layout_report()

func _m67c_render_camera_dialog(selected_only: bool) -> void:
	var dlg = ConfirmationDialog.new()
	dlg.title = "Render Selected Camera" if selected_only else "Render Cameras"
	dlg.dialog_text = "Choose render resolution. 1080p is the current working default; 4K is available for small tests."
	dlg.ok_button_text = "1080p"
	dlg.cancel_button_text = "Cancel"
	dlg.add_button("4K", false, "4k")
	add_child(dlg)
	dlg.confirmed.connect(func():
		_m67c_dispatch_render(selected_only, "1080p")
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.custom_action.connect(func(action):
		if str(action) == "4k":
			_m67c_dispatch_render(selected_only, "4k")
			dlg.queue_free()
	)
	dlg.popup_centered(Vector2i(460, 180))

func _m67c_dispatch_render(selected_only: bool, res_label: String) -> void:
	if res_label == "4k":
		if selected_only and has_method("_render_source_selected_camera"):
			call("_render_source_selected_camera")
		elif (not selected_only) and has_method("_render_source_all_cameras"):
			call("_render_source_all_cameras")
		else:
			if selected_only:
				_render_selected_camera()
			else:
				_render_all_cameras()
			if status_label:
				status_label.text = "4K render path not present; rendered with current clean-render size."
		return
	if selected_only:
		_render_selected_camera()
	else:
		_render_all_cameras()

func _m67c_timestamp() -> String:
	var d = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [int(d["year"]), int(d["month"]), int(d["day"]), int(d["hour"]), int(d["minute"]), int(d["second"])]

func _m67c_feet(m: float) -> float:
	return m / FT_TO_M

func _m67c_ft_in(m: float) -> String:
	var total_inches = int(round(m * 39.3700787402))
	var ft = int(floor(float(total_inches) / 12.0))
	var inch = total_inches - ft * 12
	return str(ft) + "'-" + str(inch) + "\""

func _m67c_layout_rows() -> Array:
	var rows: Array = []
	for c in cameras:
		var pos: Vector3 = c["position"] as Vector3
		var floor_m = sqrt(pos.x * pos.x + pos.z * pos.z)
		var dist3 = pos.distance_to(TARGET)
		var tilt = rad_to_deg(atan2(TARGET.y - pos.y, max(floor_m, 0.001)))
		var row = {
			"camera_id": str(c["id"]),
			"tier": str(c["tier"]),
			"azimuth_deg": float(c["azimuth_deg"]),
			"height_m": pos.y,
			"height_ft": _m67c_feet(pos.y),
			"height_ft_in": _m67c_ft_in(pos.y),
			"x_m": pos.x,
			"y_m": pos.y,
			"z_m": pos.z,
			"x_ft": _m67c_feet(pos.x),
			"y_ft": _m67c_feet(pos.y),
			"z_ft": _m67c_feet(pos.z),
			"floor_dist_m": floor_m,
			"floor_dist_ft": _m67c_feet(floor_m),
			"floor_dist_ft_in": _m67c_ft_in(floor_m),
			"distance_3d_m": dist3,
			"distance_3d_ft": _m67c_feet(dist3),
			"distance_3d_ft_in": _m67c_ft_in(dist3),
			"tilt_deg": tilt,
			"portrait": bool(c["portrait"]),
			"mount_zone": str(c["mount"]),
			"lens_name": "Rokinon 24mm T5.6",
			"fx_px": 1817.8,
			"fy_px": 1817.8,
			"hfov_deg": 55.7,
			"vfov_deg": 33.1,
			"supported_resolution": "1920x1080 or 3840x2160"
		}
		rows.append(row)
	return rows

func _m67c_csv_escape(v) -> String:
	var s = str(v)
	s = s.replace("\"", "\"\"")
	if s.find(",") >= 0 or s.find("\n") >= 0 or s.find("\"") >= 0:
		return "\"" + s + "\""
	return s

func _m67c_write_layout_csv(path: String, rows: Array) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	var keys = ["camera_id", "tier", "azimuth_deg", "height_m", "height_ft_in", "floor_dist_m", "floor_dist_ft_in", "distance_3d_m", "distance_3d_ft_in", "tilt_deg", "x_m", "y_m", "z_m", "mount_zone", "lens_name", "fx_px", "hfov_deg", "vfov_deg"]
	f.store_line(",".join(keys))
	for row in rows:
		var vals: Array = []
		for k in keys:
			vals.append(_m67c_csv_escape(row.get(k, "")))
		f.store_line(",".join(vals))
	f.close()

func _m67c_export_layout_report_to(out_dir: String) -> void:
	if out_dir == "":
		_prompt_external_layout_report()
		return
	await _export_layout_report_to_dir(out_dir)


var m67d_left_rail_collapsed := false

func _m67d_left_edge() -> float:
	return 0.0 if m67d_left_rail_collapsed else LEFT_PANEL_W

func _m67d_apply_clear_viewport() -> void:
	# Default to maximum viewport area. Inspector remains available from the top toolbar.
	_m68a_set_inspector_visible(false)
	if rig_root != null:
		rig_root.visible = false
	_layout_ui()

func _m67d_toggle_left_rail() -> void:
	m67d_left_rail_collapsed = not m67d_left_rail_collapsed
	if left_panel != null:
		left_panel.visible = not m67d_left_rail_collapsed
	_layout_ui()

func _m67d_resize_left_rail(delta_w: float) -> void:
	m67d_left_rail_collapsed = false
	LEFT_PANEL_W = clamp(LEFT_PANEL_W + delta_w, 240.0, 460.0)
	if left_panel != null:
		left_panel.visible = true
	_layout_ui()

func _m67d_stamp() -> String:
	var d = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [int(d["year"]), int(d["month"]), int(d["day"]), int(d["hour"]), int(d["minute"]), int(d["second"])]

func _m67d_prompt_layout_report_folder() -> void:
	_prompt_external_layout_report()

func _m67d_export_layout_report_to_dir(base_dir: String) -> void:
	await _export_layout_report_to_dir(base_dir)

func _m67d_write_text(path: String, body: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write " + path)
		return
	f.store_string(body)
	f.close()

func _m67d_camera_row(c: Dictionary) -> Dictionary:
	var pos: Vector3 = c["position"] as Vector3
	var dist3 = pos.distance_to(TARGET)
	var floor_dist = Vector2(pos.x, pos.z).length()
	var aim = (TARGET - pos).normalized()
	var tilt = rad_to_deg(asin(aim.y))
	return {
		"camera": str(c["id"]),
		"tier": str(c.get("tier", "")),
		"lens": "Rokinon 24mm T5.6",
		"resolution": "1920x1080 / 3840x2160 supported",
		"position_m": [snapped(pos.x, 0.001), snapped(pos.y, 0.001), snapped(pos.z, 0.001)],
		"position_ft": [snapped(pos.x / FT_TO_M, 0.01), snapped(pos.y / FT_TO_M, 0.01), snapped(pos.z / FT_TO_M, 0.01)],
		"height_m": snapped(pos.y, 0.001),
		"height_ft": snapped(pos.y / FT_TO_M, 0.01),
		"distance_3d_m": snapped(dist3, 0.001),
		"distance_3d_ft": snapped(dist3 / FT_TO_M, 0.01),
		"floor_distance_m": snapped(floor_dist, 0.001),
		"floor_distance_ft": snapped(floor_dist / FT_TO_M, 0.01),
		"azimuth_deg": snapped(float(c.get("azimuth_deg", 0.0)), 0.1),
		"tilt_deg": snapped(tilt, 0.1),
		"mount_zone": str(c.get("mount", "")),
		"notes": "Aim film plane at performer head focus target unless modified on site."
	}

func _m67d_layout_json() -> Dictionary:
	var rows: Array = []
	for c in cameras:
		rows.append(_m67d_camera_row(c))
	return {
		"report": "SplatViz camera layout report",
		"version": "M67D",
		"stage": {"name": "NOZ Stage #1", "width_m": STAGE_W_M, "depth_m": STAGE_D_M, "grid_height_m": GRID_H_M},
		"focus_target_m": [TARGET.x, TARGET.y, TARGET.z],
		"frame_policy": "preserve camera frame, scale only, no crop, no squeeze",
		"cameras": rows
	}

func _m67d_csv_escape(v) -> String:
	var s = str(v)
	s = s.replace("\"", "\"\"")
	return "\"" + s + "\""

func _m67d_layout_csv() -> String:
	var header = ["camera", "tier", "lens", "height_m", "height_ft", "floor_distance_m", "floor_distance_ft", "distance_3d_m", "distance_3d_ft", "azimuth_deg", "tilt_deg", "x_m", "y_m", "z_m", "mount_zone", "notes"]
	var lines = [",".join(header)]
	for c in cameras:
		var r = _m67d_camera_row(c)
		var pm: Array = r["position_m"]
		var vals = [r["camera"], r["tier"], r["lens"], r["height_m"], r["height_ft"], r["floor_distance_m"], r["floor_distance_ft"], r["distance_3d_m"], r["distance_3d_ft"], r["azimuth_deg"], r["tilt_deg"], pm[0], pm[1], pm[2], r["mount_zone"], r["notes"]]
		var escaped: Array[String] = []
		for v in vals:
			escaped.append(_m67d_csv_escape(v))
		lines.append(",".join(escaped))
	return "\n".join(lines) + "\n"

func _m67d_svg_point(pos: Vector3, kind: String, w: float, h: float, margin: float) -> Vector2:
	if kind == "top":
		return Vector2(margin + (pos.x + STAGE_W_M * 0.5) / STAGE_W_M * (w - margin * 2.0), margin + (pos.z + STAGE_D_M * 0.5) / STAGE_D_M * (h - margin * 2.0))
	elif kind == "front":
		return Vector2(margin + (pos.x + STAGE_W_M * 0.5) / STAGE_W_M * (w - margin * 2.0), h - margin - pos.y / GRID_H_M * (h - margin * 2.0))
	else:
		return Vector2(margin + (pos.z + STAGE_D_M * 0.5) / STAGE_D_M * (w - margin * 2.0), h - margin - pos.y / GRID_H_M * (h - margin * 2.0))

func _m67d_layout_svg(kind: String) -> String:
	var w = 1200.0
	var h = 800.0
	var m = 80.0
	var title = "Top Plan" if kind == "top" else ("Front Elevation" if kind == "front" else "Side Elevation")
	var lines: Array[String] = []
	lines.append('<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="800" viewBox="0 0 1200 800">')
	lines.append('<rect width="1200" height="800" fill="#faf8ef"/>')
	lines.append('<text x="60" y="45" font-family="Arial" font-size="28" font-weight="700">SplatViz Camera Layout — ' + title + '</text>')
	lines.append('<text x="60" y="75" font-family="Arial" font-size="16">Stage: %.2fm × %.2fm / %.1fft × %.1fft · Grid %.2fm / %.1fft</text>' % [STAGE_W_M, STAGE_D_M, STAGE_W_M / FT_TO_M, STAGE_D_M / FT_TO_M, GRID_H_M, GRID_H_M / FT_TO_M])
	lines.append('<rect x="%s" y="%s" width="%s" height="%s" fill="none" stroke="#111" stroke-width="2"/>' % [str(m), str(m + 40.0), str(w - m * 2.0), str(h - m * 2.0 - 40.0)])
	# grid
	for i in range(1, 10):
		var x = m + i * (w - m * 2.0) / 10.0
		var y = m + 40.0 + i * (h - m * 2.0 - 40.0) / 10.0
		lines.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#d8d3c6" stroke-width="1"/>' % [x, m + 40.0, x, h - m])
		lines.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#d8d3c6" stroke-width="1"/>' % [m, y, w - m, y])
	# performer / focus
	var target_pt = _m67d_svg_point(TARGET, kind, w, h, m)
	lines.append('<circle cx="%.1f" cy="%.1f" r="10" fill="#111"/><text x="%.1f" y="%.1f" font-family="Arial" font-size="14">Performer focus</text>' % [target_pt.x, target_pt.y, target_pt.x + 14.0, target_pt.y - 10.0])
	for c in cameras:
		var pos: Vector3 = c["position"] as Vector3
		var p = _m67d_svg_point(pos, kind, w, h, m)
		var color = "#1b6cff"
		if str(c.get("tier", "")) == "low":
			color = "#0b8f55"
		elif str(c.get("tier", "")) == "high":
			color = "#c43b2f"
		lines.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#999" stroke-width="1" stroke-dasharray="4 5"/>' % [p.x, p.y, target_pt.x, target_pt.y])
		lines.append('<rect x="%.1f" y="%.1f" width="22" height="14" transform="rotate(0 %.1f %.1f)" fill="%s" stroke="#111" stroke-width="1"/>' % [p.x - 11.0, p.y - 7.0, p.x, p.y, color])
		lines.append('<text x="%.1f" y="%.1f" font-family="Arial" font-size="13" font-weight="700">%s</text>' % [p.x + 13.0, p.y + 4.0, str(c["id"])])
	lines.append('</svg>')
	return "\n".join(lines)

func _m67d_layout_html(top_svg: String, front_svg: String, side_svg: String) -> String:
	var cards: Array[String] = []
	for c in cameras:
		var r = _m67d_camera_row(c)
		cards.append('<div class="card"><h3>%s</h3><p><b>%s</b> · %s</p><p>Height: %sm / %sft<br>Floor dist: %sm / %sft<br>3D dist: %sm / %sft<br>Azimuth: %s° · Tilt: %s°</p><p>Mount: %s</p></div>' % [r["camera"], r["tier"], r["lens"], str(r["height_m"]), str(r["height_ft"]), str(r["floor_distance_m"]), str(r["floor_distance_ft"]), str(r["distance_3d_m"]), str(r["distance_3d_ft"]), str(r["azimuth_deg"]), str(r["tilt_deg"]), r["mount_zone"]])
	return '<!doctype html><html><head><meta charset="utf-8"><title>SplatViz Layout Report</title><style>body{font-family:Arial,sans-serif;background:#fbfaf4;color:#111;margin:32px}h1{font-size:34px}h2{page-break-before:always;border-top:2px solid #111;padding-top:18px}.meta{font-size:15px;line-height:1.45}.diagram{background:white;border:1px solid #bbb;margin:18px 0;padding:10px}.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.card{border:1px solid #999;background:white;padding:12px;break-inside:avoid}.card h3{margin:0 0 8px 0}@media print{body{margin:16mm}.cards{grid-template-columns:repeat(2,1fr)}} </style></head><body><h1>SplatViz Camera Layout Report</h1><div class="meta"><b>Stage:</b> NOZ Stage #1 — %.2fm × %.2fm / %.1fft × %.1fft<br><b>Grid height:</b> %.2fm / %.1fft<br><b>Frame policy:</b> preserve camera frame, scale only, no crop, no squeeze<br><b>Purpose:</b> camera mounting and aiming handoff for a third-party rigging/camera team.</div><h2>Top Plan</h2><div class="diagram">%s</div><h2>Front Elevation</h2><div class="diagram">%s</div><h2>Side Elevation</h2><div class="diagram">%s</div><h2>Camera Mounting Schedule</h2><div class="cards">%s</div></body></html>' % [STAGE_W_M, STAGE_D_M, STAGE_W_M / FT_TO_M, STAGE_D_M / FT_TO_M, GRID_H_M, GRID_H_M / FT_TO_M, top_svg, front_svg, side_svg, "\n".join(cards)]

func _m67e_prompt_layout_report_folder() -> void:
	_prompt_external_layout_report()

func _prompt_layout_report_folder() -> void:
	_prompt_external_layout_report()

func _export_camera_layout() -> void:
	_prompt_external_layout_report()

func _m67e_export_layout_report_to_dir(base_dir: String) -> void:
	await _export_layout_report_to_dir(base_dir)


var m67f_nav_dragging := false
var m67f_nav_drag_offset := Vector2.ZERO
var m67f_nav_collapsed := false
var m67f_nav_position := Vector2(-1, -1)


var m67f_last_layout_report_folder := ""
var m67f_focus_legend_panel: PanelContainer

func _m67f_stamp() -> String:
	var d = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [int(d["year"]), int(d["month"]), int(d["day"]), int(d["hour"]), int(d["minute"]), int(d["second"])]

func _m67f_left_edge() -> float:
	return 0.0 if left_panel != null and not left_panel.visible else LEFT_PANEL_W

func _m67f_prompt_layout_report_folder() -> void:
	_prompt_external_layout_report()

func _m67f_open_layout_report_folder() -> void:
	if m67f_last_layout_report_folder != "" and DirAccess.dir_exists_absolute(m67f_last_layout_report_folder):
		OS.shell_open(m67f_last_layout_report_folder)
	else:
		OS.shell_open(_layout_report_default_root())

func _m67f_export_layout_report_to_dir(base_dir: String) -> void:
	await _export_layout_report_to_dir(base_dir)

func _m67f_render_contact_sheet_images(render_dir: String, size: Vector2i) -> void:
	DirAccess.make_dir_recursive_absolute(render_dir)
	for c in cameras:
		var p = render_dir.path_join(_camera_unique_filename(c))
		await _render_camera_to_path(c, p, size, true)
	if status_label:
		status_label.text = "Rendered " + str(cameras.size()) + " clean contact-sheet stills at " + str(size.x) + "×" + str(size.y)

func _m67f_write_text(path: String, body: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write " + path)
		return
	f.store_string(body)
	f.close()

func _m67f_camera_row(c: Dictionary) -> Dictionary:
	var pos: Vector3 = c["position"] as Vector3
	var dist3 = pos.distance_to(TARGET)
	var floor_dist = Vector2(pos.x, pos.z).length()
	var aim = (TARGET - pos).normalized()
	var tilt = rad_to_deg(asin(aim.y))
	return {
		"camera": str(c["id"]),
		"tier": str(c.get("tier", "")),
		"lens": "Rokinon 24mm T5.6",
		"resolution": "1920x1080 / 3840x2160 supported",
		"position_m": [snapped(pos.x, 0.001), snapped(pos.y, 0.001), snapped(pos.z, 0.001)],
		"position_ft": [snapped(pos.x / FT_TO_M, 0.01), snapped(pos.y / FT_TO_M, 0.01), snapped(pos.z / FT_TO_M, 0.01)],
		"height_m": snapped(pos.y, 0.001),
		"height_ft": snapped(pos.y / FT_TO_M, 0.01),
		"distance_3d_m": snapped(dist3, 0.001),
		"distance_3d_ft": snapped(dist3 / FT_TO_M, 0.01),
		"floor_distance_m": snapped(floor_dist, 0.001),
		"floor_distance_ft": snapped(floor_dist / FT_TO_M, 0.01),
		"azimuth_deg": snapped(float(c.get("azimuth_deg", 0.0)), 0.1),
		"tilt_deg": snapped(tilt, 0.1),
		"mount_zone": str(c.get("mount", "")),
		"notes": "Aim film plane at performer head focus target unless modified on site."
	}

func _m67f_layout_json() -> Dictionary:
	var rows: Array = []
	for c in cameras:
		rows.append(_m67f_camera_row(c))
	return {
		"report": "SplatViz camera layout report",
		"version": "M67F",
		"stage": {"name": "NOZ Stage #1", "width_m": STAGE_W_M, "depth_m": STAGE_D_M, "grid_height_m": GRID_H_M},
		"focus_target_m": [TARGET.x, TARGET.y, TARGET.z],
		"frame_policy": "preserve camera frame, scale only, no crop, no squeeze, no letterbox",
		"contact_render_size_px": [M67F_REPORT_CONTACT_RENDER_SIZE.x, M67F_REPORT_CONTACT_RENDER_SIZE.y],
		"cameras": rows
	}

func _m67f_csv_escape(v) -> String:
	var s = str(v)
	s = s.replace("\"", "\"\"")
	return "\"" + s + "\""

func _m67f_layout_csv() -> String:
	var header = ["camera", "tier", "lens", "height_m", "height_ft", "floor_distance_m", "floor_distance_ft", "distance_3d_m", "distance_3d_ft", "azimuth_deg", "tilt_deg", "x_m", "y_m", "z_m", "mount_zone", "contact_render", "notes"]
	var lines = [",".join(header)]
	for c in cameras:
		var r = _m67f_camera_row(c)
		var pm: Array = r["position_m"]
		var vals = [r["camera"], r["tier"], r["lens"], r["height_m"], r["height_ft"], r["floor_distance_m"], r["floor_distance_ft"], r["distance_3d_m"], r["distance_3d_ft"], r["azimuth_deg"], r["tilt_deg"], pm[0], pm[1], pm[2], r["mount_zone"], "camera_contact_renders/" + _camera_unique_filename(c), r["notes"]]
		var escaped: Array[String] = []
		for v in vals:
			escaped.append(_m67f_csv_escape(v))
		lines.append(",".join(escaped))
	return "\n".join(lines) + "\n"

func _m67f_svg_point(pos: Vector3, kind: String, w: float, h: float, margin: float) -> Vector2:
	if kind == "top":
		return Vector2(margin + (pos.x + STAGE_W_M * 0.5) / STAGE_W_M * (w - margin * 2.0), margin + 40.0 + (pos.z + STAGE_D_M * 0.5) / STAGE_D_M * (h - margin * 2.0 - 40.0))
	elif kind == "front":
		return Vector2(margin + (pos.x + STAGE_W_M * 0.5) / STAGE_W_M * (w - margin * 2.0), h - margin - pos.y / GRID_H_M * (h - margin * 2.0 - 40.0))
	else:
		return Vector2(margin + (pos.z + STAGE_D_M * 0.5) / STAGE_D_M * (w - margin * 2.0), h - margin - pos.y / GRID_H_M * (h - margin * 2.0 - 40.0))

func _m67f_layout_svg(kind: String) -> String:
	var w = 1200.0
	var h = 800.0
	var m = 80.0
	var title = "Top Plan" if kind == "top" else ("Front Elevation" if kind == "front" else "Side Elevation")
	var lines: Array[String] = []
	lines.append('<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="800" viewBox="0 0 1200 800">')
	lines.append('<rect width="1200" height="800" fill="#faf8ef"/>')
	lines.append('<text x="60" y="45" font-family="Arial" font-size="28" font-weight="700">SplatViz Camera Layout — ' + title + '</text>')
	lines.append('<text x="60" y="75" font-family="Arial" font-size="16">Stage: %.2fm × %.2fm / %.1fft × %.1fft · Grid %.2fm / %.1fft</text>' % [STAGE_W_M, STAGE_D_M, STAGE_W_M / FT_TO_M, STAGE_D_M / FT_TO_M, GRID_H_M, GRID_H_M / FT_TO_M])
	lines.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="none" stroke="#111" stroke-width="2"/>' % [m, m + 40.0, w - m * 2.0, h - m * 2.0 - 40.0])
	for i in range(1, 10):
		var x = m + i * (w - m * 2.0) / 10.0
		var y = m + 40.0 + i * (h - m * 2.0 - 40.0) / 10.0
		lines.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#d8d3c6" stroke-width="1"/>' % [x, m + 40.0, x, h - m])
		lines.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#d8d3c6" stroke-width="1"/>' % [m, y, w - m, y])
	var target_pt = _m67f_svg_point(TARGET, kind, w, h, m)
	lines.append('<circle cx="%.1f" cy="%.1f" r="10" fill="#111"/><text x="%.1f" y="%.1f" font-family="Arial" font-size="14">Performer focus</text>' % [target_pt.x, target_pt.y, target_pt.x + 14.0, target_pt.y - 10.0])
	for c in cameras:
		var pos: Vector3 = c["position"] as Vector3
		var p = _m67f_svg_point(pos, kind, w, h, m)
		var color = "#1b6cff"
		if str(c.get("tier", "")) == "low":
			color = "#0b8f55"
		elif str(c.get("tier", "")) == "high":
			color = "#c43b2f"
		lines.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#999" stroke-width="1" stroke-dasharray="4 5"/>' % [p.x, p.y, target_pt.x, target_pt.y])
		lines.append('<rect x="%.1f" y="%.1f" width="22" height="14" fill="%s" stroke="#111" stroke-width="1"/>' % [p.x - 11.0, p.y - 7.0, color])
		lines.append('<text x="%.1f" y="%.1f" font-family="Arial" font-size="13" font-weight="700">%s</text>' % [p.x + 13.0, p.y + 4.0, str(c["id"])])
	lines.append('</svg>')
	return "\n".join(lines)

func _m67f_layout_html(top_svg: String, front_svg: String, side_svg: String, thumb_size: Vector2i) -> String:
	var cards: Array[String] = []
	for c in cameras:
		var r = _m67f_camera_row(c)
		var img_rel = "camera_contact_renders/" + _camera_unique_filename(c)
		cards.append('<div class="card"><img class="thumb" src="%s" alt="%s clean camera render"><h3>%s</h3><p><b>%s</b> · %s</p><p>Clean render: %d×%d, 16:9, preserve frame / no crop / no squeeze / no letterbox</p><p>Height AFF: %sm / %sft<br>Floor dist: %sm / %sft<br>3D dist: %sm / %sft<br>Azimuth: %s° · Tilt: %s°</p><p>Mount: %s</p><p class="note">%s</p></div>' % [img_rel, r["camera"], r["camera"], r["tier"], r["lens"], thumb_size.x, thumb_size.y, str(r["height_m"]), str(r["height_ft"]), str(r["floor_distance_m"]), str(r["floor_distance_ft"]), str(r["distance_3d_m"]), str(r["distance_3d_ft"]), str(r["azimuth_deg"]), str(r["tilt_deg"]), r["mount_zone"], r["notes"]])
	return '<!doctype html><html><head><meta charset="utf-8"><title>SplatViz Layout Report</title><style>body{font-family:Arial,sans-serif;background:#fbfaf4;color:#111;margin:32px}h1{font-size:34px}h2{page-break-before:always;border-top:2px solid #111;padding-top:18px}.meta{font-size:15px;line-height:1.45}.diagram{background:white;border:1px solid #bbb;margin:18px 0;padding:10px}.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.card{border:1px solid #999;background:white;padding:10px;break-inside:avoid}.card h3{margin:8px 0 8px 0}.thumb{width:100%;aspect-ratio:16/9;object-fit:contain;background:#111;border:1px solid #bbb}.note{font-size:12px;color:#333}@media print{body{margin:13mm}.cards{grid-template-columns:repeat(2,1fr)}.card{page-break-inside:avoid}.thumb{max-height:58mm}}</style></head><body><h1>SplatViz Camera Layout Report</h1><div class="meta"><b>Stage:</b> NOZ Stage #1 — %.2fm × %.2fm / %.1fft × %.1fft<br><b>Grid height:</b> %.2fm / %.1fft<br><b>Frame policy:</b> preserve camera frame, scale only, no crop, no squeeze, no letterbox<br><b>Contact renders:</b> clean camera outputs at %d×%d for report scale.<br><b>Purpose:</b> camera mounting and aiming handoff for a third-party rigging/camera team.</div><h2>Top Plan</h2><div class="diagram">%s</div><h2>Front Elevation</h2><div class="diagram">%s</div><h2>Side Elevation</h2><div class="diagram">%s</div><h2>Camera Contact Sheet / Mounting Schedule</h2><div class="cards">%s</div></body></html>' % [STAGE_W_M, STAGE_D_M, STAGE_W_M / FT_TO_M, STAGE_D_M / FT_TO_M, GRID_H_M, GRID_H_M / FT_TO_M, thumb_size.x, thumb_size.y, top_svg, front_svg, side_svg, "\n".join(cards)]

func _m67f_focus_mat(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.no_depth_test = false
	return m

func _m67f_cylinder_between(a: Vector3, b: Vector3, radius: float, mat: Material, name: String) -> MeshInstance3D:
	var dir = b - a
	var len = dir.length()
	var mi = MeshInstance3D.new()
	mi.name = name
	if len < 0.001:
		return mi
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = len
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = a.lerp(b, 0.5)
	mi.quaternion = Quaternion(Vector3.UP, dir.normalized())
	return mi

func _m67f_add_focus_arrow_for_selected() -> void:
	_m67g_add_focus_arrow_for_selected()

func _m67f_update_focus_legend() -> void:
	if ui_layer == null:
		return
	if m67f_focus_legend_panel == null:
		_m67f_build_focus_legend()
	m67f_focus_legend_panel.visible = mode == "Focus"
	m67f_focus_legend_panel.position = Vector2(_m67f_left_edge() + 22, TOP_BAR_H + 220)

func _m67f_build_focus_legend() -> void:
	m67f_focus_legend_panel = PanelContainer.new()
	m67f_focus_legend_panel.name = "M67F Focus Color Legend"
	m67f_focus_legend_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m67f_focus_legend_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.010, 0.030, 0.034, 0.84)))
	ui_layer.add_child(m67f_focus_legend_panel)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	m67f_focus_legend_panel.add_child(vb)
	var title = Label.new()
	title.text = "Focus Color Key"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.68, 1.0, 0.82))
	vb.add_child(title)
	_m67f_add_legend_row(vb, Color(1.0, 0.34, 0.08, 0.88), "unusable")
	_m67f_add_legend_row(vb, Color(1.0, 0.80, 0.08, 0.88), "acceptable")
	_m67f_add_legend_row(vb, Color(0.25, 1.0, 0.42, 0.92), "sharp / focus target")
	_m67f_add_legend_row(vb, Color(0.20, 0.65, 1.0, 0.82), "far unusable")

func _m67f_add_legend_row(parent: VBoxContainer, color: Color, label_text: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var swatch = ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(28, 12)
	row.add_child(swatch)
	var l = Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.82, 0.94, 0.88))
	row.add_child(l)

func _m67f_nav_legend_gui_input(event: InputEvent) -> void:
	if nav_legend_panel == null:
		return
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			m67f_nav_dragging = mb.pressed
			m67f_nav_drag_offset = mb.position
			if mb.pressed:
				nav_legend_panel.move_to_front()
	elif event is InputEventMouseMotion and m67f_nav_dragging:
		var mm = event as InputEventMouseMotion
		m67f_nav_position = nav_legend_panel.position + mm.relative
		_m67f_layout_nav_legend()

func _m67f_layout_nav_legend() -> void:
	if nav_legend_panel == null:
		return
	var s = get_viewport().get_visible_rect().size
	if m67f_nav_position.x < 0.0:
		m67f_nav_position = Vector2(_m67f_left_edge() + 18, TOP_BAR_H + 14)
	m67f_nav_position.x = clamp(m67f_nav_position.x, 4.0, max(4.0, s.x - 240.0))
	m67f_nav_position.y = clamp(m67f_nav_position.y, TOP_BAR_H + 4.0, max(TOP_BAR_H + 4.0, s.y - 190.0))
	nav_legend_panel.position = m67f_nav_position
	nav_legend_panel.size = Vector2(226, 36 if m67f_nav_collapsed else 178)
	_m67f_apply_nav_minimized()

func _m67f_toggle_nav_minimized() -> void:
	_m67f_set_nav_minimized(not m67f_nav_collapsed)

func _m67f_set_nav_minimized(v: bool) -> void:
	m67f_nav_collapsed = v
	_m67f_apply_nav_minimized()
	_m67f_layout_nav_legend()

func _m67f_apply_nav_minimized() -> void:
	if nav_legend_panel == null:
		return
	var vb = nav_legend_panel.get_child(0) if nav_legend_panel.get_child_count() > 0 else null
	if vb != null and vb.get_child_count() > 1:
		vb.get_child(1).visible = not m67f_nav_collapsed

# --- SplatViz M67G blocking report + focus ticks BEGIN ---
# M67G fixes two real blockers from the M67F pass:
# 1) The layout report waits for clean contact renders to exist before building/opening HTML.
# 2) Focus mode uses a recoverable color key plus distance ticks distributed along the focus ray.
const M67G_CONTACT_RENDER_SIZE = Vector2i(1280, 720)
const M67G_FOCUS_RED = Color(1.0, 0.23, 0.04, 0.62)
const M67G_FOCUS_YELLOW = Color(1.0, 0.78, 0.06, 0.50)
const M67G_FOCUS_GREEN = Color(0.16, 0.95, 0.34, 0.52)
const M67G_FOCUS_BLUE = Color(0.18, 0.58, 1.0, 0.44)

func _m67g_timestamp() -> String:
	var d = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [int(d.year), int(d.month), int(d.day), int(d.hour), int(d.minute), int(d.second)]

func _m67g_num(v: float, places: int = 2) -> String:
	var m = pow(10.0, float(places))
	return str(snapped(v, 1.0 / m))

func _m67g_ft(meters: float) -> String:
	return _m67g_num(meters / FT_TO_M, 2) + " ft"

func _m67g_html_escape(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

func _m67g_csv_text(s: String) -> String:
	var out = s.replace("\"", "\"\"")
	if out.find(",") >= 0 or out.find("\n") >= 0 or out.find("\"") >= 0:
		return "\"" + out + "\""
	return out

func _m67g_margin_summary(margins: Dictionary) -> String:
	return "L %s%% · R %s%% · T %s%% · B %s%%" % [
		_m67g_num(float(margins.get("left_pct", 0.0))),
		_m67g_num(float(margins.get("right_pct", 0.0))),
		_m67g_num(float(margins.get("top_pct", 0.0))),
		_m67g_num(float(margins.get("bottom_pct", 0.0)))
	]

func _m67g_write_text(path: String, content: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("M67G could not write " + path)
		return
	f.store_string(content)
	f.close()

func _m67g_stage_name() -> String:
	return report_stage_name

func _m67g_export_timestamp_human() -> String:
	var d = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [int(d.year), int(d.month), int(d.day), int(d.hour), int(d.minute), int(d.second)]

func _m67g_coordinate_system_text() -> String:
	return "Origin at stage center on finished floor. +X stage right, +Y up from floor, +Z upstage."

func _m67g_origin_definition_text() -> String:
	return "All positions are measured from stage center unless noted. Heights are lens-center heights above finished floor."

func _m67g_frame_policy_text() -> String:
	return "Preserve the full camera frame. Do not crop, squeeze, or letterbox."

func _m67g_lens_summary(cam_list: Array) -> String:
	var names: Dictionary = {}
	for c_var in cam_list:
		var c: Dictionary = c_var as Dictionary
		names[str(c.get("lens", "Rokinon 24mm T5.6"))] = true
	var parts: PackedStringArray = PackedStringArray()
	for key in names.keys():
		parts.append(str(key))
	return ", ".join(parts)

func _m67g_support_type_for_camera(c: Dictionary) -> String:
	if installation_mode != "Mixed":
		return installation_mode
	return _m67h_support_bucket(str(c.get("mount", "")))

func _m67g_support_type_for_record(r: Dictionary) -> String:
	return str(r.get("support_type", "Mixed"))

func _m67g_support_color(support_type: String) -> Color:
	match support_type:
		"Truss":
			return Color("275dad")
		"Stands":
			return Color("2f7f4f")
		"Tripods":
			return Color("8c5a2b")
		"Mixed":
			return Color("6c6571")
		_:
			return Color("6c6571")

func _m67g_support_hex(support_type: String) -> String:
	return _m67g_support_color(support_type).to_html(false)

func _m67g_status_hex(status: String) -> String:
	match status:
		"PASS":
			return "2f7f4f"
		"WARNING":
			return "9d6b15"
		"FAIL":
			return "b24a22"
		"INVALID":
			return "b32020"
		_:
			return "6c6571"

func _m67g_dim_label_m_ft(meters: float, places: int = 2) -> String:
	return _m67g_num(meters, places) + " m / " + _m67g_ft(meters)

func _m67g_vec3_label(v: Vector3, places: int = 2) -> String:
	return _m67g_num(v.x, places) + ", " + _m67g_num(v.y, places) + ", " + _m67g_num(v.z, places)

func _m67g_vec3_m_ft_label(v: Vector3) -> String:
	return _m67g_vec3_label(v, 2) + " m (" + _m67g_num(v.x / FT_TO_M, 2) + ", " + _m67g_num(v.y / FT_TO_M, 2) + ", " + _m67g_num(v.z / FT_TO_M, 2) + " ft)"

func _m67g_array_to_vec3(v: Variant) -> Vector3:
	return _m67h_variant_to_vec3(v, Vector3.ZERO)

func _m67g_support_groups(data: Array) -> Dictionary:
	var groups := {"Truss": [], "Stands": [], "Tripods": [], "Mixed": []}
	for r_var in data:
		var r: Dictionary = r_var as Dictionary
		var key = _m67g_support_type_for_record(r)
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(str(r.get("camera_label", r.get("id", ""))))
	return groups

func _m67g_installation_mode_notes() -> Array[String]:
	match installation_mode:
		"Truss":
			return [
				"Confirm clamp locations, trim height, and lens-center height along each truss run before final lockoff.",
				"Use pan and tilt correction first. If framing still fails, shift the pickup point or change lens/support."
			]
		"Stands":
			return [
				"Mark stand floor positions, verify ballast and aisle clearance, and confirm lens-center heights before aiming.",
				"Use pan and tilt correction first. If framing still fails, adjust stand position or head height."
			]
		"Tripods":
			return [
				"Mark tripod footprints, keep clear working space around legs, and lock heads before final verification.",
				"Use pan and tilt correction first. If framing still fails, adjust tripod position or height."
			]
		_:
			return [
				"Confirm each support location, lens-center height, and clearance before final lockoff.",
				"Use the support group notes on each sheet to decide whether to adjust pan/tilt, support height, or support location."
			]

func _m67h_layout_metadata(cam_list: Array = cameras) -> Dictionary:
	var profile = _m67h_array_profile(layout_name)
	var tier_heights := {"low": 0.0, "mid": 0.0, "high": 0.0}
	var tier_radii := {"low": 0.0, "mid": 0.0, "high": 0.0}
	if not cam_list.is_empty():
		var first: Dictionary = cam_list[0] as Dictionary
		if first.has("tier_heights_m"):
			tier_heights = first.get("tier_heights_m", tier_heights)
		if first.has("tier_radius_m"):
			tier_radii = first.get("tier_radius_m", tier_radii)
	return {
		"array_profile_name": str(profile.get("name", layout_name)),
		"array_size": int(profile.get("array_size", cam_list.size())),
		"tier_count": int(profile.get("tier_count", 3)),
		"cameras_per_tier": int(profile.get("cameras_per_tier", max(1, int(cam_list.size() / 3)))),
		"azimuth_spacing_deg": float(profile.get("azimuth_spacing_deg", 360.0 / max(1.0, float(cam_list.size())))),
		"tier_stagger_deg": float(profile.get("tier_stagger_deg", 0.0)),
		"tier_heights_m": tier_heights,
		"tier_radius_m": tier_radii,
		"frame_safe_generation": _m67h_is_frame_safe_profile(layout_name)
	}

func _m67h_layout_level_metrics(cam_list: Array = cameras) -> Dictionary:
	var azimuths: Array[float] = []
	var tiers: Dictionary = {}
	for c_var in cam_list:
		var c: Dictionary = c_var as Dictionary
		azimuths.append(float(c.get("azimuth_deg", 0.0)))
		var tier = str(c.get("tier", "mid"))
		if not tiers.has(tier):
			tiers[tier] = 0
		tiers[tier] = int(tiers[tier]) + 1
	azimuths.sort()
	var max_gap := 0.0
	var min_gap := 360.0
	if azimuths.size() > 1:
		for i in range(azimuths.size()):
			var a = azimuths[i]
			var b = azimuths[(i + 1) % azimuths.size()]
			var gap = fposmod(b - a, 360.0)
			if i == azimuths.size() - 1:
				gap = fposmod(azimuths[0] + 360.0 - a, 360.0)
			if gap <= 0.0:
				continue
			max_gap = max(max_gap, gap)
			min_gap = min(min_gap, gap)
	return {
		"angular_coverage_deg": 360.0 if not cam_list.is_empty() else 0.0,
		"maximum_azimuth_gap_deg": max_gap,
		"minimum_azimuth_gap_deg": 0.0 if min_gap == 360.0 else min_gap,
		"vertical_tier_coverage": tiers,
		"neighbor_baseline_diversity_deg": min_gap,
		"heuristic_only": true
	}

func _m67g_report_payload(report_root: String, data: Array, export_timestamp: String = "") -> Dictionary:
	if export_timestamp == "":
		export_timestamp = _m68a_timestamp()
	var volume = _m67h_capture_volume()
	var subject = _m67h_capture_subject_bounds()
	var effective_performer_height_m = report_performer_height_m
	var effective_performer_height_source = report_performer_height_source
	if report_performer_height_source != "user":
		var subject_size = subject.get("size", Vector3(0.0, ROBOT_HEIGHT_M, 0.0))
		if subject_size is Vector3 and float((subject_size as Vector3).y) > 0.01:
			effective_performer_height_m = float((subject_size as Vector3).y)
			effective_performer_height_source = "subject_bounds"
	var counts = _m67h_qc_counts(cameras)
	var volume_counts = _m67h_volume_qc_counts(cameras)
	var layout_meta = _m67h_layout_metadata(cameras)
	var support_groups = _m67g_support_groups(data)
	var label_warning := _m68a3_camera_label_warning(data.size())
	return {
		"schema_version": "splatviz_frame_safe_array_blueprint_v1",
		"report_root": report_root,
		"app_release_label": SPLATVIZ_RELEASE_LABEL,
		"export_tag": SPLATVIZ_EXPORT_TAG,
		"export_timestamp": export_timestamp,
		"layout_profile": str(layout_meta.get("array_profile_name", layout_name)),
		"render_width": M67G_CONTACT_RENDER_SIZE.x,
		"render_height": M67G_CONTACT_RENDER_SIZE.y,
		"camera_count": data.size(),
		"subject_qc_counts": counts,
		"volume_qc_counts": volume_counts,
		"stage_name": _m67g_stage_name(),
		"capture_specs": report_capture_specs,
		"stage_specs": report_stage_specs,
		"performer_specs": report_performer_specs,
		"floor_type": report_floor_type,
		"report_preview_background": report_preview_background,
		"camera_label_scheme": report_camera_label_scheme,
		"camera_label_warning": label_warning,
		"performer_height_m": effective_performer_height_m,
		"performer_height_source": effective_performer_height_source,
		"height_scale_enabled": report_height_scale_enabled,
		"project_name": SPLATVIZ_RELEASE_LABEL + " Camera Layout Blueprint Package",
		"coordinate_system": _m67g_coordinate_system_text(),
		"origin_definition": _m67g_origin_definition_text(),
		"stage_dimensions_m": [STAGE_W_M, STAGE_D_M],
		"grid_height_m": GRID_H_M,
		"frame_policy": _m67g_frame_policy_text(),
		"contact_render_size": [M67G_CONTACT_RENDER_SIZE.x, M67G_CONTACT_RENDER_SIZE.y],
		"array_profile_name": str(layout_meta.get("array_profile_name", layout_name)),
		"array_size": int(layout_meta.get("array_size", data.size())),
		"tier_count": int(layout_meta.get("tier_count", 3)),
		"cameras_per_tier": int(layout_meta.get("cameras_per_tier", 0)),
		"tier_heights_m": layout_meta.get("tier_heights_m", {}),
		"tier_radius_m": layout_meta.get("tier_radius_m", {}),
		"azimuth_spacing_deg": float(layout_meta.get("azimuth_spacing_deg", 0.0)),
		"tier_stagger_deg": float(layout_meta.get("tier_stagger_deg", 0.0)),
		"frame_safe_generation": bool(layout_meta.get("frame_safe_generation", false)),
		"capture_subject_bounds_m": {
			"center_m": _m67h_vec3_to_array(subject.get("center", TARGET)),
			"size_m": _m67h_vec3_to_array(subject.get("size", Vector3.ZERO)),
			"min_m": _m67h_vec3_to_array(subject.get("min", Vector3.ZERO)),
			"max_m": _m67h_vec3_to_array(subject.get("max", Vector3.ZERO)),
			"padding_m": _m67h_vec3_to_array(subject.get("padding", Vector3.ZERO)),
			"source": str(subject.get("source", "estimated_reference_subject")),
			"estimated": bool(subject.get("estimated", true))
		},
		"capture_volume_bounds_m": {
			"center_m": _m67h_vec3_to_array(volume.get("center", TARGET)),
			"size_m": _m67h_vec3_to_array(volume.get("size", Vector3.ZERO)),
			"min_m": _m67h_vec3_to_array(volume.get("min", Vector3.ZERO)),
			"max_m": _m67h_vec3_to_array(volume.get("max", Vector3.ZERO)),
			"motion_margin_m": _m67h_vec3_to_array(volume.get("motion_margin", Vector3.ZERO)),
			"floor_included": true
		},
		"capture_volume": {
			"center_m": _m67h_vec3_to_array(volume.get("center", TARGET)),
			"size_m": _m67h_vec3_to_array(volume.get("size", Vector3.ZERO)),
			"min_m": _m67h_vec3_to_array(volume.get("min", Vector3.ZERO)),
			"max_m": _m67h_vec3_to_array(volume.get("max", Vector3.ZERO)),
			"motion_margin_m": _m67h_vec3_to_array(volume.get("motion_margin", Vector3.ZERO)),
			"floor_included": true
		},
		"subject_frame_safety": _m67h_subject_frame_safety(),
		"volume_frame_safety": _m67h_volume_frame_safety(),
		"frame_safety": _m67h_subject_frame_safety(),
		"installation_mode": installation_mode,
		"lens_summary": _m67g_lens_summary(data),
		"frame_qc_counts": counts,
		"subject_frame_qc_counts": counts,
		"volume_frame_qc_counts": volume_counts,
		"camera_count_total": data.size(),
		"camera_count_exportable": _m67h_exportable_training_cameras(cameras).size(),
		"layout_metrics": _m67h_layout_level_metrics(cameras),
		"support_groups": support_groups,
		"overview_notes": _m67g_installation_mode_notes(),
		"cameras": data
	}

func _m67g_report_css() -> String:
	return "body{font-family:Helvetica,Arial,sans-serif;background:#eee9df;color:#1f2e3a;margin:0;}main{padding:22px 24px 34px;}a{color:#184f97;text-decoration:none}a:hover{text-decoration:underline}.sheet{max-width:1440px;margin:0 auto;background:#fffdf8;border:1px solid #c8c6bd;box-shadow:0 3px 10px rgba(31,46,58,0.08)}.titlebar{display:flex;justify-content:space-between;gap:18px;padding:20px 24px;border-bottom:2px solid #5f6f7f;background:linear-gradient(180deg,#fbfaf6,#f3eee2)}.titleblock h1{margin:0;font-size:34px;line-height:1.05}.titleblock p{margin:6px 0 0;font-size:15px;color:#425363}.meta-grid{display:grid;grid-template-columns:repeat(2,minmax(170px,1fr));gap:5px 16px;font-size:13px;align-content:start}.nav{display:flex;flex-wrap:wrap;gap:14px;padding:12px 24px;border-bottom:1px solid #d8d4c8;background:#f8f5ed;font-size:13px}.content{padding:24px}.lede{font-size:16px;line-height:1.55;margin:0 0 18px}.grid-two{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px;align-items:start}.grid-three{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}.index-grid{display:grid;grid-template-columns:1.2fr 0.8fr;gap:18px}.card{border:1px solid #d5d1c5;background:#fffefb;padding:16px}.card h2,.card h3{margin:0 0 10px}.card p{margin:0 0 8px;line-height:1.5}.kv{display:grid;grid-template-columns:minmax(170px,230px) 1fr;gap:7px 12px;font-size:13px}.kv div{padding:3px 0;border-bottom:1px solid #eee8dd}.kv .key{font-weight:700}.note-list{margin:0;padding-left:18px;line-height:1.5}.svg-frame{border:1px solid #d5d1c5;background:#fff;padding:10px}.drawing-frame{padding:12px;background:#fffdfa}.drawing-frame img{width:100%;height:auto;display:block}.drawing-stack{display:grid;gap:18px}.table{width:100%;border-collapse:collapse;font-size:13px}.table th,.table td{border:1px solid #d8d4c8;padding:7px 9px;text-align:left;vertical-align:top}.table th{background:#f2eee4}.small{font-size:12px;color:#566474}.hero-specs{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;margin-bottom:18px}.hero-spec{border:1px solid #d8d4c8;background:#faf6eb;padding:14px}.hero-spec b{display:block;font-size:12px;letter-spacing:0.04em;text-transform:uppercase;color:#5b6c5c}.hero-spec span{display:block;margin-top:6px;font-size:21px;line-height:1.25}.schedule-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}.camera-card{border:1px solid #d6d0c1;background:#fff;padding:12px;break-inside:avoid;page-break-inside:avoid}.camera-card img{width:100%;aspect-ratio:16/9;object-fit:contain;background:#f4f0e8;border:1px solid #ddd6c7}.placeholder{width:100%;aspect-ratio:16/9;display:flex;align-items:center;justify-content:center;background:#f7f3ea;border:1px solid #ddd6c7;color:#6b5845;font-weight:700;text-align:center;padding:12px;box-sizing:border-box}.camera-title{display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin:10px 0}.camera-title h3{margin:0;font-size:20px}.camera-subtitle{font-size:12px;color:#5d6a76;margin-top:4px}.tag{display:inline-block;padding:3px 8px;border-radius:999px;font-size:12px;font-weight:700;background:#ecf2fb;color:#2a4b7c}.footnote{font-size:12px;line-height:1.5;color:#44505c;margin-top:14px}.crossref{font-size:12px;color:#5b6672}.legend-row{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}.legend-item{display:flex;align-items:center;gap:10px;padding:10px 12px;border:1px solid #ddd6c7;background:#fffdfa}.legend-item svg{flex:none}.warning{color:#9b5d14;font-weight:700}.print-break{page-break-before:always}@media print{@page{size:landscape;margin:11mm}body{background:#fff}main{padding:0}.sheet{border:none;box-shadow:none;max-width:none}.nav{display:none}.content{padding:12mm}.index-grid,.grid-two,.grid-three,.hero-specs{grid-template-columns:repeat(2,minmax(0,1fr))}.schedule-grid{grid-template-columns:repeat(2,minmax(0,1fr))}.camera-card,.card,.svg-frame{break-inside:avoid;page-break-inside:avoid}}"

func _m67g_sheet_shell(payload: Dictionary, title: String, subtitle: String, body: String) -> String:
	var nav = [
		["Build Summary", "sheet_01_overview.html"],
		["Top Plan", "sheet_02_top_plan.html"],
		["Front Elevation", "sheet_03_front_elevation.html"],
		["Side Elevation", "sheet_04_side_elevation.html"],
		["Camera Schedule", "sheet_05_camera_schedule.html"]
	]
	var nav_html = ""
	for item in nav:
		nav_html += "<a href='" + str(item[1]) + "'>" + _m67g_html_escape(str(item[0])) + "</a>"
	var meta_html = "<div><b>Project:</b> " + _m67g_html_escape(str(payload.get("project_name", ""))) + "</div>"
	meta_html += "<div><b>Stage:</b> " + _m67g_html_escape(str(payload.get("stage_name", ""))) + "</div>"
	meta_html += "<div><b>Export:</b> " + _m67g_html_escape(str(payload.get("export_timestamp", ""))) + "</div>"
	meta_html += "<div><b>Mode:</b> " + _m67g_html_escape(str(payload.get("installation_mode", ""))) + "</div>"
	meta_html += "<div><b>Camera Count:</b> " + str(int(payload.get("camera_count_total", 0))) + "</div>"
	meta_html += "<div><b>Sheet:</b> " + _m67g_html_escape(title) + "</div>"
	return "<!doctype html><html><head><meta charset='utf-8'><title>" + _m67g_html_escape(title) + " - SplatViz Rigging Packet</title><link rel='stylesheet' href='assets/report.css'></head><body><main><div class='sheet'><div class='titlebar'><div class='titleblock'><h1>" + _m67g_html_escape(title) + "</h1><p>" + _m67g_html_escape(subtitle) + "</p></div><div class='meta-grid'>" + meta_html + "</div></div><div class='nav'><a href='index.html'>Index</a>" + nav_html + "</div><div class='content'>" + body + "</div></div></main></body></html>"

func _m67g_build_index_html(payload: Dictionary) -> String:
	var body = "<p class='lede'>This packet is formatted for rigging, camera prep, and stage layout. Use Sheet 01 for production assumptions, then mark the stage from the plan and elevations before final camera lockoff.</p>"
	body += "<div class='hero-specs'>"
	body += "<div class='hero-spec'><b>Capture Specs</b><span>" + _m67g_html_escape(str(payload.get("capture_specs", ""))) + "</span></div>"
	body += "<div class='hero-spec'><b>Stage Specs</b><span>" + _m67g_html_escape(str(payload.get("stage_specs", ""))) + "</span></div>"
	body += "<div class='hero-spec'><b>Performer Specs</b><span>" + _m67g_html_escape(str(payload.get("performer_specs", ""))) + "</span></div>"
	body += "<div class='hero-spec'><b>Drawing Package Contents</b><span>Build summary, plan, elevations, schedule, CSV, JSON</span></div></div>"
	body += "<div class='index-grid'><div class='card'><h2>Build Summary</h2><div class='kv'>"
	body += "<div class='key'>Camera Array</div><div>" + _m67g_html_escape(str(payload.get("array_profile_name", ""))) + " · " + str(int(payload.get("camera_count_total", 0))) + " cameras</div>"
	body += "<div class='key'>Lens Package</div><div>" + _m67g_html_escape(str(payload.get("lens_summary", ""))) + "</div>"
	body += "<div class='key'>Build Mode</div><div>" + _m67g_html_escape(str(payload.get("installation_mode", ""))) + "</div>"
	body += "<div class='key'>Stage Datum / Origin</div><div>" + _m67g_html_escape(str(payload.get("origin_definition", ""))) + "</div>"
	body += "<div class='key'>Stage Name</div><div>" + _m67g_html_escape(str(payload.get("stage_name", ""))) + "</div>"
	body += "<div class='key'>Floor / Surface</div><div>" + _m67g_html_escape(str(payload.get("floor_type", ""))) + "</div>"
	body += "<div class='key'>Performer Height</div><div>" + _m67g_html_escape(_m67g_dim_label_m_ft(float(payload.get("performer_height_m", report_performer_height_m)), 2)) + "</div>"
	body += "<div class='key'>Camera Label Scheme</div><div>" + _m67g_html_escape(str(payload.get("camera_label_scheme", ""))) + "</div>"
	body += "</div></div>"
	body += "<div class='card'><h2>Sheet Set</h2><table class='table'><tr><th>Sheet</th><th>Use</th></tr>"
	body += "<tr><td><a href='sheet_01_overview.html'>Sheet 01: Build Summary</a></td><td>Production specs, datum, stage dimensions, label scheme, and install notes.</td></tr>"
	body += "<tr><td><a href='sheet_02_top_plan.html'>Sheet 02: Top Plan</a></td><td>Camera floor positions, stage boundary, support zones, and subject footprint.</td></tr>"
	body += "<tr><td><a href='sheet_03_front_elevation.html'>Sheet 03: Front Elevation</a></td><td>Lens-center heights, tier references, and performer height scale.</td></tr>"
	body += "<tr><td><a href='sheet_04_side_elevation.html'>Sheet 04: Side Elevation</a></td><td>Depth, clean aim lines, and performer height scale.</td></tr>"
	body += "<tr><td><a href='sheet_05_camera_schedule.html'>Sheet 05: Camera Schedule</a></td><td>Field-use camera cards with labels, position, support, and install notes.</td></tr></table></div></div>"
	body += "<div class='card'><h2>Technical Cross-Reference</h2><table class='table'><tr><th>File</th><th>Use</th></tr>"
	body += "<tr><td><a href='camera_mounting_schedule.csv'>camera_mounting_schedule.csv</a></td><td>Field schedule with production camera labels and technical cross-reference columns.</td></tr>"
	body += "<tr><td><a href='camera_layout.json'>camera_layout.json</a></td><td>Structured export that preserves internal IDs, QC, and provenance metadata.</td></tr>"
	body += "<tr><td><a href='top_plan.svg'>top_plan.svg</a></td><td>Large top-plan drawing asset.</td></tr>"
	body += "<tr><td><a href='front_elevation.svg'>front_elevation.svg</a></td><td>Large front-elevation drawing asset.</td></tr>"
	body += "<tr><td><a href='side_elevation.svg'>side_elevation.svg</a></td><td>Large side-elevation drawing asset.</td></tr>"
	body += "<tr><td><a href='support_legend.svg'>support_legend.svg</a></td><td>Rigging/build symbol legend.</td></tr></table></div>"
	return _m67g_sheet_shell(payload, "Drawing Package Index", "Rigging / build summary and file map", body)

func _layout_report_default_root() -> String:
	if export_root_path != "" and not _layout_report_path_is_in_project(export_root_path):
		return export_root_path
	return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)

func _layout_report_normalize_path(path: String) -> String:
	return path.replace("\\", "/").rstrip("/")

func _layout_report_path_is_in_project(path: String) -> bool:
	var normalized_path = _layout_report_normalize_path(path)
	var project_root = _layout_report_normalize_path(ProjectSettings.globalize_path("res://"))
	return normalized_path == project_root or normalized_path.begins_with(project_root + "/")

func _layout_report_expected_contact_paths(contact_dir: String) -> Array:
	var expected: Array = []
	for c in cameras:
		if _m67h_camera_exports_contact_frame(c):
			expected.append(contact_dir.path_join(_camera_unique_filename(c)))
	return expected

func _layout_report_expected_diagnostic_paths(diagnostic_dir: String) -> Array:
	var expected: Array = []
	for c in cameras:
		if _m67h_camera_requires_diagnostic_thumbnail(c):
			expected.append(diagnostic_dir.path_join(_camera_unique_filename(c)))
	return expected

func _layout_report_sheet_paths(report_root: String) -> Array:
	return [
		report_root.path_join("index.html"),
		report_root.path_join("sheet_01_overview.html"),
		report_root.path_join("sheet_02_top_plan.html"),
		report_root.path_join("sheet_03_front_elevation.html"),
		report_root.path_join("sheet_04_side_elevation.html"),
		report_root.path_join("sheet_05_camera_schedule.html")
	]

func _layout_report_required_paths(report_root: String) -> Array:
	var required: Array = _layout_report_sheet_paths(report_root)
	required.append_array([
		report_root.path_join("top_plan.svg"),
		report_root.path_join("front_elevation.svg"),
		report_root.path_join("side_elevation.svg"),
		report_root.path_join("support_legend.svg"),
		report_root.path_join("assets/report.css"),
		report_root.path_join("camera_mounting_schedule.csv"),
		report_root.path_join("camera_layout.json")
	])
	required.append_array(_layout_report_expected_contact_paths(report_root.path_join("camera_contact_renders")))
	required.append_array(_layout_report_expected_diagnostic_paths(report_root.path_join("camera_qc_diagnostics")))
	return required

func _layout_report_missing_paths(paths: Array) -> Array:
	var missing: Array = []
	for path_var in paths:
		var path = str(path_var)
		if not FileAccess.file_exists(path):
			missing.append(path)
	return missing

func _layout_report_wait_for_paths(paths: Array, max_seconds: float) -> bool:
	var waited := 0.0
	while waited < max_seconds:
		if _layout_report_missing_paths(paths).is_empty():
			return true
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	return _layout_report_missing_paths(paths).is_empty()

func _layout_report_verify_index_html(html_path: String) -> bool:
	if not FileAccess.file_exists(html_path):
		return false
	var html = FileAccess.get_file_as_string(html_path)
	return html.find("%s") == -1 \
		and html.find("sheet_01_overview.html") >= 0 \
		and html.find("sheet_02_top_plan.html") >= 0 \
		and html.find("sheet_03_front_elevation.html") >= 0 \
		and html.find("sheet_04_side_elevation.html") >= 0 \
		and html.find("sheet_05_camera_schedule.html") >= 0

func _layout_report_fail(message: String) -> void:
	push_warning(message)
	if status_label != null:
		status_label.text = message

func _m67g_init_layout_report_mode_dialog() -> void:
	if layout_report_mode_dialog_m67g != null:
		return
	layout_report_mode_dialog_m67g = ConfirmationDialog.new()
	layout_report_mode_dialog_m67g.title = "Layout Report Settings"
	layout_report_mode_dialog_m67g.ok_button_text = "Continue"
	layout_report_mode_dialog_m67g.cancel_button_text = "Cancel"
	var vb = VBoxContainer.new()
	vb.custom_minimum_size = Vector2(420, 0)
	vb.add_theme_constant_override("separation", 10)
	layout_report_mode_dialog_m67g.add_child(vb)
	var desc = Label.new()
	desc.text = "Choose the installation mode used for report language and support notes. This does not change camera positions."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc)
	layout_report_mode_option_m67g = OptionButton.new()
	for mode_name in ["Truss", "Stands", "Tripods", "Mixed"]:
		layout_report_mode_option_m67g.add_item(mode_name)
	vb.add_child(layout_report_mode_option_m67g)
	add_child(layout_report_mode_dialog_m67g)
	layout_report_mode_dialog_m67g.confirmed.connect(func():
		installation_mode = layout_report_mode_option_m67g.get_item_text(layout_report_mode_option_m67g.selected)
		_m67g_open_layout_report_folder_dialog()
	)

func _m67g_open_layout_report_folder_dialog() -> void:
	if layout_report_dialog_m67c == null:
		_m67c_init_layout_report_dialog()
	layout_report_dialog_m67c.current_dir = _layout_report_default_root()
	layout_report_dialog_m67c.use_native_dialog = true
	layout_report_dialog_m67c.popup_centered(Vector2i(900, 650))

func _prompt_external_layout_report() -> void:
	_m67g_init_layout_report_mode_dialog()
	var target_mode = installation_mode
	if target_mode == "":
		target_mode = _m67h_installation_mode()
	for i in range(layout_report_mode_option_m67g.get_item_count()):
		if layout_report_mode_option_m67g.get_item_text(i) == target_mode:
			layout_report_mode_option_m67g.select(i)
			break
	layout_report_mode_dialog_m67g.popup_centered(Vector2i(460, 180))

func _export_layout_report_to_dir(base_dir: String) -> void:
	var chosen_dir = base_dir.strip_edges()
	if chosen_dir == "":
		return
	if _layout_report_path_is_in_project(chosen_dir):
		_layout_report_fail("Choose an external destination folder outside the Godot project.")
		return
	_m67h_refresh_all_camera_layout_fields()
	var export_timestamp := _m68a_timestamp()
	var report_root = chosen_dir.path_join(_m68a_layout_report_folder_name(export_timestamp))
	var contact_dir = report_root.path_join("camera_contact_renders")
	var diagnostic_dir = report_root.path_join("camera_qc_diagnostics")
	var expected_contact_paths = _layout_report_expected_contact_paths(contact_dir)
	var expected_diagnostic_paths = _layout_report_expected_diagnostic_paths(diagnostic_dir)
	var expected_render_paths: Array = expected_contact_paths.duplicate()
	expected_render_paths.append_array(expected_diagnostic_paths)
	m67f_last_layout_report_folder = report_root
	DirAccess.make_dir_recursive_absolute(contact_dir)
	DirAccess.make_dir_recursive_absolute(diagnostic_dir)
	if status_label != null:
		status_label.text = "Rendering layout report thumbnails..."
	await _m67g_render_contact_images_blocking(contact_dir, diagnostic_dir)
	if not await _layout_report_wait_for_paths(expected_render_paths, 5.0):
		_layout_report_fail("Layout report export stopped: one or more camera thumbnails were not written.")
		return
	var data = _m67g_camera_report_data(contact_dir, diagnostic_dir)
	var payload = _m67g_report_payload(report_root, data, export_timestamp)
	_m67g_write_report_files(report_root, payload)
	var required_paths = _layout_report_required_paths(report_root)
	if not _layout_report_missing_paths(required_paths).is_empty():
		_layout_report_fail("Layout report export stopped: required report files are missing.")
		return
	var html_path = report_root.path_join("index.html")
	if not _layout_report_verify_index_html(html_path):
		_layout_report_fail("Layout report export stopped: index.html failed validation.")
		return
	if status_label != null:
		status_label.text = "Layout report written: " + html_path
	OS.shell_open(html_path)

func _m67g_prompt_external_layout_report() -> void:
	_prompt_external_layout_report()

func _m67g_export_layout_report_to_dir(base_dir: String) -> void:
	await _export_layout_report_to_dir(base_dir)

func _m67g_render_contact_images_blocking(contact_dir: String, diagnostic_dir: String) -> void:
	# Important: render sequentially and wait for each PNG to land before the report is assembled.
	for i in range(cameras.size()):
		var c: Dictionary = _m67h_refresh_camera_layout_fields(cameras[i])
		cameras[i] = c
		var img_path = contact_dir.path_join(_camera_unique_filename(c))
		if _m67h_camera_requires_diagnostic_thumbnail(c):
			img_path = diagnostic_dir.path_join(_camera_unique_filename(c))
		await _render_camera_to_path(c, img_path, M67G_CONTACT_RENDER_SIZE, true)
		await _layout_report_wait_for_paths([img_path], 2.0)
		await get_tree().process_frame

func _m67g_camera_report_data(contact_dir: String, diagnostic_dir: String) -> Array:
	var out: Array = []
	var volume = _m67h_capture_volume()
	var subject = _m67h_capture_subject_bounds()
	for i in range(cameras.size()):
		var c: Dictionary = _m67h_refresh_camera_layout_fields(cameras[i])
		cameras[i] = c
		var id = str(c.get("id", "C%02d" % (i + 1)))
		var image_name = _camera_unique_filename_from_id(id)
		var cam_name = image_name.trim_suffix("_frame_000001.png")
		var image_path = contact_dir.path_join(image_name)
		var image_rel = "camera_contact_renders/" + image_name
		var image_type = "contact"
		if _m67h_camera_requires_diagnostic_thumbnail(c):
			image_path = diagnostic_dir.path_join(image_name)
			image_rel = "camera_qc_diagnostics/" + image_name
			image_type = "diagnostic"
		var pos: Vector3 = c.get("position", Vector3.ZERO)
		var focus_target = _m67h_camera_focus_target(c)
		var aim_target = _m67h_camera_aim_target(c)
		var focus_d = pos.distance_to(focus_target)
		var floor_d = Vector2(pos.x, pos.z).length()
		var radius_m = floor_d
		var target_delta = aim_target - pos
		var tilt = rad_to_deg(atan2(target_delta.y, max(Vector2(target_delta.x, target_delta.z).length(), 0.001)))
		var intr = _m66d_capture_intrinsics(c, CLEAN_RENDER_SIZE)
		var support_type = _m67g_support_type_for_camera(c)
		var roll_deg = _m66d_capture_roll_deg(c)
		var camera_label = _m68a3_camera_label_for(i, id)
		var rec = {
			"id": id,
			"internal_camera_id": id,
			"camera_label": camera_label,
			"cam_name": cam_name,
			"array_profile_name": str(c.get("array_profile_name", layout_name)),
			"array_size": int(c.get("array_size", cameras.size())),
			"tier": str(c.get("tier", "")),
			"mount": str(c.get("mount", "")),
			"support_type": support_type,
			"support_id_or_zone": str(c.get("mount", "")),
			"image": image_rel,
			"image_exists": FileAccess.file_exists(image_path),
			"image_type": image_type,
			"subject_frame_qc_status": str(c.get("subject_frame_qc_status", c.get("frame_qc_status", "UNKNOWN"))),
			"subject_frame_qc_reason": str(c.get("subject_frame_qc_reason", c.get("frame_qc_reason", ""))),
			"subject_frame_qc_recommendation": str(c.get("subject_frame_qc_recommendation", c.get("frame_qc_recommendation", ""))),
			"subject_frame_qc_margins_pct": c.get("subject_frame_qc_margins_pct", c.get("frame_qc_margins", {})),
			"subject_frame_coverage_pct": float(c.get("subject_frame_coverage_pct", c.get("frame_qc_projected_coverage_pct", 0.0))),
			"volume_frame_qc_status": str(c.get("volume_frame_qc_status", "OUTSIDE")),
			"volume_frame_qc_margins_pct": c.get("volume_frame_qc_margins_pct", {}),
			"volume_frame_coverage_pct": float(c.get("volume_frame_coverage_pct", 0.0)),
			"frame_qc_status": str(c.get("frame_qc_status", "UNKNOWN")),
			"frame_qc_reason": str(c.get("frame_qc_reason", "")),
			"frame_qc_recommendation": str(c.get("frame_qc_recommendation", "")),
			"frame_qc_margins": c.get("frame_qc_margins", {}),
			"frame_qc_projected_coverage_pct": float(c.get("frame_qc_projected_coverage_pct", 0.0)),
			"export_policy": _m67h_export_policy(c),
			"lens": "Rokinon 24mm T5.6",
			"resolution": str(M67G_CONTACT_RENDER_SIZE.x) + "×" + str(M67G_CONTACT_RENDER_SIZE.y),
			"frame_policy": _m67g_frame_policy_text(),
			"position_m": [pos.x, pos.y, pos.z],
			"position_ft": [pos.x / FT_TO_M, pos.y / FT_TO_M, pos.z / FT_TO_M],
			"height_m": pos.y,
			"height_ft": pos.y / FT_TO_M,
			"distance_3d_m": focus_d,
			"distance_3d_ft": focus_d / FT_TO_M,
			"floor_distance_m": floor_d,
			"floor_distance_ft": floor_d / FT_TO_M,
			"radius_m": radius_m,
			"radius_ft": radius_m / FT_TO_M,
			"azimuth_deg": float(c.get("azimuth_deg", 0.0)),
			"pan_deg": float(c.get("azimuth_deg", 0.0)),
			"tilt_deg": tilt,
			"roll_deg": roll_deg,
			"hfov_deg": float(intr.get("hfov", 0.0)),
			"vfov_deg": float(intr.get("vfov", 0.0)),
			"portrait": bool(c.get("portrait", false)),
			"aim_target_m": _m67h_vec3_to_array(aim_target),
			"focus_target_m": _m67h_vec3_to_array(focus_target),
			"capture_subject_bounds_m": c.get("capture_subject_bounds_m", {
				"center_m": _m67h_vec3_to_array(subject.get("center", TARGET)),
				"size_m": _m67h_vec3_to_array(subject.get("size", Vector3.ZERO))
			}),
			"capture_volume_center_m": _m67h_vec3_to_array(volume.get("center", TARGET)),
			"capture_volume_bounds_m": c.get("capture_volume_bounds_m", {
				"center_m": _m67h_vec3_to_array(volume.get("center", TARGET)),
				"size_m": _m67h_vec3_to_array(volume.get("size", Vector3.ZERO))
			}),
			"layout_metrics": c.get("layout_metrics", {}),
			"install_note": str(c.get("subject_frame_qc_recommendation", c.get("frame_qc_recommendation", ""))),
			"notes": "Use the listed aim target and preserve the full frame during verification."
		}
		out.append(rec)
	return out

func _m67g_write_report_files(report_root: String, payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(report_root)
	DirAccess.make_dir_recursive_absolute(report_root.path_join("assets"))
	_m67g_write_text(report_root.path_join("assets/report.css"), _m67g_report_css())
	_m67g_write_text(report_root.path_join("top_plan.svg"), _m67g_build_top_plan_svg(payload))
	_m67g_write_text(report_root.path_join("front_elevation.svg"), _m67g_build_front_elevation_svg(payload))
	_m67g_write_text(report_root.path_join("side_elevation.svg"), _m67g_build_side_elevation_svg(payload))
	_m67g_write_text(report_root.path_join("support_legend.svg"), _m67g_build_support_legend_svg(payload))
	_m67g_write_report_csv_json(report_root, payload)
	_m67g_write_text(report_root.path_join("index.html"), _m67g_build_index_html(payload))
	_m67g_write_text(report_root.path_join("sheet_01_overview.html"), _m67g_build_overview_html(payload))
	_m67g_write_text(report_root.path_join("sheet_02_top_plan.html"), _m67g_build_top_plan_html(payload))
	_m67g_write_text(report_root.path_join("sheet_03_front_elevation.html"), _m67g_build_front_elevation_html(payload))
	_m67g_write_text(report_root.path_join("sheet_04_side_elevation.html"), _m67g_build_side_elevation_html(payload))
	_m67g_write_text(report_root.path_join("sheet_05_camera_schedule.html"), _m67g_build_schedule_html(payload))

func _m67g_write_report_csv_json(report_root: String, payload: Dictionary) -> void:
	var data: Array = payload.get("cameras", [])
	var csv = "camera_label,internal_camera_id,support_type,support_id_or_zone,lens_center_height_m,lens_center_height_ft,stage_position_m,stage_position_ft,pan_deg,tilt_deg,roll_deg,focus_distance_m,focus_distance_ft,aim_reference,installer_note,qc_status,volume_qc_status,margin_left_pct,margin_right_pct,margin_top_pct,margin_bottom_pct,volume_margin_left_pct,volume_margin_right_pct,volume_margin_top_pct,volume_margin_bottom_pct\n"
	for r_var in data:
		var r: Dictionary = r_var as Dictionary
		var p = r["position_m"]
		var pft = r["position_ft"]
		var margins: Dictionary = r.get("subject_frame_qc_margins_pct", r.get("frame_qc_margins", {}))
		var volume_margins: Dictionary = r.get("volume_frame_qc_margins_pct", {})
		var aim_target = _m67g_array_to_vec3(r.get("aim_target_m", Vector3.ZERO))
		csv += _m67g_csv_text(str(r.get("camera_label", r["id"]))) + "," + _m67g_csv_text(str(r.get("internal_camera_id", r["id"]))) + ","
		csv += _m67g_csv_text(str(r.get("support_type", ""))) + "," + _m67g_csv_text(str(r.get("support_id_or_zone", ""))) + ","
		csv += _m67g_num(float(r["height_m"])) + "," + _m67g_num(float(r["height_ft"])) + ","
		csv += _m67g_csv_text(_m67g_vec3_label(_m67g_array_to_vec3(p), 2)) + "," + _m67g_csv_text(_m67g_vec3_label(_m67g_array_to_vec3(pft), 2)) + ","
		csv += _m67g_num(float(r["pan_deg"])) + "," + _m67g_num(float(r["tilt_deg"])) + "," + _m67g_num(float(r.get("roll_deg", 0.0))) + ","
		csv += _m67g_num(float(r["distance_3d_m"])) + "," + _m67g_num(float(r["distance_3d_ft"])) + ","
		csv += _m67g_csv_text(_m67g_vec3_label(aim_target, 2)) + "," + _m67g_csv_text(str(r.get("install_note", ""))) + ","
		csv += _m67g_csv_text(str(r.get("subject_frame_qc_status", r.get("frame_qc_status", "")))) + "," + _m67g_csv_text(str(r.get("volume_frame_qc_status", ""))) + ","
		csv += _m67g_num(float(margins.get("left_pct", 0.0))) + "," + _m67g_num(float(margins.get("right_pct", 0.0))) + ","
		csv += _m67g_num(float(margins.get("top_pct", 0.0))) + "," + _m67g_num(float(margins.get("bottom_pct", 0.0))) + ","
		csv += _m67g_num(float(volume_margins.get("left_pct", 0.0))) + "," + _m67g_num(float(volume_margins.get("right_pct", 0.0))) + ","
		csv += _m67g_num(float(volume_margins.get("top_pct", 0.0))) + "," + _m67g_num(float(volume_margins.get("bottom_pct", 0.0))) + "\n"
	_m67g_write_text(report_root.path_join("camera_mounting_schedule.csv"), csv)
	_m67g_write_text(report_root.path_join("camera_layout.json"), JSON.stringify(payload, "  "))
func _m67g_build_top_plan_svg(payload: Dictionary) -> String:
	var data: Array = payload.get("cameras", [])
	var volume: Dictionary = payload.get("capture_volume_bounds_m", payload.get("capture_volume", {}))
	var subject: Dictionary = payload.get("capture_subject_bounds_m", {})
	var w = 1860.0
	var h = 1240.0
	var scale = 74.0
	var cx = w * 0.5
	var cy = h * 0.53
	var svg = "<svg xmlns='http://www.w3.org/2000/svg' width='1860' height='1240' viewBox='0 0 1860 1240'>"
	svg += "<rect width='1860' height='1240' fill='#f8f2e6'/>"
	svg += "<defs><pattern id='plan_grid' width='74' height='74' patternUnits='userSpaceOnUse'><path d='M74 0H0V74' fill='none' stroke='#d6d2c9' stroke-width='1.2'/></pattern></defs>"
	svg += "<rect width='1860' height='1240' fill='url(#plan_grid)'/>"
	var stage_w = STAGE_W_M * scale
	var stage_d = STAGE_D_M * scale
	var stage_x = cx - stage_w * 0.5
	var stage_y = cy - stage_d * 0.5
	var volume_size = _m67g_array_to_vec3(volume.get("size_m", Vector3.ZERO))
	var volume_center = _m67g_array_to_vec3(volume.get("center_m", Vector3.ZERO))
	var subject_size = _m67g_array_to_vec3(subject.get("size_m", Vector3.ZERO))
	var subject_center = _m67g_array_to_vec3(subject.get("center_m", Vector3.ZERO))
	var vol_x = cx + (volume_center.x - volume_size.x * 0.5) * scale
	var vol_y = cy - (volume_center.z + volume_size.z * 0.5) * scale
	var sub_x = cx + (subject_center.x - subject_size.x * 0.5) * scale
	var sub_y = cy - (subject_center.z + subject_size.z * 0.5) * scale
	svg += "<rect x='" + str(stage_x) + "' y='" + str(stage_y) + "' width='" + str(stage_w) + "' height='" + str(stage_d) + "' fill='#f6e4c1' stroke='#7c6444' stroke-width='5'/>"
	svg += "<line x1='" + str(stage_x) + "' y1='" + str(stage_y + stage_d * 0.15) + "' x2='" + str(stage_x + stage_w) + "' y2='" + str(stage_y + stage_d * 0.15) + "' stroke='#d6b888' stroke-width='3' opacity='0.65'/>"
	svg += "<line x1='" + str(stage_x) + "' y1='" + str(stage_y + stage_d * 0.50) + "' x2='" + str(stage_x + stage_w) + "' y2='" + str(stage_y + stage_d * 0.50) + "' stroke='#d6b888' stroke-width='3' opacity='0.65'/>"
	svg += "<line x1='" + str(stage_x) + "' y1='" + str(stage_y + stage_d * 0.84) + "' x2='" + str(stage_x + stage_w) + "' y2='" + str(stage_y + stage_d * 0.84) + "' stroke='#d6b888' stroke-width='3' opacity='0.65'/>"
	svg += "<line x1='" + str(cx) + "' y1='" + str(stage_y) + "' x2='" + str(cx) + "' y2='" + str(stage_y + stage_d) + "' stroke='#6f89a8' stroke-width='2' stroke-dasharray='10 8'/>"
	svg += "<line x1='" + str(stage_x) + "' y1='" + str(cy) + "' x2='" + str(stage_x + stage_w) + "' y2='" + str(cy) + "' stroke='#6f89a8' stroke-width='2' stroke-dasharray='10 8'/>"
	svg += "<rect x='" + str(vol_x) + "' y='" + str(vol_y) + "' width='" + str(volume_size.x * scale) + "' height='" + str(volume_size.z * scale) + "' fill='rgba(110,160,215,0.12)' stroke='#356fb4' stroke-width='4'/>"
	svg += "<rect x='" + str(sub_x) + "' y='" + str(sub_y) + "' width='" + str(subject_size.x * scale) + "' height='" + str(subject_size.z * scale) + "' fill='rgba(212,128,99,0.18)' stroke='#b66b4d' stroke-width='4'/>"
	svg += "<circle cx='" + str(cx) + "' cy='" + str(cy) + "' r='8' fill='#204565'/><text x='" + str(cx + 18) + "' y='" + str(cy - 12) + "' font-size='22' font-weight='700' fill='#204565'>Stage datum / origin</text>"
	svg += "<text x='80' y='82' font-size='40' font-weight='700' fill='#17345e'>Top Plan</text>"
	svg += "<text x='80' y='122' font-size='20' fill='#425363'>Production camera labels, stage footprint, support zones, and subject reference.</text>"
	svg += "<text x='80' y='1140' font-size='20' fill='#425363'>Preview background: " + _m67g_html_escape(str(payload.get("report_preview_background", ""))) + "</text>"
	for r_var in data:
		var r: Dictionary = r_var as Dictionary
		var p = r["position_m"]
		var x = cx + float(p[0]) * scale
		var y = cy - float(p[2]) * scale
		svg += "<line x1='" + str(x) + "' y1='" + str(y) + "' x2='" + str(cx) + "' y2='" + str(cy) + "' stroke='#9db2d3' stroke-width='1.4' stroke-dasharray='7 7'/>"
		svg += _m67g_svg_support_marker(x, y, str(r.get("support_type", "Mixed")), "PASS", true)
		svg += "<text x='" + str(x + 18) + "' y='" + str(y - 14) + "' font-size='20' font-weight='700' fill='#17345e'>" + _m67g_html_escape(str(r.get("camera_label", r["id"]))) + "</text>"
		svg += "<text x='" + str(x + 18) + "' y='" + str(y + 12) + "' font-size='13' fill='#4a5f7c'>" + _m67g_html_escape(str(r.get("internal_camera_id", r["id"]))) + " · " + _m67g_num(float(r.get("azimuth_deg", 0.0)), 0) + "°</text>"
	svg += _m67g_svg_dim_line(stage_x, stage_y + stage_d + 92.0, stage_x + stage_w, stage_y + stage_d + 92.0, "Stage width " + _m67g_dim_label_m_ft(STAGE_W_M, 2), false)
	svg += _m67g_svg_dim_line(stage_x - 84.0, stage_y, stage_x - 84.0, stage_y + stage_d, "Stage depth " + _m67g_dim_label_m_ft(STAGE_D_M, 2), true)
	svg += _m67g_svg_dim_line(sub_x, sub_y + subject_size.z * scale + 34.0, sub_x + subject_size.x * scale, sub_y + subject_size.z * scale + 34.0, "Performer width " + _m67g_dim_label_m_ft(subject_size.x, 2), false)
	svg += _m67g_svg_dim_line(vol_x - 40.0, vol_y, vol_x - 40.0, vol_y + volume_size.z * scale, "Capture depth " + _m67g_dim_label_m_ft(volume_size.z, 2), true)
	svg += _m67g_svg_scale_bar(1390.0, 1120.0, 2.0, scale)
	svg += "</svg>"
	return svg

func _m67g_build_front_elevation_svg(payload: Dictionary) -> String:
	var data: Array = payload.get("cameras", [])
	var volume: Dictionary = payload.get("capture_volume_bounds_m", payload.get("capture_volume", {}))
	var subject: Dictionary = payload.get("capture_subject_bounds_m", {})
	var w = 1860.0
	var h = 1180.0
	var scale_x = 84.0
	var scale_y = 270.0
	var base = 1010.0
	var cx = w * 0.5
	var performer_height_m = float(payload.get("performer_height_m", report_performer_height_m))
	var svg = "<svg xmlns='http://www.w3.org/2000/svg' width='1860' height='1180' viewBox='0 0 1860 1180'>"
	svg += "<rect width='1860' height='1180' fill='#f8f2e6'/>"
	svg += "<defs><pattern id='front_grid' width='84' height='84' patternUnits='userSpaceOnUse'><path d='M84 0H0V84' fill='none' stroke='#d6d2c9' stroke-width='1.1'/></pattern></defs>"
	svg += "<rect width='1860' height='1180' fill='url(#front_grid)'/>"
	svg += "<rect x='120' y='" + str(base) + "' width='1620' height='80' fill='#ccb28e' opacity='0.85'/>"
	svg += "<text x='80' y='82' font-size='40' font-weight='700' fill='#17345e'>Front Elevation</text>"
	svg += "<text x='80' y='122' font-size='20' fill='#425363'>Lens-center heights, tier references, performer scale, and floor line.</text>"
	svg += "<line x1='120' y1='" + str(base) + "' x2='1740' y2='" + str(base) + "' stroke='#6f583d' stroke-width='6'/>"
	var volume_size = _m67g_array_to_vec3(volume.get("size_m", Vector3.ZERO))
	var volume_center = _m67g_array_to_vec3(volume.get("center_m", Vector3.ZERO))
	var subject_size = _m67g_array_to_vec3(subject.get("size_m", Vector3.ZERO))
	var subject_center = _m67g_array_to_vec3(subject.get("center_m", Vector3.ZERO))
	var vol_x = cx + (volume_center.x - volume_size.x * 0.5) * scale_x
	var vol_y = base - (volume_center.y + volume_size.y * 0.5) * scale_y
	var sub_x = cx + (subject_center.x - subject_size.x * 0.5) * scale_x
	var sub_y = base - (subject_center.y + subject_size.y * 0.5) * scale_y
	svg += "<rect x='" + str(vol_x) + "' y='" + str(vol_y) + "' width='" + str(volume_size.x * scale_x) + "' height='" + str(volume_size.y * scale_y) + "' fill='rgba(110,160,215,0.12)' stroke='#356fb4' stroke-width='4'/>"
	svg += "<rect x='" + str(sub_x) + "' y='" + str(sub_y) + "' width='" + str(subject_size.x * scale_x) + "' height='" + str(subject_size.y * scale_y) + "' fill='rgba(212,128,99,0.18)' stroke='#b66b4d' stroke-width='4'/>"
	svg += "<rect x='" + str(cx - 30.0) + "' y='" + str(base - performer_height_m * scale_y) + "' width='60' height='" + str(performer_height_m * scale_y) + "' rx='18' fill='rgba(143,131,146,0.24)' stroke='#6f6576' stroke-width='4'/>"
	var ruler_x = sub_x + subject_size.x * scale_x + 130.0
	svg += "<line x1='" + str(ruler_x) + "' y1='" + str(base) + "' x2='" + str(ruler_x) + "' y2='" + str(base - 2.8 * scale_y) + "' stroke='#d88b42' stroke-width='8'/>"
	for mark_index in range(0, 6):
		var mark_m = float(mark_index) * 0.5
		var mark_y = base - mark_m * scale_y
		svg += "<line x1='" + str(ruler_x - 34.0) + "' y1='" + str(mark_y) + "' x2='" + str(ruler_x + 34.0) + "' y2='" + str(mark_y) + "' stroke='#d88b42' stroke-width='6'/>"
		svg += "<text x='" + str(ruler_x + 48.0) + "' y='" + str(mark_y + 8.0) + "' font-size='22' fill='#915627'>" + _m67g_dim_label_m_ft(mark_m, 2) + "</text>"
	svg += "<text x='" + str(ruler_x + 48.0) + "' y='" + str(base - performer_height_m * scale_y - 18.0) + "' font-size='24' font-weight='700' fill='#915627'>Performer height " + _m67g_html_escape(_m67g_dim_label_m_ft(performer_height_m, 2)) + "</text>"
	var aim_target = volume_center
	var tier_heights: Dictionary = payload.get("tier_heights_m", {})
	for tier_y in [float(tier_heights.get("low", 0.72)), float(tier_heights.get("mid", 1.55)), float(tier_heights.get("high", 2.45))]:
		var yv = base - tier_y * scale_y
		svg += "<line x1='120' y1='" + str(yv) + "' x2='1740' y2='" + str(yv) + "' stroke='#9fb3c8' stroke-width='2' stroke-dasharray='10 8'/>"
		svg += "<text x='132' y='" + str(yv - 12.0) + "' font-size='18' fill='#54657e'>Tier reference " + _m67g_dim_label_m_ft(tier_y, 2) + "</text>"
	for r_var in data:
		var r: Dictionary = r_var as Dictionary
		var p = r["position_m"]
		var x = cx + float(p[0]) * scale_x
		var y = base - float(p[1]) * scale_y
		var tx = cx + aim_target.x * scale_x
		var ty = base - aim_target.y * scale_y
		svg += "<line x1='" + str(x) + "' y1='" + str(y) + "' x2='" + str(tx) + "' y2='" + str(ty) + "' stroke='#9db2d3' stroke-width='1.6' stroke-dasharray='7 6'/>"
		svg += _m67g_svg_support_marker(x, y, str(r.get("support_type", "Mixed")), "PASS", false)
		svg += "<text x='" + str(x + 18.0) + "' y='" + str(y - 16.0) + "' font-size='20' font-weight='700' fill='#17345e'>" + _m67g_html_escape(str(r.get("camera_label", r["id"]))) + "</text>"
	svg += _m67g_svg_dim_line(cx - STAGE_W_M * scale_x * 0.5, base + 86.0, cx + STAGE_W_M * scale_x * 0.5, base + 86.0, "Stage width " + _m67g_dim_label_m_ft(STAGE_W_M, 2), false)
	svg += _m67g_svg_dim_line(sub_x - 40.0, sub_y, sub_x - 40.0, sub_y + subject_size.y * scale_y, "Subject height " + _m67g_dim_label_m_ft(subject_size.y, 2), true)
	svg += _m67g_svg_dim_line(vol_x + volume_size.x * scale_x + 56.0, vol_y, vol_x + volume_size.x * scale_x + 56.0, vol_y + volume_size.y * scale_y, "Capture height " + _m67g_dim_label_m_ft(volume_size.y, 2), true)
	svg += _m67g_svg_scale_bar(1400.0, 1080.0, 2.0, scale_x)
	svg += "</svg>"
	return svg

func _m67g_build_side_elevation_svg(payload: Dictionary) -> String:
	var data: Array = payload.get("cameras", [])
	var volume: Dictionary = payload.get("capture_volume_bounds_m", payload.get("capture_volume", {}))
	var subject: Dictionary = payload.get("capture_subject_bounds_m", {})
	var w = 1860.0
	var h = 1180.0
	var scale_z = 86.0
	var scale_y = 270.0
	var base = 1010.0
	var cx = w * 0.5
	var performer_height_m = float(payload.get("performer_height_m", report_performer_height_m))
	var svg = "<svg xmlns='http://www.w3.org/2000/svg' width='1860' height='1180' viewBox='0 0 1860 1180'>"
	svg += "<rect width='1860' height='1180' fill='#f8f2e6'/>"
	svg += "<defs><pattern id='side_grid' width='86' height='86' patternUnits='userSpaceOnUse'><path d='M86 0H0V86' fill='none' stroke='#d6d2c9' stroke-width='1.1'/></pattern></defs>"
	svg += "<rect width='1860' height='1180' fill='url(#side_grid)'/>"
	svg += "<rect x='120' y='" + str(base) + "' width='1620' height='80' fill='#ccb28e' opacity='0.85'/>"
	svg += "<text x='80' y='82' font-size='40' font-weight='700' fill='#17345e'>Side Elevation</text>"
	svg += "<text x='80' y='122' font-size='20' fill='#425363'>Depth, clean aim lines, stage floor, and performer height reference.</text>"
	svg += "<line x1='120' y1='" + str(base) + "' x2='1740' y2='" + str(base) + "' stroke='#6f583d' stroke-width='6'/>"
	var volume_size = _m67g_array_to_vec3(volume.get("size_m", Vector3.ZERO))
	var volume_center = _m67g_array_to_vec3(volume.get("center_m", Vector3.ZERO))
	var subject_size = _m67g_array_to_vec3(subject.get("size_m", Vector3.ZERO))
	var subject_center = _m67g_array_to_vec3(subject.get("center_m", Vector3.ZERO))
	var vol_x = cx + (volume_center.z - volume_size.z * 0.5) * scale_z
	var vol_y = base - (volume_center.y + volume_size.y * 0.5) * scale_y
	var sub_x = cx + (subject_center.z - subject_size.z * 0.5) * scale_z
	var sub_y = base - (subject_center.y + subject_size.y * 0.5) * scale_y
	svg += "<rect x='" + str(vol_x) + "' y='" + str(vol_y) + "' width='" + str(volume_size.z * scale_z) + "' height='" + str(volume_size.y * scale_y) + "' fill='rgba(110,160,215,0.12)' stroke='#356fb4' stroke-width='4'/>"
	svg += "<rect x='" + str(sub_x) + "' y='" + str(sub_y) + "' width='" + str(subject_size.z * scale_z) + "' height='" + str(subject_size.y * scale_y) + "' fill='rgba(212,128,99,0.18)' stroke='#b66b4d' stroke-width='4'/>"
	svg += "<circle cx='" + str(cx + TARGET.z * scale_z) + "' cy='" + str(base - TARGET.y * scale_y) + "' r='10' fill='#214d93'/>"
	svg += "<text x='" + str(cx + TARGET.z * scale_z + 18.0) + "' y='" + str(base - TARGET.y * scale_y - 10.0) + "' font-size='22' fill='#214d93'>Aim / focus reference</text>"
	var ruler_x = sub_x + subject_size.z * scale_z + 140.0
	svg += "<line x1='" + str(ruler_x) + "' y1='" + str(base) + "' x2='" + str(ruler_x) + "' y2='" + str(base - 2.8 * scale_y) + "' stroke='#d88b42' stroke-width='8'/>"
	for mark_index in range(0, 6):
		var mark_m = float(mark_index) * 0.5
		var mark_y = base - mark_m * scale_y
		svg += "<line x1='" + str(ruler_x - 34.0) + "' y1='" + str(mark_y) + "' x2='" + str(ruler_x + 34.0) + "' y2='" + str(mark_y) + "' stroke='#d88b42' stroke-width='6'/>"
		svg += "<text x='" + str(ruler_x + 48.0) + "' y='" + str(mark_y + 8.0) + "' font-size='22' fill='#915627'>" + _m67g_dim_label_m_ft(mark_m, 2) + "</text>"
	svg += "<text x='" + str(ruler_x + 48.0) + "' y='" + str(base - performer_height_m * scale_y - 18.0) + "' font-size='24' font-weight='700' fill='#915627'>Performer height " + _m67g_html_escape(_m67g_dim_label_m_ft(performer_height_m, 2)) + "</text>"
	for r_var in data:
		var r: Dictionary = r_var as Dictionary
		var p = r["position_m"]
		var x = cx + float(p[2]) * scale_z
		var y = base - float(p[1]) * scale_y
		var aim_target = _m67g_array_to_vec3(r.get("aim_target_m", Vector3.ZERO))
		var tx = cx + aim_target.z * scale_z
		var ty = base - aim_target.y * scale_y
		svg += "<line x1='" + str(x) + "' y1='" + str(y) + "' x2='" + str(tx) + "' y2='" + str(ty) + "' stroke='#9db2d3' stroke-width='1.6' stroke-dasharray='7 6'/>"
		svg += _m67g_svg_support_marker(x, y, str(r.get("support_type", "Mixed")), "PASS", false)
		svg += "<text x='" + str(x + 18.0) + "' y='" + str(y - 16.0) + "' font-size='20' font-weight='700' fill='#17345e'>" + _m67g_html_escape(str(r.get("camera_label", r["id"]))) + "</text>"
	svg += _m67g_svg_dim_line(cx - STAGE_D_M * scale_z * 0.5, base + 86.0, cx + STAGE_D_M * scale_z * 0.5, base + 86.0, "Stage depth " + _m67g_dim_label_m_ft(STAGE_D_M, 2), false)
	svg += _m67g_svg_dim_line(sub_x, sub_y + subject_size.y * scale_y + 38.0, sub_x + subject_size.z * scale_z, sub_y + subject_size.y * scale_y + 38.0, "Subject depth " + _m67g_dim_label_m_ft(subject_size.z, 2), false)
	svg += _m67g_svg_dim_line(vol_x, vol_y + volume_size.y * scale_y + 72.0, vol_x + volume_size.z * scale_z, vol_y + volume_size.y * scale_y + 72.0, "Capture depth " + _m67g_dim_label_m_ft(volume_size.z, 2), false)
	svg += _m67g_svg_scale_bar(1400.0, 1080.0, 2.0, scale_z)
	svg += "</svg>"
	return svg

func _m67g_build_support_legend_svg(payload: Dictionary) -> String:
	var svg = "<svg xmlns='http://www.w3.org/2000/svg' width='1280' height='300' viewBox='0 0 1280 300'>"
	svg += "<rect width='1280' height='300' fill='#fbf7ef' stroke='#d5d1c5'/>"
	svg += "<text x='28' y='48' font-size='28' font-weight='700' fill='#17345e'>Rigging / Build Legend</text>"
	var supports = ["Truss", "Stands", "Tripods", "Mixed"]
	for i in range(supports.size()):
		var name = supports[i]
		var x = 70 + i * 290
		svg += _m67g_svg_support_marker(x, 122, name, "PASS", false)
		svg += "<text x='" + str(x + 34) + "' y='130' font-size='22' fill='#17345e'>" + name + "</text>"
	svg += "<text x='34' y='212' font-size='20' fill='#425363'>Stage floor = wood floor reference. Blue box = capture envelope. Warm box = performer / subject footprint. Dashed lines = aiming reference only.</text>"
	svg += "<text x='34' y='250' font-size='20' fill='#425363'>Production camera labels appear on the drawings. Internal IDs remain in CSV / JSON for technical cross-reference.</text>"
	return svg + "</svg>"

func _m67g_svg_support_marker(x: float, y: float, support_type: String, status: String, filled: bool) -> String:
	var color = "#" + _m67g_support_hex(support_type)
	var ring = "#" + _m67g_status_hex(status)
	if support_type == "Truss":
		return "<rect x='" + str(x - 10.0) + "' y='" + str(y - 10.0) + "' width='20' height='20' fill='" + (color if filled else "#ffffff") + "' stroke='" + color + "' stroke-width='2'/><line x1='" + str(x - 10.0) + "' y1='" + str(y - 10.0) + "' x2='" + str(x + 10.0) + "' y2='" + str(y + 10.0) + "' stroke='" + color + "' stroke-width='1.5'/><line x1='" + str(x - 10.0) + "' y1='" + str(y + 10.0) + "' x2='" + str(x + 10.0) + "' y2='" + str(y - 10.0) + "' stroke='" + color + "' stroke-width='1.5'/><circle cx='" + str(x) + "' cy='" + str(y) + "' r='15' fill='none' stroke='" + ring + "' stroke-width='0.9' opacity='0.5'/>"
	if support_type == "Tripods":
		return "<polygon points='" + str(x) + "," + str(y - 12.0) + " " + str(x - 12.0) + "," + str(y + 10.0) + " " + str(x + 12.0) + "," + str(y + 10.0) + "' fill='" + (color if filled else "#ffffff") + "' stroke='" + color + "' stroke-width='2'/><circle cx='" + str(x) + "' cy='" + str(y) + "' r='15' fill='none' stroke='" + ring + "' stroke-width='0.9' opacity='0.5'/>"
	if support_type == "Stands":
		return "<circle cx='" + str(x) + "' cy='" + str(y) + "' r='10' fill='" + (color if filled else "#ffffff") + "' stroke='" + color + "' stroke-width='2'/><line x1='" + str(x) + "' y1='" + str(y + 10.0) + "' x2='" + str(x) + "' y2='" + str(y + 22.0) + "' stroke='" + color + "' stroke-width='2'/><circle cx='" + str(x) + "' cy='" + str(y) + "' r='15' fill='none' stroke='" + ring + "' stroke-width='0.9' opacity='0.5'/>"
	return "<rect x='" + str(x - 11.0) + "' y='" + str(y - 11.0) + "' width='22' height='22' rx='5' fill='" + (color if filled else "#ffffff") + "' stroke='" + color + "' stroke-width='2'/><circle cx='" + str(x) + "' cy='" + str(y) + "' r='15' fill='none' stroke='" + ring + "' stroke-width='0.9' opacity='0.5'/>"

func _m67g_svg_dim_line(x1: float, y1: float, x2: float, y2: float, label: String, vertical: bool) -> String:
	var out = "<line x1='" + str(x1) + "' y1='" + str(y1) + "' x2='" + str(x2) + "' y2='" + str(y2) + "' stroke='#3f5e91' stroke-width='1.5'/>"
	if vertical:
		out += "<line x1='" + str(x1 - 8.0) + "' y1='" + str(y1) + "' x2='" + str(x1 + 8.0) + "' y2='" + str(y1) + "' stroke='#3f5e91' stroke-width='1.5'/>"
		out += "<line x1='" + str(x2 - 8.0) + "' y1='" + str(y2) + "' x2='" + str(x2 + 8.0) + "' y2='" + str(y2) + "' stroke='#3f5e91' stroke-width='1.5'/>"
		var tx = x1 + 14.0
		var ty = (y1 + y2) * 0.5
		out += "<text x='" + str(tx) + "' y='" + str(ty) + "' font-size='13' fill='#244781' transform='rotate(-90 " + str(tx) + " " + str(ty) + ")'>" + _m67g_html_escape(label) + "</text>"
	else:
		out += "<line x1='" + str(x1) + "' y1='" + str(y1 - 8.0) + "' x2='" + str(x1) + "' y2='" + str(y1 + 8.0) + "' stroke='#3f5e91' stroke-width='1.5'/>"
		out += "<line x1='" + str(x2) + "' y1='" + str(y2 - 8.0) + "' x2='" + str(x2) + "' y2='" + str(y2 + 8.0) + "' stroke='#3f5e91' stroke-width='1.5'/>"
		out += "<text x='" + str((x1 + x2) * 0.5) + "' y='" + str(y1 - 10.0) + "' text-anchor='middle' font-size='13' fill='#244781'>" + _m67g_html_escape(label) + "</text>"
	return out

func _m67g_svg_scale_bar(x: float, y: float, meters: float, scale: float) -> String:
	var px = meters * scale
	var out = "<line x1='" + str(x) + "' y1='" + str(y) + "' x2='" + str(x + px) + "' y2='" + str(y) + "' stroke='#17345e' stroke-width='4'/>"
	out += "<line x1='" + str(x) + "' y1='" + str(y - 8.0) + "' x2='" + str(x) + "' y2='" + str(y + 8.0) + "' stroke='#17345e' stroke-width='3'/>"
	out += "<line x1='" + str(x + px) + "' y1='" + str(y - 8.0) + "' x2='" + str(x + px) + "' y2='" + str(y + 8.0) + "' stroke='#17345e' stroke-width='3'/>"
	out += "<text x='" + str(x + px * 0.5) + "' y='" + str(y - 12.0) + "' text-anchor='middle' font-size='13' fill='#17345e'>Scale bar " + _m67g_dim_label_m_ft(meters, 2) + "</text>"
	return out

func _m67g_support_groups_table(payload: Dictionary) -> String:
	var groups: Dictionary = payload.get("support_groups", {})
	var html = "<table class='table'><tr><th>Support type</th><th>Camera labels</th></tr>"
	for key in ["Truss", "Stands", "Tripods", "Mixed"]:
		var cams: Array = groups.get(key, [])
		if cams.is_empty():
			continue
		html += "<tr><td>" + _m67g_html_escape(key) + "</td><td>" + _m67g_html_escape(", ".join(PackedStringArray(cams))) + "</td></tr>"
	return html + "</table>"

func _m67g_unsafe_camera_table(data: Array) -> String:
	var rows: Array[String] = []
	for r_var in data:
		var r: Dictionary = r_var as Dictionary
		var status = str(r.get("subject_frame_qc_status", r.get("frame_qc_status", "PASS")))
		var volume_status = str(r.get("volume_frame_qc_status", "PASS"))
		if status == "PASS" and volume_status == "PASS":
			continue
		var volume_pill_class = "warning" if volume_status == "WARNING" else ("fail" if volume_status == "OUTSIDE" else "pass")
		rows.append("<tr><td>" + _m67g_html_escape(str(r["id"])) + "</td><td><span class='pill " + status.to_lower() + "'>" + status + "</span></td><td><span class='pill " + volume_pill_class + "'>" + _m67g_html_escape(volume_status) + "</span></td><td>" + _m67g_html_escape(_m67g_margin_summary(r.get("subject_frame_qc_margins_pct", r.get("frame_qc_margins", {})))) + "</td><td>" + _m67g_html_escape(str(r.get("install_note", ""))) + "</td></tr>")
	if rows.is_empty():
		return "<p class='small'>All cameras currently meet training-safe subject margins and the planning volume stays inside the preferred frame envelope.</p>"
	return "<table class='table'><tr><th>Camera</th><th>Subject QC</th><th>Volume QC</th><th>Subject margins</th><th>Adjustment note</th></tr>" + "\n".join(PackedStringArray(rows)) + "</table>"

func _m67g_camera_rows_sorted(data: Array) -> Array:
	var copy = data.duplicate()
	copy.sort_custom(func(a, b): return str((a as Dictionary).get("camera_label", (a as Dictionary).get("id", ""))) < str((b as Dictionary).get("camera_label", (b as Dictionary).get("id", ""))))
	return copy

func _m67g_build_overview_html(payload: Dictionary) -> String:
	var volume = _m67g_array_to_vec3((payload.get("capture_volume_bounds_m", {}) as Dictionary).get("size_m", Vector3.ZERO))
	var subject = _m67g_array_to_vec3((payload.get("capture_subject_bounds_m", {}) as Dictionary).get("size_m", Vector3.ZERO))
	var body = "<p class='lede'>This sheet is the field build summary for the camera array. Use it to confirm production specs, coordinate references, stage dimensions, performer scale, and label conventions before layout begins.</p>"
	body += "<div class='grid-two'>"
	body += "<div class='card'><h2>Production Specs</h2><div class='kv'>"
	body += "<div class='key'>Capture Specs</div><div>" + _m67g_html_escape(str(payload.get("capture_specs", ""))) + "</div>"
	body += "<div class='key'>Stage Specs</div><div>" + _m67g_html_escape(str(payload.get("stage_specs", ""))) + "</div>"
	body += "<div class='key'>Performer Specs</div><div>" + _m67g_html_escape(str(payload.get("performer_specs", ""))) + "</div>"
	body += "<div class='key'>Stage name</div><div>" + _m67g_html_escape(str(payload.get("stage_name", ""))) + "</div>"
	body += "<div class='key'>Export time</div><div>" + _m67g_html_escape(str(payload.get("export_timestamp", ""))) + "</div>"
	body += "<div class='key'>Camera Array</div><div>" + _m67g_html_escape(str(payload.get("array_profile_name", ""))) + " · " + str(int(payload.get("camera_count_total", 0))) + " cameras</div>"
	body += "<div class='key'>Camera label scheme</div><div>" + _m67g_html_escape(str(payload.get("camera_label_scheme", ""))) + "</div>"
	body += "<div class='key'>Coordinate system</div><div>" + _m67g_html_escape(str(payload.get("coordinate_system", ""))) + "</div>"
	body += "<div class='key'>Origin</div><div>" + _m67g_html_escape(str(payload.get("origin_definition", ""))) + "</div>"
	body += "<div class='key'>Stage dimensions</div><div>" + _m67g_dim_label_m_ft(STAGE_W_M, 2) + " wide, " + _m67g_dim_label_m_ft(STAGE_D_M, 2) + " deep</div>"
	body += "<div class='key'>Performer height</div><div>" + _m67g_html_escape(_m67g_dim_label_m_ft(float(payload.get("performer_height_m", report_performer_height_m)), 2)) + " (" + _m67g_html_escape(str(payload.get("performer_height_source", "default"))) + ")</div>"
	body += "<div class='key'>Subject footprint</div><div>" + _m67g_dim_label_m_ft(subject.x, 2) + " W, " + _m67g_dim_label_m_ft(subject.z, 2) + " D, " + _m67g_dim_label_m_ft(subject.y, 2) + " H</div>"
	body += "<div class='key'>Capture envelope</div><div>" + _m67g_dim_label_m_ft(volume.x, 2) + " W, " + _m67g_dim_label_m_ft(volume.z, 2) + " D, " + _m67g_dim_label_m_ft(volume.y, 2) + " H</div>"
	body += "<div class='key'>Build mode</div><div>" + _m67g_html_escape(str(payload.get("installation_mode", ""))) + "</div>"
	body += "<div class='key'>Floor type</div><div>" + _m67g_html_escape(str(payload.get("floor_type", ""))) + "</div>"
	body += "<div class='key'>Array spacing</div><div>" + _m67g_num(float(payload.get("azimuth_spacing_deg", 0.0)), 1) + "° azimuth spacing, " + _m67g_num(float(payload.get("tier_stagger_deg", 0.0)), 1) + "° tier stagger</div>"
	body += "<div class='key'>Lens package</div><div>" + _m67g_html_escape(str(payload.get("lens_summary", ""))) + "</div>"
	body += "<div class='key'>Preview background</div><div>" + _m67g_html_escape(str(payload.get("report_preview_background", ""))) + "</div>"
	body += "</div></div>"
	body += "<div class='card'><h2>Install Notes</h2><ul class='note-list'>"
	for note in payload.get("overview_notes", []):
		body += "<li>" + _m67g_html_escape(str(note)) + "</li>"
	body += "<li>Use production camera labels on the drawings and schedule. Internal IDs remain in the technical cross-reference files.</li>"
	body += "<li>Measure lens-center heights from the finished floor surface.</li>"
	body += "<li>Final structural design, loads, overhead rigging, safety review, and venue compliance remain the responsibility of qualified production and rigging professionals.</li>"
	if str(payload.get("camera_label_warning", "")) != "":
		body += "<li class='warning'>" + _m67g_html_escape(str(payload.get("camera_label_warning", ""))) + "</li>"
	body += "</ul><div class='footnote'>Rigging disclaimer: this packet is a placement and aiming reference. Do not treat it as a stamped engineering document.</div></div></div>"
	return _m67g_sheet_shell(payload, "Sheet 01 - Build Summary", "Production specs, stage datum, performer scale, and install notes", body)

func _m67g_build_top_plan_html(payload: Dictionary) -> String:
	var body = "<p class='lede'>Use this sheet for stage floor marking, support placement, array radius checks, and label confirmation. The drawing is intentionally large for field printouts.</p>"
	body += "<div class='drawing-stack'><div class='svg-frame drawing-frame'><img src='top_plan.svg' alt='Top plan drawing'></div>"
	body += "<div class='grid-two'><div class='card'><h2>Support Groups</h2>" + _m67g_support_groups_table(payload) + "</div>"
	body += "<div class='card'><h2>Plan Checks</h2><ul class='note-list'><li>Mark the stage datum and centerlines first.</li><li>Confirm the performer footprint and capture envelope before placing supports.</li><li>Verify azimuth and stage position from the production camera label, then cross-check the internal ID only if needed.</li></ul></div></div>"
	body += "<div class='svg-frame'><img src='support_legend.svg' alt='Support legend'></div></div>"
	return _m67g_sheet_shell(payload, "Sheet 02 - Top Plan", "Floor layout, azimuth labels, and support grouping", body)

func _m67g_build_front_elevation_html(payload: Dictionary) -> String:
	var tiers: Dictionary = {}
	for r_var in payload.get("cameras", []):
		var r: Dictionary = r_var as Dictionary
		var tier = str(r.get("tier", ""))
		if not tiers.has(tier):
			tiers[tier] = []
		(tiers[tier] as Array).append(_m67g_dim_label_m_ft(float(r.get("height_m", 0.0)), 2))
	var body = "<p class='lede'>Use this sheet to verify lens-center height from floor, tier spacing, performer scale, and front-view alignment.</p>"
	body += "<div class='drawing-stack'><div class='svg-frame drawing-frame'><img src='front_elevation.svg' alt='Front elevation drawing'></div>"
	body += "<div class='grid-two'><div class='card'><h2>Height Checks</h2><table class='table'><tr><th>Tier</th><th>Reference height</th></tr>"
	for tier_name in ["low", "mid", "high"]:
		if tiers.has(tier_name):
			body += "<tr><td>" + tier_name.capitalize() + "</td><td>" + _m67g_html_escape(str((tiers[tier_name] as Array)[0])) + "</td></tr>"
	body += "</table></div>"
	body += "<div class='card'><h2>Verification Notes</h2><ul class='note-list'><li>Measure lens-center height from finished floor, not from support hardware.</li><li>Keep the height ruler beside the performer reference for quick visual confirmation.</li><li>If a tier reads tight, correct support height or support position before lockoff.</li></ul></div></div></div>"
	return _m67g_sheet_shell(payload, "Sheet 03 - Front Elevation", "Lens-center heights, tier references, and front-view aim lines", body)

func _m67g_build_side_elevation_html(payload: Dictionary) -> String:
	var rows: Array[String] = []
	for r_var in _m67g_camera_rows_sorted(payload.get("cameras", [])):
		var r: Dictionary = r_var as Dictionary
		if rows.size() >= 8:
			break
		rows.append("<tr><td>" + _m67g_html_escape(str(r.get("camera_label", r["id"]))) + "</td><td>" + _m67g_dim_label_m_ft(float(r.get("distance_3d_m", 0.0)), 2) + "</td><td>" + _m67g_html_escape(str(r.get("support_id_or_zone", ""))) + "</td></tr>")
	var body = "<p class='lede'>Use this sheet to check depth from subject, focus reference, support clearance, and performer height relative to the floor line.</p>"
	body += "<div class='drawing-stack'><div class='svg-frame drawing-frame'><img src='side_elevation.svg' alt='Side elevation drawing'></div>"
	body += "<div><div class='card'><h2>Focus Reference</h2><div class='kv'>"
	body += "<div class='key'>Focus target</div><div>" + _m67g_vec3_m_ft_label(TARGET) + "</div>"
	body += "<div class='key'>Capture volume depth</div><div>" + _m67g_dim_label_m_ft(_m67g_array_to_vec3((payload.get("capture_volume", {}) as Dictionary).get("size_m", Vector3.ZERO)).z, 2) + "</div>"
	body += "</div></div>"
	body += "<div class='card'><h2>Distance Examples</h2><table class='table'><tr><th>Camera</th><th>Focus distance</th><th>Support zone</th></tr>" + "\n".join(PackedStringArray(rows)) + "</table></div></div></div>"
	body += "<div class='card'><h2>Side-View Checks</h2><ul class='note-list'><li>Check cable runs, stands, or tripod footprints against performer travel paths.</li><li>Use the clean aim lines as a head-angle reference only.</li><li>Confirm the stage floor line and performer height ruler before final camera lockoff.</li></ul></div>"
	return _m67g_sheet_shell(payload, "Sheet 04 - Side Elevation", "Depth, focus reference, and side-view aim lines", body)

func _m67g_camera_card_html(r: Dictionary) -> String:
	var aim_target = _m67g_array_to_vec3(r.get("aim_target_m", Vector3.ZERO))
	var focus_target = _m67g_array_to_vec3(r.get("focus_target_m", Vector3.ZERO))
	var html = "<div class='camera-card'><div class='camera-title'><div><h3>" + _m67g_html_escape(str(r.get("camera_label", r["id"]))) + "</h3><div class='camera-subtitle'>Internal ID: " + _m67g_html_escape(str(r.get("internal_camera_id", r["id"]))) + "</div></div><span class='tag'>" + _m67g_html_escape(str(r.get("support_type", ""))) + "</span></div>"
	if bool(r.get("image_exists", false)):
		html += "<img src='" + _m67g_html_escape(str(r["image"])) + "' alt='" + _m67g_html_escape(str(r.get("camera_label", r["id"]))) + " thumbnail'>"
	else:
		html += "<div class='placeholder'>Contact preview not available</div>"
	html += "<div class='kv' style='margin-top:10px'>"
	html += "<div class='key'>Body / Lens</div><div>Komodo-X / " + _m67g_html_escape(str(r.get("lens", ""))) + "</div>"
	html += "<div class='key'>Support / Mount Zone</div><div>" + _m67g_html_escape(str(r.get("support_type", ""))) + " / " + _m67g_html_escape(str(r.get("support_id_or_zone", ""))) + "</div>"
	html += "<div class='key'>World position</div><div>" + _m67g_vec3_m_ft_label(_m67g_array_to_vec3(r.get("position_m", Vector3.ZERO))) + "</div>"
	html += "<div class='key'>Lens Center Height</div><div>" + _m67g_dim_label_m_ft(float(r.get("height_m", 0.0)), 2) + "</div>"
	html += "<div class='key'>Stage Position</div><div>X/Y/Z " + _m67g_vec3_label(_m67g_array_to_vec3(r.get("position_m", Vector3.ZERO)), 2) + " m</div>"
	html += "<div class='key'>Pan / tilt / roll</div><div>" + _m67g_num(float(r.get("pan_deg", 0.0)), 1) + "° / " + _m67g_num(float(r.get("tilt_deg", 0.0)), 1) + "° / " + _m67g_num(float(r.get("roll_deg", 0.0)), 1) + "°</div>"
	html += "<div class='key'>Focus Distance</div><div>" + _m67g_dim_label_m_ft(float(r.get("distance_3d_m", 0.0)), 2) + "</div>"
	html += "<div class='key'>Aim Reference</div><div>" + _m67g_vec3_m_ft_label(aim_target) + "</div>"
	html += "<div class='key'>Focus Target</div><div>" + _m67g_vec3_m_ft_label(focus_target) + "</div>"
	html += "<div class='key'>Installer Note</div><div>" + _m67g_html_escape(str(r.get("install_note", ""))) + "</div>"
	html += "</div></div>"
	return html

func _m67g_build_schedule_html(payload: Dictionary) -> String:
	var cards: Array[String] = []
	for r_var in _m67g_camera_rows_sorted(payload.get("cameras", [])):
		cards.append(_m67g_camera_card_html(r_var as Dictionary))
	var body = "<p class='lede'>Use this sheet as a field camera schedule. The visible card fields are installation-facing; technical QC and provenance remain preserved in the JSON and CSV exports.</p>"
	body += "<div class='card'><h2>Schedule Notes</h2><ul class='note-list'><li>Use the production camera label in the field and the internal ID only for technical cross-reference.</li><li>Confirm support zone, lens-center height, stage position, and aim reference before lockoff.</li><li>If a contact preview is missing, use the listed position and note fields, then refresh the packet after verification.</li></ul></div>"
	body += "<div class='schedule-grid'>" + "\n".join(PackedStringArray(cards)) + "</div>"
	return _m67g_sheet_shell(payload, "Sheet 05 - Camera Schedule", "Camera-by-camera install and verification sheet", body)

func _m67g_mat(col: Color, transparent: bool = true) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.no_depth_test = true
	return m

func _m67g_add_focus_arrow_for_selected() -> void:
	if cameras.is_empty() or selected_index < 0 or selected_index >= cameras.size():
		return
	var c: Dictionary = cameras[selected_index]
	var origin: Vector3 = c.get("position", Vector3.ZERO)
	var focus_d = origin.distance_to(TARGET)
	var dir = (TARGET - origin).normalized()
	var right = dir.cross(Vector3.UP).normalized()
	if right.length() < 0.01:
		right = Vector3.RIGHT
	var label_offset = right * 0.34 + Vector3.UP * 0.1
	var marks = [
		{"t": 0.55, "color": M67G_FOCUS_RED, "name": "unusable"},
		{"t": 0.78, "color": M67G_FOCUS_YELLOW, "name": "acceptable"},
		{"t": 1.00, "color": M67G_FOCUS_GREEN, "name": "sharp"},
		{"t": 1.18, "color": M67G_FOCUS_BLUE, "name": "far unusable"}
	]
	var prev_t = 0.0
	for m in marks:
		var t = float(m["t"])
		_m67g_add_focus_segment(origin + dir * focus_d * prev_t, origin + dir * focus_d * t, m["color"], "focus segment " + str(m["name"]))
		_m67g_add_focus_tick(origin + dir * focus_d * t, dir, right, m["color"], "focus tick " + str(m["name"]))
		_m67g_add_focus_label(origin + dir * focus_d * t + label_offset, _m67g_num(focus_d * t, 2) + "m / " + _m67g_ft(focus_d * t), m["color"])
		prev_t = t
	_m67g_add_focus_label(origin + dir * focus_d * 1.0 + Vector3.UP * 0.38, "Focus target " + _m67g_num(focus_d, 2) + "m / " + _m67g_ft(focus_d), M67G_FOCUS_GREEN)

func _m67g_add_focus_segment(a: Vector3, b: Vector3, col: Color, name: String) -> void:
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_end()
	var inst = MeshInstance3D.new()
	inst.name = name
	inst.mesh = mesh
	inst.material_override = _m67g_mat(col, true)
	overlay_root.add_child(inst)
	# Add small spheres along the segment to make the guide read thicker than a default line.
	var count = 7
	for i in range(count + 1):
		var t = float(i) / float(max(count, 1))
		var s = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.025
		sm.height = 0.05
		s.mesh = sm
		s.material_override = _m67g_mat(col, true)
		s.position = a.lerp(b, t)
		s.name = name + " bead"
		overlay_root.add_child(s)

func _m67g_add_focus_tick(p: Vector3, dir: Vector3, right: Vector3, col: Color, name: String) -> void:
	var up = Vector3.UP
	var half = 0.18
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(p - right * half)
	mesh.surface_add_vertex(p + right * half)
	mesh.surface_add_vertex(p - up * half)
	mesh.surface_add_vertex(p + up * half)
	mesh.surface_end()
	var inst = MeshInstance3D.new()
	inst.name = name
	inst.mesh = mesh
	inst.material_override = _m67g_mat(col, true)
	overlay_root.add_child(inst)

func _m67g_add_focus_label(pos: Vector3, txt: String, col: Color) -> void:
	var label = Label3D.new()
	label.name = "M67G focus distance label"
	label.text = txt
	label.font_size = 18
	label.modulate = Color(1, 1, 1, 0.95)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	overlay_root.add_child(label)

func _m67g_add_focus_color_key() -> void:
	# Replace the old generic key with the actual colors/opacity used for the M67G focus path.
	var panel = PanelContainer.new()
	panel.name = "M67G Focus Color Key"
	panel.custom_minimum_size = Vector2(320, 190)
	panel.position = Vector2(36, TOP_BAR_H + 22)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.0, 0.04, 0.04, 0.72), Color(0.22, 0.95, 1.0, 0.55), 10))
	ui_layer.add_child(panel)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var title = Label.new()
	title.text = "Focus Color Key"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.68, 1.0, 0.82))
	vb.add_child(title)
	var rows = [
		["unusable", M67G_FOCUS_RED],
		["acceptable", M67G_FOCUS_YELLOW],
		["sharp / focus target", M67G_FOCUS_GREEN],
		["far unusable", M67G_FOCUS_BLUE]
	]
	for row in rows:
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var sw = ColorRect.new()
		sw.custom_minimum_size = Vector2(54, 24)
		sw.color = row[1]
		hb.add_child(sw)
		var lab = Label.new()
		lab.text = row[0]
		lab.add_theme_font_size_override("font_size", 16)
		lab.add_theme_color_override("font_color", Color(0.9, 1.0, 0.92))
		hb.add_child(lab)
		vb.add_child(hb)
# --- SplatViz M67G blocking report + focus ticks END ---
