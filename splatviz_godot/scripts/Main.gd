extends Node3D

const FT_TO_M = 0.3048
const STAGE_W_M = 17.98
const STAGE_D_M = 17.37
const GRID_H_M = 5.49
const ROBOT_HEIGHT_M = 1.8034 # 5 ft 11 in
const TARGET = Vector3(0.0, 1.62, 0.0) # approximate eye/focus height for 5 ft 11 in subject
const CLEAN_RENDER_SIZE = Vector2i(1920, 1080) # 1080p at source 16:9 aspect
const LEFT_PANEL_W = 360.0
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
var ui_layer: CanvasLayer
var status_label: Label
var inspector_label: Label
var prediction_label: Label
var camera_option: OptionButton
var export_path_label: Label
var export_dialog: FileDialog
var msplat_dataset_dialog: FileDialog
var ply_import_dialog: FileDialog
var right_panel: PanelContainer
var top_bar: PanelContainer
var inspector_toggle_button: Button
var layout_option: OptionButton
var mode_label: Label
var left_panel: PanelContainer
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
var msplat_last_phase = "idle"
var msplat_train_path = ""
var msplat_num_iters = 1500
var latest_ply_path = ""
var latest_ply_summary = ""
var latest_ply_valid_points = 0
var msplat_dataset_root = ""
var msplat_result_root = ""
var splat_root: Node3D
var splat_point_material: StandardMaterial3D

var mode = "Focus"
var layout_name = "Premium 36-Camera Multi-Tier"
var selected_index = 0
var cameras: Array = []
var camera_nodes: Array = []
var export_root_path = ""
var inspector_visible = true
var camera_pov_active = false
var comparison_panel: PanelContainer
var comparison_label: Label
var focus_readout_panel: PanelContainer
var focus_readout_label: Label
var splat_frustum_mode_option: OptionButton
var splat_all_frustums = true

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
	_build_materials()
	_build_world()
	_build_ui()
	_set_layout(layout_name)
	_set_mode("Focus")
	_update_orbit_camera()
	_update_inspector()
	_update_export_label()
	status_label.text = "M5.4: Msplat terminal watchdog; log tail, PID, and progress stay live until process exit + final markers."

func _process(delta: float) -> void:
	_process_keyboard(delta)
	_layout_ui()
	_poll_msplat_terminal(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			mouse_down_left = false
			mouse_down_middle = false
			mouse_down_right = false
		elif event.keycode == KEY_F:
			_frame_selected_camera()
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
			distance = max(2.0, distance * 0.9)
			_update_orbit_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and in_view:
			distance = min(42.0, distance * 1.1)
			_update_orbit_camera()

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

func _viewport_hit(p: Vector2) -> bool:
	var s = get_viewport().get_visible_rect().size
	return p.x > LEFT_PANEL_W and p.x < s.x - _right_panel_width() and p.y > TOP_BAR_H and p.y < s.y - 8

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
	var cp = cos(pitch)
	var pos = pivot + Vector3(sin(yaw) * cp, -sin(pitch), cos(yaw) * cp) * distance
	orbit_camera.global_position = pos
	orbit_camera.look_at(pivot, Vector3.UP)
	_update_status_nav()

func _update_status_nav() -> void:
	if status_label:
		status_label.text = "Viewport: drag orbit · Shift+drag pan · wheel dolly · WASD/arrows move · Q/E vertical · F frame selected · PNG export enabled."

func _build_materials() -> void:
	mat_floor = _mat(Color(0.035, 0.11, 0.12, 1.0), false)
	mat_grid = _mat(Color(0.08, 0.32, 0.36, 0.55), true)
	mat_truss = _mat(Color(1.0, 0.66, 0.12, 0.86), true)
	mat_stand = _mat(Color(1.0, 0.65, 0.12, 1.0), false)
	mat_camera_body = _mat(Color(0.84, 0.86, 0.78, 1.0), false)
	mat_camera_lens = _mat(Color(0.0, 0.08, 0.16, 1.0), false)
	mat_camera_selected = _mat(Color(0.20, 0.95, 0.50, 1.0), false)
	mat_body = _mat(Color(0.92, 0.94, 0.9, 1.0), false)
	mat_focus_box = _mat(Color(0.2, 0.65, 1.0, 0.045), true)
	mat_frustum_faint = _mat(Color(0.25, 0.9, 0.5, 0.045), true)
	mat_selected = _mat(Color(1.0, 0.12, 0.85, 0.085), true)
	mat_prev = _mat(Color(0.0, 0.75, 1.0, 0.065), true)
	mat_next = _mat(Color(1.0, 0.62, 0.0, 0.065), true)
	mat_weak_line = _mat(Color(1.0, 1.0, 1.0, 0.85), true)
	mat_focus_too_near = _mat(Color(1.0, 0.34, 0.08, 0.085), true)
	mat_focus_accept = _mat(Color(1.0, 0.80, 0.08, 0.075), true)
	mat_focus_critical = _mat(Color(0.25, 1.0, 0.42, 0.10), true)
	# M5.3: visible unshaded point material for imported Msplat/PLY previews.
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
		_add_box(Vector3(x, 0.012, 0), Vector3(0.012, 0.012, STAGE_D_M), mat_grid, stage_root, "stage grid x")
		x += step
	var z = -STAGE_D_M / 2.0
	while z <= STAGE_D_M / 2.0:
		_add_box(Vector3(0, 0.014, z), Vector3(STAGE_W_M, 0.012, 0.012), mat_grid, stage_root, "stage grid z")
		z += step

	_add_box(Vector3(-STAGE_W_M/2.0, 0.04, 0), Vector3(0.045, 0.045, STAGE_D_M), mat_grid, stage_root, "stage boundary")
	_add_box(Vector3(STAGE_W_M/2.0, 0.04, 0), Vector3(0.045, 0.045, STAGE_D_M), mat_grid, stage_root, "stage boundary")
	_add_box(Vector3(0, 0.04, -STAGE_D_M/2.0), Vector3(STAGE_W_M, 0.045, 0.045), mat_grid, stage_root, "stage boundary")
	_add_box(Vector3(0, 0.04, STAGE_D_M/2.0), Vector3(STAGE_W_M, 0.045, 0.045), mat_grid, stage_root, "stage boundary")

func _build_rig_assets() -> void:
	# Basic assumed rigging proxies: front/upstage truss, stand zones, and a low crossbar.
	_add_box(Vector3(0, 3.65, -4.8), Vector3(7.4, 0.09, 0.13), mat_truss, rig_root, "front camera truss 24ft / 7.32m")
	_add_box(Vector3(0, 3.65, 5.3), Vector3(6.1, 0.09, 0.13), mat_truss, rig_root, "upstage 20ft truss 12ft / 3.66m")
	_add_box(Vector3(-4.0, 1.9, -0.4), Vector3(3.0, 0.055, 0.075), mat_truss, rig_root, "left low speed rail")
	_add_box(Vector3(4.0, 1.9, 0.4), Vector3(3.0, 0.055, 0.075), mat_truss, rig_root, "right low speed rail")
	_add_stand(Vector3(-6.2, 0, -1.5), 2.13, "left stand proxy 7ft / 2.13m")
	_add_stand(Vector3(6.2, 0, 1.5), 2.13, "right stand proxy 7ft / 2.13m")
	_add_stand(Vector3(-5.2, 0, 4.3), 2.6, "rear-left stand proxy")
	_add_stand(Vector3(5.2, 0, -4.3), 2.6, "front-right stand proxy")

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

func _set_layout(name: String) -> void:
	layout_name = name
	for child in camera_root.get_children():
		child.queue_free()
	for child in overlay_root.get_children():
		child.queue_free()
	cameras.clear()
	camera_nodes.clear()
	_build_cameras()
	_rebuild_camera_dropdown()
	selected_index = min(selected_index, max(0, cameras.size() - 1))
	_rebuild_overlays()
	_update_inspector()

func _camera_count() -> int:
	if layout_name.begins_with("Lean"):
		return 16
	if layout_name.begins_with("Recommended"):
		return 24
	return 36

func _build_cameras() -> void:
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
			"focus_m": pos.distance_to(TARGET),
			"px_cm": _projected_px_cm(pos.distance_to(TARGET), portrait),
			"mount": _mount_zone_for_angle(a, tier)
		}
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
	holder.look_at(TARGET, Vector3.UP)

	var body = MeshInstance3D.new()
	var bm = BoxMesh.new()
	# RED KOMODO-X proxy body: approx 129 x 101 x 95 mm scaled slightly up for visibility.
	bm.size = Vector3(0.24, 0.18, 0.19)
	body.mesh = bm
	body.material_override = mat_camera_body if data["index"] != selected_index else mat_camera_selected
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
	for child in overlay_root.get_children():
		child.queue_free()
	if focus_envelope_root != null:
		focus_envelope_root.visible = mode == "Focus" or mode == "Splat Viability"
	if mode == "Focus":
		# M2.9: all cameras transform to focus-style visualization, with reduced opacity.
		for i in range(cameras.size()):
			_add_focus_zones_for_camera(i, i == selected_index)
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
	elif mode == "Rig / Lighting":
		_add_mount_lines()
		if not cameras.is_empty():
			overlay_root.add_child(_make_frustum_mesh(cameras[selected_index], mat_selected, true, true))
	elif mode == "Edit Camera":
		if focus_envelope_root != null:
			focus_envelope_root.visible = true
		if not cameras.is_empty():
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
	var origin: Vector3 = data["position"] as Vector3
	var target = TARGET
	var forward = (target - origin).normalized()
	var right = forward.cross(Vector3.UP).normalized()
	if right.length() < 0.001:
		right = Vector3.RIGHT
	var up = right.cross(forward).normalized()
	var focus_d = origin.distance_to(target)
	var far_d = focus_d * 0.985 if stop_at_subject else max(6.0, focus_d + 1.4)
	var half_h = tan(deg_to_rad(36.0) / 2.0) * far_d
	var half_w = half_h * 16.0 / 9.0
	if bool(data["portrait"]):
		var tmp = half_h
		half_h = half_w
		half_w = tmp
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
	_add_frustum_segment(origin, TARGET, max(0.4, critical_near - 0.75), critical_near, _mat(Color(1.0,0.32,0.06,0.030 * alpha_mul), true), str(data["id"]) + " orange: approaching too near")
	_add_frustum_segment(origin, TARGET, critical_near - 0.18, critical_near, _mat(Color(1.0,0.82,0.08,0.030 * alpha_mul), true), str(data["id"]) + " yellow: acceptable near focus")
	_add_frustum_segment(origin, TARGET, critical_near, critical_far, _mat(Color(0.22,1.0,0.38,0.075 * alpha_mul), true), str(data["id"]) + " green: critical sharpness slab")
	_add_frustum_segment(origin, TARGET, critical_far, display_far, _mat(Color(1.0,0.82,0.08,0.030 * alpha_mul), true), str(data["id"]) + " yellow: acceptable far focus")
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

func _add_frustum_segment(origin: Vector3, target: Vector3, near_d: float, far_d: float, material: Material, name: String) -> void:
	if far_d <= near_d + 0.02:
		return
	var forward = (target - origin).normalized()
	var right = forward.cross(Vector3.UP).normalized()
	if right.length() < 0.001:
		right = Vector3.RIGHT
	var up = right.cross(forward).normalized()
	var vfov = deg_to_rad(36.0)
	var aspect = 16.0/9.0
	var n_h = tan(vfov/2.0) * near_d
	var n_w = n_h * aspect
	var f_h = tan(vfov/2.0) * far_d
	var f_w = f_h * aspect
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
	_add_toolbar_label(th, "SplatViz M5.4", 22, Color(0.68, 1.0, 0.82), 165)
	_add_toolbar_button(th, "Scene", func(): _set_mode("Rig / Lighting"), 92)
	_add_toolbar_button(th, "Cameras", func(): _set_mode("Edit Camera"), 110)
	_add_toolbar_button(th, "Analysis", func(): _set_mode("Comparison"), 112)
	_add_toolbar_button(th, "Export", func(): _choose_export_folder(), 92)
	_add_toolbar_button(th, "Msplat", func(): _open_msplat_window(), 104)
	_add_toolbar_button(th, "Splat View", func(): _set_mode("Splat View"), 122)
	_add_toolbar_button(th, "Help", func(): _show_help(), 78)

	left_panel = PanelContainer.new()
	left_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_panel.offset_left = 0
	left_panel.offset_top = TOP_BAR_H
	left_panel.offset_right = LEFT_PANEL_W
	left_panel.offset_bottom = 0
	left_panel.position = Vector2(0, TOP_BAR_H)
	left_panel.size = Vector2(LEFT_PANEL_W, screen_size.y - TOP_BAR_H)
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
	lv.custom_minimum_size = Vector2(LEFT_PANEL_W - 24, 0)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 6)
	left_scroll.add_child(lv)
	_add_label(lv, "PROJECT / STAGE", 14, Color(0.45, 1.0, 0.67))
	_add_label(lv, "NOZ Stage #1\n59×57 ft / 17.98×17.37 m\ngrid 18 ft / 5.49 m", 15, Color(0.82,0.93,0.89))

	_add_label(lv, "LAYOUT", 14, Color(0.45, 1.0, 0.67))
	layout_option = OptionButton.new()
	layout_option.add_theme_font_size_override("font_size", 16)
	layout_option.add_item("Lean 16-Camera Msplat")
	layout_option.add_item("Recommended 24-Camera Baseline")
	layout_option.add_item("Premium 36-Camera Multi-Tier")
	layout_option.selected = 2
	layout_option.item_selected.connect(func(idx): _on_layout_selected(idx))
	lv.add_child(layout_option)

	_add_label(lv, "MODE", 14, Color(0.45, 1.0, 0.67))
	_add_button(lv, "Focus", func(): _set_mode("Focus"))
	_add_button(lv, "Splat Viability", func(): _set_mode("Splat Viability"))
	_add_button(lv, "Compare Layouts", func(): _set_mode("Comparison"))
	_add_button(lv, "Edit Camera", func(): _set_mode("Edit Camera"))
	_add_button(lv, "Camera POV", func(): _set_mode("Camera POV"))
	_add_button(lv, "Splat View", func(): _set_mode("Splat View"))
	_add_button(lv, "Rig / Lighting", func(): _set_mode("Rig / Lighting"))
	mode_label = _add_label(lv, "Mode: Focus", 17, Color.WHITE)
	_add_label(lv, "SPLAT FRUSTUM VIEW", 14, Color(0.45, 1.0, 0.67))
	splat_frustum_mode_option = OptionButton.new()
	splat_frustum_mode_option.add_theme_font_size_override("font_size", 16)
	splat_frustum_mode_option.add_item("All frustums")
	splat_frustum_mode_option.add_item("Selected only")
	splat_frustum_mode_option.selected = 0
	splat_frustum_mode_option.item_selected.connect(func(idx): _on_splat_frustum_mode_selected(idx))
	lv.add_child(splat_frustum_mode_option)

	_add_label(lv, "RENDER / EXPORT", 14, Color(0.45, 1.0, 0.67))
	_add_button(lv, "Render Clean All", func(): _render_all_cameras())
	_add_button(lv, "Render Clean Selected", func(): _render_selected_camera())
	_add_button(lv, "Choose Export Folder…", func(): _choose_export_folder())
	_add_button(lv, "Import PLY…", func(): _browse_ply_file())
	_add_button(lv, "Load Latest Splat", func(): _load_latest_msplat_result())
	export_path_label = _add_label(lv, "Exports save outside the project repo", 12, Color(0.70,0.84,0.78))

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
	inspector_toggle_button.text = "« Inspector"
	inspector_toggle_button.position = Vector2(screen_size.x - RIGHT_PANEL_W - 112, TOP_BAR_H + 8)
	inspector_toggle_button.size = Vector2(104, 34)
	inspector_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	inspector_toggle_button.pressed.connect(func(): _toggle_inspector())
	root.add_child(inspector_toggle_button)

	# Persistent next/previous camera buttons, useful in Camera POV and selection review.
	prev_cam_button = Button.new()
	prev_cam_button.text = "‹\nPrev\nCam"
	prev_cam_button.position = Vector2(LEFT_PANEL_W + 12, screen_size.y * 0.48)
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

	_build_comparison_panel(root, screen_size)
	_build_msplat_panel(root, screen_size)

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
	msplat_terminal_label.text = "$ SplatViz Msplat terminal ready.\n$ Browse/export a dataset, then Run Msplat. Older datasets are auto-upgraded with COLMAP binary sparse metadata.\n$ Sparse status: M5.4 auto-upgrades selected datasets with COLMAP binary cameras/images/points3D plus Nerfstudio transforms.\n$ Progress follows densify + step logs; final refresh waits for SplatViz exit/splat markers.\n"
	terminal_box.add_child(msplat_terminal_label)
	_update_msplat_terminal_header()

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
	if status_label:
		status_label.text = "Help: drag orbit · Shift+drag pan · wheel dolly · WASD/arrows move · Q/E vertical · F frame selected. Top tabs switch modes; Cameras opens Edit Camera; Analysis opens layout comparison; Msplat opens a separate terminal window."


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
	if camera_root != null:
		camera_root.visible = not splat_view
	if rig_root != null:
		rig_root.visible = not splat_view
	if overlay_root != null:
		overlay_root.visible = not splat_view
	# M5.3: Splat View is reserved for imported/reconstructed PLY results. Hide source robot.
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

func _panel_style(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.13,0.34,0.36,0.85)
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

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

func _on_splat_frustum_mode_selected(idx: int) -> void:
	splat_all_frustums = idx == 0
	if mode == "Splat Viability":
		_rebuild_overlays()
	_update_inspector()

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
	inspector_visible = not inspector_visible
	if right_panel != null:
		right_panel.visible = inspector_visible
	if inspector_toggle_button != null:
		inspector_toggle_button.text = "« Inspector" if inspector_visible else "Inspector »"
		var screen_size = get_viewport().get_visible_rect().size
		inspector_toggle_button.position = Vector2(screen_size.x - RIGHT_PANEL_W - 112, TOP_BAR_H + 8) if inspector_visible else Vector2(screen_size.x - 112, TOP_BAR_H + 8)

func _select_prev_camera() -> void:
	if cameras.is_empty():
		return
	selected_index = _prev_index()
	if camera_option != null:
		camera_option.selected = selected_index
	_rebuild_overlays()
	_update_inspector()
	if camera_pov_active:
		_camera_pov()

func _select_next_camera() -> void:
	if cameras.is_empty():
		return
	selected_index = _next_index()
	if camera_option != null:
		camera_option.selected = selected_index
	_rebuild_overlays()
	_update_inspector()
	if camera_pov_active:
		_camera_pov()

func _on_layout_selected(idx: int) -> void:
	if idx == 0:
		_set_layout("Lean 16-Camera Msplat")
	elif idx == 1:
		_set_layout("Recommended 24-Camera Baseline")
	else:
		_set_layout("Premium 36-Camera Multi-Tier")
	_update_prediction()

func _on_camera_selected(idx: int) -> void:
	selected_index = idx
	_rebuild_overlays()
	_update_inspector()

func _apply_selected_camera_position(new_pos: Vector3) -> void:
	if cameras.is_empty():
		return
	new_pos.y = clamp(new_pos.y, 0.35, 3.85)
	var c = cameras[selected_index]
	c["position"] = new_pos
	c["focus_m"] = new_pos.distance_to(TARGET)
	c["px_cm"] = _projected_px_cm(float(c["focus_m"]), bool(c["portrait"]))
	c["azimuth_deg"] = fposmod(rad_to_deg(atan2(new_pos.z, new_pos.x)), 360.0)
	c["mount"] = _mount_zone_for_angle(deg_to_rad(float(c["azimuth_deg"])), str(c["tier"]))
	cameras[selected_index] = c
	var node = camera_nodes[selected_index] as Node3D
	if node != null:
		node.position = new_pos
		node.look_at(TARGET, Vector3.UP)
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
		c["px_cm"] = _projected_px_cm(float(c["focus_m"]), bool(c["portrait"]))
		cameras[selected_index] = c
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
		left_panel.size = Vector2(LEFT_PANEL_W, max(1.0, s.y - TOP_BAR_H))
	if right_panel != null:
		right_panel.position = Vector2(s.x - RIGHT_PANEL_W, TOP_BAR_H)
		right_panel.size = Vector2(RIGHT_PANEL_W, max(1.0, s.y - TOP_BAR_H))
	if inspector_toggle_button != null:
		inspector_toggle_button.position = Vector2(s.x - RIGHT_PANEL_W - 112, TOP_BAR_H + 8) if inspector_visible else Vector2(s.x - 112, TOP_BAR_H + 8)
	if prev_cam_button != null:
		prev_cam_button.position = Vector2(LEFT_PANEL_W + 12, s.y * 0.48)
	if next_cam_button != null:
		next_cam_button.position = Vector2(s.x - _right_panel_width() - 68, s.y * 0.48)
	if focus_readout_panel != null:
		focus_readout_panel.position = Vector2(s.x - _right_panel_width() - 590, s.y - 252)
	if comparison_panel != null:
		comparison_panel.position = Vector2(LEFT_PANEL_W + 24, TOP_BAR_H + 24)
		comparison_panel.size = Vector2(max(520.0, s.x - LEFT_PANEL_W - _right_panel_width() - 48), 335)
	# Msplat terminal lives in its own Window in M3.5; no stage overlay layout needed.


func _set_mode(new_mode: String) -> void:
	mode = new_mode
	camera_pov_active = mode == "Camera POV"
	if comparison_panel != null:
		comparison_panel.visible = mode == "Comparison"
	# Msplat is a separate window, not an overlay mode.
	if mode_label:
		mode_label.text = "Mode: " + mode
	if camera_pov_active:
		_camera_pov()
	else:
		_rebuild_overlays()
	_apply_mode_visibility()
	_update_prediction()
	_update_inspector()

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
			focus_readout_label.text += "Preview: " + (latest_ply_summary if latest_ply_summary != "" else "no PLY stats yet") + "\n"
		focus_readout_label.text += "Next bridge: COLMAP sparse binary export or COLMAP/GLOMAP integration."


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
		text += "Use Prev Cam / Next Cam to step around the array in camera order. Clean renders use the same selected camera transforms and hide all planning overlays.\n\n"
		text += "Render output\n" + export_root_path + "/splatviz_clean_m53/images/C##/CAM##_frame_000001.png"
	elif mode == "Rig / Lighting":
		text += "RIG / LIGHTING — " + str(c["id"]) + "\n\n"
		text += "Mount assumption: " + str(c["mount"]) + "\n"
		text += "Planning proxy only, not final rigging. Evaluate physical attachment, shadows, cable access, and whether moving inward creates lighting problems at T5.6 / ISO 800 / 90° shutter."
	elif mode == "Splat View":
		text += "SPLAT VIEW\n\n"
		text += "Purpose\nInspect an imported Msplat / PLY result on the same NOZ Stage #1 coordinate frame. The source robot is hidden so failed or empty PLY output is obvious.\n\n"
		text += "Loaded PLY\n" + (latest_ply_path if latest_ply_path != "" else "No PLY imported yet. Use Import PLY or Load Latest Splat.") + "\n\n"
		text += "PLY preview stats\n" + (latest_ply_summary if latest_ply_summary != "" else "No PLY stats yet.") + "\n\n"
		text += "Interpretation\nThis is a point-cloud preview, not a final production gsplat assessment. M5.4 filters invalid/NaN vertices from Msplat PLYs and auto-fits tiny COLMAP-scale results into the performer envelope for visual inspection.\n\n"
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

func _update_camera_highlight() -> void:
	for i in range(camera_nodes.size()):
		var holder: Node3D = camera_nodes[i]
		var body = holder.get_node_or_null(str(cameras[i]["id"]) + " body") as MeshInstance3D
		if body:
			body.material_override = mat_camera_selected if i == selected_index else mat_camera_body
		var label = holder.get_node_or_null(str(cameras[i]["id"]) + " label") as Label3D
		if label:
			# Default: selected camera only. Top/Rig views can still show labels through inspector selection.
			label.visible = i == selected_index or mode == "Rig / Lighting"
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
		_rebuild_overlays()
		_update_inspector()

func _frame_selected_camera() -> void:
	if cameras.is_empty():
		return
	pivot = (cameras[selected_index]["position"] as Vector3).lerp(TARGET, 0.35)
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

func _camera_pov() -> void:
	if cameras.is_empty():
		return
	for child in overlay_root.get_children():
		child.queue_free()
	if focus_envelope_root != null:
		focus_envelope_root.visible = false
	var c = cameras[selected_index]
	pivot = TARGET
	var pos: Vector3 = c["position"] as Vector3
	orbit_camera.global_position = pos
	orbit_camera.look_at(TARGET, Vector3.UP)
	status_label.text = "Camera POV preview for " + str(c["id"]) + ". Use Prev Cam / Next Cam to step through the array."

func _save_view_png() -> void:
	var out_dir = export_root_path + "/splatviz_view_m39"
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

func _render_selected_camera() -> void:
	if cameras.is_empty():
		return
	var c = cameras[selected_index]
	var out_dir = export_root_path + "/splatviz_clean_m53/images/" + str(c["id"])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path = out_dir + "/" + _camera_unique_filename(c)
	await _render_camera_to_path(c, path, CLEAN_RENDER_SIZE, true)
	_write_render_manifest(export_root_path + "/splatviz_clean_m53", [c], CLEAN_RENDER_SIZE, true)
	status_label.text = "Rendered clean selected camera still: " + path

func _render_all_cameras() -> void:
	var root = export_root_path + "/splatviz_clean_m53/images"
	DirAccess.make_dir_recursive_absolute(root)
	for c in cameras:
		var out_dir = root + "/" + str(c["id"])
		DirAccess.make_dir_recursive_absolute(out_dir)
		await _render_camera_to_path(c, out_dir + "/" + _camera_unique_filename(c), CLEAN_RENDER_SIZE, true)
	_write_render_manifest(export_root_path + "/splatviz_clean_m53", cameras, CLEAN_RENDER_SIZE, true)
	status_label.text = "Rendered " + str(cameras.size()) + " clean 1080p 16:9 stills to: " + root

func _render_camera_to_path(c: Dictionary, path: String, size: Vector2i, clean: bool) -> void:
	var visibility_state = _begin_clean_render_visibility() if clean else {}
	var sv = SubViewport.new()
	sv.size = size
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	sv.world_3d = get_viewport().world_3d
	sv.disable_3d = false
	add_child(sv)
	var cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 33.09 if not bool(c["portrait"]) else 58.77
	cam.global_position = c["position"] as Vector3
	sv.add_child(cam)
	cam.look_at(TARGET, Vector3.UP)
	if bool(c["portrait"]):
		cam.rotate_object_local(Vector3(0, 0, -1), deg_to_rad(90.0))
	cam.current = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img = sv.get_texture().get_image()
	img.save_png(path)
	sv.queue_free()
	if clean:
		_end_clean_render_visibility(visibility_state)

func _begin_clean_render_visibility() -> Dictionary:
	var state = {}
	state["overlay"] = overlay_root.visible
	state["stage_root"] = stage_root.visible
	state["camera_root"] = camera_root.visible
	state["rig_root"] = rig_root.visible
	state["focus_envelope"] = focus_envelope_root.visible if focus_envelope_root != null else true
	overlay_root.visible = false
	stage_root.visible = false
	camera_root.visible = false
	rig_root.visible = false
	if focus_envelope_root != null:
		focus_envelope_root.visible = false
	return state

func _end_clean_render_visibility(state: Dictionary) -> void:
	overlay_root.visible = bool(state.get("overlay", true))
	stage_root.visible = bool(state.get("stage_root", true))
	camera_root.visible = bool(state.get("camera_root", true))
	rig_root.visible = bool(state.get("rig_root", true))
	if focus_envelope_root != null:
		focus_envelope_root.visible = bool(state.get("focus_envelope", true))

func _write_render_manifest(root_path: String, cams: Array, size: Vector2i, clean: bool) -> void:
	DirAccess.make_dir_recursive_absolute(root_path)
	var cam_entries = []
	for c in cams:
		var pos: Vector3 = c["position"] as Vector3
		cam_entries.append({
			"camera_id": str(c["id"]),
			"image_path": "images/" + str(c["id"]) + "/" + _camera_unique_filename(c),
			"position_m": [pos.x, pos.y, pos.z],
			"look_at_m": [TARGET.x, TARGET.y, TARGET.z],
			"focus_distance_m": float(c["focus_m"]),
			"tier": str(c["tier"]),
			"portrait_roll": bool(c["portrait"]),
			"lens": "Rokinon DSX24-RF 24mm T1.5",
			"body": "RED KOMODO-X proxy"
		})
	var manifest = {
		"splatviz_version": "M5.4",
		"render_type": "clean" if clean else "diagnostic",
		"export_root_path": root_path,
		"subject_asset": "SplatVizRobot.glb",
		"subject_height_m": ROBOT_HEIGHT_M,
		"subject_height_ft_in": "5 ft 11 in",
		"resolution_px": [size.x, size.y],
		"source_aspect_ratio": "16:9",
		"layout": layout_name,
		"overlays_hidden_for_clean_render": clean,
		"stage_helpers_hidden_for_clean_render": clean,
		"validation_note": "Msplat is a Msplat run. Production conclusions require gsplat validation.",
		"cameras": cam_entries
	}
	var f = FileAccess.open(root_path + "/render_manifest.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(manifest, "  "))
		f.close()


func _msplat_input_path() -> String:
	var dataset = msplat_dataset_root if msplat_dataset_root != "" else export_root_path + "/splatviz_msplat_dataset_m54"
	if FileAccess.file_exists(dataset + "/sparse/0/cameras.bin") and FileAccess.file_exists(dataset + "/sparse/0/images.bin") and FileAccess.file_exists(dataset + "/sparse/0/points3D.bin"):
		return dataset + "/sparse/0"
	return dataset

func _msplat_command_string() -> String:
	var home = OS.get_environment("HOME")
	var train_path = home + "/msplat-env/bin/msplat-train"
	var input_path = _msplat_input_path()
	var result = msplat_result_root if msplat_result_root != "" else export_root_path + "/splatviz_msplat_result_m54"
	var ply = result + "/splat.ply"
	return train_path + " --input " + input_path + " --output " + ply + " --num-iters " + str(msplat_num_iters) + " --eval --test-every 8"

func _update_msplat_terminal_header() -> void:
	var home = OS.get_environment("HOME")
	if msplat_train_path == "":
		msplat_train_path = home + "/msplat-env/bin/msplat-train"
	if msplat_dataset_root == "":
		msplat_dataset_root = export_root_path + "/splatviz_msplat_dataset_m54"
	if msplat_result_root == "":
		msplat_result_root = export_root_path + "/splatviz_msplat_result_m54"
	if msplat_path_label:
		msplat_path_label.text = "msplat-train: " + msplat_train_path + "\nDataset: " + msplat_dataset_root + "\nResult: " + msplat_result_root
	if msplat_command_label:
		msplat_command_label.text = "Command: " + _msplat_command_string()

func _append_msplat_terminal(line: String) -> void:
	if msplat_terminal_label == null:
		return
	msplat_terminal_label.text += line + "\n"
	var max_chars = 16000
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
		dataset = base + "/splatviz_msplat_dataset_from_images_m53"
		_create_msplat_dataset_from_images(chosen, dataset)
		_append_msplat_terminal("$ Built Nerfstudio transforms.json dataset from clean images folder: " + dataset)
	elif not has_sparse and not has_transforms and has_images:
		dataset = chosen + "_msplat_dataset_m53"
		_create_msplat_dataset_from_images(chosen + "/images", dataset)
		_append_msplat_terminal("$ Built Nerfstudio transforms.json dataset from selected render folder: " + dataset)
	elif not has_sparse and not has_transforms:
		_append_msplat_terminal("$ Warning: selected folder does not contain transforms.json or sparse/0/images.bin/images.txt. Select a SplatViz dataset root, COLMAP sparse dataset root, or clean images folder.")
	msplat_dataset_root = dataset
	msplat_result_root = _path_parent(dataset) + "/splatviz_msplat_result_m54"
	msplat_log_path = msplat_result_root + "/train.log"
	_update_msplat_terminal_header()
	_refresh_msplat_terminal(false)

func _path_parent(path: String) -> String:
	var p = path.trim_suffix("/")
	var idx = p.rfind("/")
	if idx <= 0:
		return p
	return p.substr(0, idx)

func _create_msplat_dataset_from_images(images_root: String, dataset_root: String) -> void:
	DirAccess.make_dir_recursive_absolute(dataset_root + "/images")
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0")
	var copied = 0
	for c in cameras:
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
	_write_colmap_dataset(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_seed_point_cloud_ply(dataset_root)
	_mirror_images_to_colmap_sparse(dataset_root)
	_write_colmap_binary_dataset(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_nerfstudio_transforms(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_msplat_manifest(dataset_root, cameras, CLEAN_RENDER_SIZE)
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
		best = export_root_path + "/splatviz_msplat_dataset_m54"
		_append_msplat_terminal("$ No prior dataset found. Defaulting to: " + best)
	else:
		_append_msplat_terminal("$ Found latest dataset: " + best)
	msplat_dataset_root = best
	msplat_result_root = export_root_path + "/splatviz_msplat_result_m54"
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
		# M5.4: Densification can be a long phase before msplat emits step= logs.
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

func _refresh_msplat_terminal(force: bool) -> void:
	if msplat_log_path == "":
		msplat_log_path = (msplat_result_root if msplat_result_root != "" else export_root_path + "/splatviz_msplat_result_m54") + "/train.log"
	if not FileAccess.file_exists(msplat_log_path):
		if force:
			_append_msplat_terminal("$ No train.log yet: " + msplat_log_path)
		return
	var current_size = FileAccess.get_modified_time(msplat_log_path) # fallback heartbeat if size API is unavailable
	var f = FileAccess.open(msplat_log_path, FileAccess.READ)
	if f == null:
		return
	var txt = f.get_as_text()
	f.close()
	var byte_size = txt.length()
	if byte_size != msplat_log_last_size:
		msplat_log_last_size = byte_size
		msplat_log_idle_seconds = 0.0
	else:
		msplat_log_idle_seconds += 1.0
	var max_chars = 18000
	var full_txt = txt
	if txt.length() > max_chars:
		txt = "… tail of train.log …\n" + txt.substr(max(0, txt.length() - max_chars), max_chars)
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
	# M5.4: never stop terminal refresh from file presence alone. The watchdog waits for
	# process exit plus final log markers, so the window remains truthful during long densify/eval phases.

func _poll_msplat_terminal(delta: float) -> void:
	# M5.4: poll whenever a process is known, the terminal window is visible, or we owe
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
	if msplat_log_idle_seconds >= 5.0:
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
	_append_msplat_terminal("$ Exporting SplatViz synthetic dataset…")
	var dataset_root = export_root_path + "/splatviz_msplat_dataset_m54"
	msplat_dataset_root = dataset_root
	DirAccess.make_dir_recursive_absolute(dataset_root + "/images")
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0")
	for c in cameras:
		var img_path = dataset_root + "/images/" + _camera_unique_filename(c)
		await _render_camera_to_path(c, img_path, CLEAN_RENDER_SIZE, true)
	_write_colmap_dataset(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_seed_point_cloud_ply(dataset_root)
	_mirror_images_to_colmap_sparse(dataset_root)
	_write_colmap_binary_dataset(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_nerfstudio_transforms(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_msplat_manifest(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_update_msplat_terminal_header()
	_append_msplat_terminal("$ Dataset ready: " + dataset_root)
	_append_msplat_terminal("$ Images: " + dataset_root + "/images")
	_append_msplat_terminal("$ transforms.json: " + dataset_root + "/transforms.json")
	_append_msplat_terminal("$ seed PLY: " + dataset_root + "/splatviz_seed_points.ply")
	_append_msplat_terminal("$ COLMAP binary sparse: " + dataset_root + "/sparse/0/cameras.bin + images.bin + points3D.bin")
	_append_msplat_terminal("$ Sparse note: points3D.bin is synthetic seed geometry authored by SplatViz, not COLMAP/GLOMAP triangulation yet.")
	if msplat_status_label:
		msplat_status_label.text = "Msplat dataset exported: " + dataset_root
	if status_label:
		status_label.text = "Exported Msplat/Nerfstudio synthetic dataset: " + dataset_root

func _msplat_dataset_has_colmap_sparse(path: String) -> bool:
	return path != "" and FileAccess.file_exists(path + "/sparse/0/cameras.bin") and FileAccess.file_exists(path + "/sparse/0/images.bin") and FileAccess.file_exists(path + "/sparse/0/points3D.bin")

func _msplat_dataset_has_seed(path: String) -> bool:
	return path != "" and FileAccess.file_exists(path + "/splatviz_seed_points.ply")

func _msplat_dataset_is_ready(path: String) -> bool:
	if path == "":
		return false
	# M5.4 requires the COLMAP binary sparse bridge before training. Nerfstudio transforms alone
	# loaded in Msplat but produced zero Gaussians, so treat it as incomplete for Run Msplat.
	if _msplat_dataset_has_colmap_sparse(path):
		return true
	if DirAccess.dir_exists_absolute(path + "/keyframes"):
		return true
	return false

func _ensure_msplat_dataset_current() -> void:
	if msplat_dataset_root == "":
		msplat_dataset_root = export_root_path + "/splatviz_msplat_dataset_m54"
	# M5.4: always rewrite SplatViz-authored COLMAP sparse metadata before training.
	# Older datasets could leave stale images.bin paths such as NAME=images/C##.png,
	# which Msplat resolves incorrectly. Rewriting every run keeps the M5.4 policy:
	# NAME=CAM##_frame_000001.png and image file located directly in sparse/0/.
	if DirAccess.dir_exists_absolute(msplat_dataset_root + "/images"):
		_append_msplat_terminal("$ Refreshing COLMAP sparse metadata in selected dataset:")
		_append_msplat_terminal("$ " + msplat_dataset_root)
		_rewrite_msplat_sparse_bridge(msplat_dataset_root)
	else:
		_append_msplat_terminal("$ No usable images folder found at selected dataset. Exporting fresh M5.4 dataset…")
		await _export_msplat_dataset()
	_update_msplat_terminal_header()

func _rewrite_msplat_sparse_bridge(dataset_root: String) -> void:
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0")
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0/images")
	# Rebuild all metadata that Msplat may inspect. These files are safe to overwrite.
	_write_colmap_dataset(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_seed_point_cloud_ply(dataset_root)
	_mirror_images_to_colmap_sparse(dataset_root)
	_write_colmap_binary_dataset(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_nerfstudio_transforms(dataset_root, cameras, CLEAN_RENDER_SIZE)
	_write_msplat_manifest(dataset_root, cameras, CLEAN_RENDER_SIZE)
	var policy_path = dataset_root + "/sparse/0/splatviz_colmap_name_policy_m54.txt"
	var pf = FileAccess.open(policy_path, FileAccess.WRITE)
	if pf != null:
		pf.store_string("M5.4 COLMAP images.bin policy: NAME=CAM##_frame_000001.png; Msplat resolves to sparse/0/CAM##_frame_000001.png.\n")
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
		msplat_dataset_root = export_root_path + "/splatviz_msplat_dataset_m54"
	# M5.4: do not run an older transforms-only dataset. Rebuild/export the sparse seed bridge first.
	await _ensure_msplat_dataset_current()
	if not _msplat_dataset_is_ready(msplat_dataset_root):
		_append_msplat_terminal("$ ERROR: dataset is still not Msplat-ready after rebuild/export.")
		_append_msplat_terminal("$ Expected sparse/0/cameras.bin, images.bin, and points3D.bin, or a supported Polycam keyframes folder.")
		return
	var hierarchy = _validate_msplat_sparse_image_hierarchy(msplat_dataset_root)
	_append_msplat_terminal("$ Dataset hierarchy check: resolved " + str(hierarchy.get("resolved", 0)) + "/" + str(hierarchy.get("expected", 0)) + " COLMAP image files in " + str(hierarchy.get("input_path", "")))
	if int(hierarchy.get("missing", 0)) > 0:
		_append_msplat_terminal("$ ERROR: missing COLMAP image file before launch: " + str(hierarchy.get("first_missing", "")))
		_append_msplat_terminal("$ Fix: export a fresh M5.4 dataset. Msplat resolves image names relative to sparse/0, so the PNGs must live directly beside cameras.bin/images.bin/points3D.bin.")
		return
	msplat_result_root = export_root_path + "/splatviz_msplat_result_m54"
	DirAccess.make_dir_recursive_absolute(msplat_result_root)
	var script_path = msplat_result_root + "/run_msplat.zsh"
	var log_path = msplat_result_root + "/train.log"
	var ply_path = msplat_result_root + "/splat.ply"
	msplat_log_path = log_path
	# M5.4: remove stale outputs before launching so the terminal never parses an old
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
	script += "test -f " + _shell_quote(msplat_dataset_root + "/sparse/0/splatviz_colmap_name_policy_m54.txt") + " && echo 'colmap_name_policy=m54_CAM##_frame_000001.png' >> " + _shell_quote(log_path) + " || echo 'colmap_name_policy=MISSING' >> " + _shell_quote(log_path) + "\n"
	script += "echo 'colmap_quaternion_order=qw_qx_qy_qz' >> " + _shell_quote(log_path) + "\n"
	script += "test -f " + _shell_quote(msplat_dataset_root + "/sparse/0/splatviz_colmap_seed_audit_m53.txt") + " && cat " + _shell_quote(msplat_dataset_root + "/sparse/0/splatviz_colmap_seed_audit_m53.txt") + " >> " + _shell_quote(log_path) + " || echo 'colmap_seed_tracks_policy=MISSING' >> " + _shell_quote(log_path) + "\n"
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
	script += _shell_quote(msplat_train_path) + " --input " + _shell_quote(_msplat_input_path()) + " --output " + _shell_quote(ply_path) + " --num-iters " + str(msplat_num_iters) + " --eval --test-every 8 >> " + _shell_quote(log_path) + " 2>&1\n"
	script += "ec=$?\n"
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

func _load_latest_msplat_result() -> void:
	_append_msplat_terminal("$ Loading latest splat preview…")
	if msplat_result_root == "":
		msplat_result_root = export_root_path + "/splatviz_msplat_result_m54"
	var ply_path = msplat_result_root + "/splat.ply"
	if not FileAccess.file_exists(ply_path):
		_append_msplat_terminal("$ No splat.ply yet: " + ply_path)
		if msplat_status_label:
			msplat_status_label.text = "No splat.ply yet: " + ply_path
		if status_label:
			status_label.text = "No Msplat result found yet. Check train.log or wait for training to finish."
		return
	latest_ply_path = ply_path
	var count = _load_ply_point_cloud(ply_path)
	_set_mode("Splat View")
	_append_msplat_terminal("$ Loaded splat preview: " + str(count) + " sampled points")
	if msplat_status_label:
		msplat_status_label.text = "Loaded splat preview: " + str(count) + " sampled points"
	if status_label:
		status_label.text = "Loaded Msplat PLY preview on stage: " + ply_path + " · " + latest_ply_summary

func _write_colmap_dataset(dataset_root: String, cams: Array, size: Vector2i) -> void:
	var cam_txt = "# SplatViz synthetic COLMAP cameras\n# CAMERA_ID, MODEL, WIDTH, HEIGHT, PARAMS[]\n"
	var img_txt = "# SplatViz synthetic COLMAP images\n# IMAGE_ID, QW, QX, QY, QZ, TX, TY, TZ, CAMERA_ID, NAME\n# POINTS2D[] left empty for synthetic Msplat run\n"
	for i in range(cams.size()):
		var c = cams[i]
		var camera_id = i + 1
		var image_id = i + 1
		var vfov = 58.77 if bool(c["portrait"]) else 33.09
		var fy = float(size.y) / (2.0 * tan(deg_to_rad(vfov) * 0.5))
		var fx = fy
		var cx = float(size.x) * 0.5
		var cy = float(size.y) * 0.5
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
	# M5.4 policy: COLMAP images.bin NAME is the unique flat filename, e.g.
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
	# not triangulated by COLMAP/GLOMAP. M5.4 adds synthetic projected 2D tracks so
	# the COLMAP sparse model is internally coherent instead of a trackless point seed.
	DirAccess.make_dir_recursive_absolute(dataset_root + "/sparse/0")
	var seed_ply = dataset_root + "/splatviz_seed_points.ply"
	var obs = _build_colmap_seed_observations(cams, seed_ply, size)
	_write_colmap_cameras_bin(dataset_root + "/sparse/0/cameras.bin", cams, size)
	_write_colmap_images_bin(dataset_root + "/sparse/0/images.bin", cams, obs.get("image_observations", []))
	_write_colmap_points3d_bin(dataset_root + "/sparse/0/points3D.bin", obs)
	_write_colmap_seed_audit(dataset_root, obs)

func _colmap_intrinsics_for(c: Dictionary, size: Vector2i) -> Dictionary:
	var vfov = 58.77 if bool(c["portrait"]) else 33.09
	var fy = float(size.y) / (2.0 * tan(deg_to_rad(vfov) * 0.5))
	return {"fx": fy, "fy": fy, "cx": float(size.x) * 0.5, "cy": float(size.y) * 0.5, "vfov": vfov}

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
	var pos: Vector3 = c["position"] as Vector3
	var z = (TARGET - pos).normalized() # COLMAP camera +Z / forward
	var x = Vector3.UP.cross(z).normalized() # camera +X / right
	if x.length() < 0.001:
		x = Vector3.RIGHT
	var y = -z.cross(x).normalized() # camera +Y / down
	if bool(c["portrait"]):
		var old_x = x
		x = y
		y = -old_x
	var rel = p - pos
	var xc = x.dot(rel)
	var yc = y.dot(rel)
	var zc = z.dot(rel)
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
	var path = dataset_root + "/sparse/0/splatviz_colmap_seed_audit_m53.txt"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("colmap_seed_tracks_policy=m53_projected_seed_tracks\n")
	f.store_string("colmap_seed_source_vertices=" + str(obs.get("source_vertices", 0)) + "\n")
	f.store_string("colmap_seed_point3d_count=" + str((obs.get("kept_vertices", []) as Array).size()) + "\n")
	f.store_string("colmap_seed_observation_count=" + str(obs.get("total_observations", 0)) + "\n")
	f.store_string("colmap_pose_convention=world_to_camera_rows_xright_ydown_zforward_qw_qx_qy_qz\n")
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

func _write_seed_point_cloud_ply(dataset_root: String) -> void:
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
	# reference floor patch below subject so coordinate scale has a visible anchor
	_seed_box(points, Vector3(0.0, -0.012, 0.0), Vector3(1.15, 0.02, 1.15), 245, 245, 235, 24, 2, 24)
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
		var vfov = 58.77 if bool(c["portrait"]) else 33.09
		var fy = float(size.y) / (2.0 * tan(deg_to_rad(vfov) * 0.5))
		var fx = fy
		frames.append({
			"file_path": "images/" + _camera_unique_filename(c),
			"fl_x": fx,
			"fl_y": fy,
			"cx": float(size.x) * 0.5,
			"cy": float(size.y) * 0.5,
			"w": size.x,
			"h": size.y,
			"camera_id": str(c["id"]),
			"splatviz_tier": str(c["tier"]),
			"splatviz_focus_distance_m": fd,
			"transform_matrix": _nerfstudio_transform(c)
		})
	# M5.4: do not write top-level fl_x/fl_y/cx/cy. Mixed portrait/landscape cameras
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
		"splatviz_version": "M5.4",
		"splatviz_intrinsics_policy": "No top-level intrinsics; per-frame fl_x/fl_y/cx/cy match the exact Godot render camera for each view.",
		"splatviz_note": "Synthetic Nerfstudio-style transforms authored by SplatViz; production conclusions require gsplat validation.",
		"frames": frames
	}
	var f = FileAccess.open(dataset_root + "/transforms.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(doc, "  "))
		f.close()

func _nerfstudio_transform(c: Dictionary) -> Array:
	var pos: Vector3 = c["position"] as Vector3
	var forward = (TARGET - pos).normalized()
	var right = forward.cross(Vector3.UP).normalized()
	if right.length() < 0.001:
		right = Vector3.RIGHT
	var up = right.cross(forward).normalized()
	if bool(c["portrait"]):
		var old_right = right
		right = up
		up = -old_right
	var z_axis = -forward
	return [
		[right.x, up.x, z_axis.x, pos.x],
		[right.y, up.y, z_axis.y, pos.y],
		[right.z, up.z, z_axis.z, pos.z],
		[0.0, 0.0, 0.0, 1.0]
	]

func _write_msplat_manifest(dataset_root: String, cams: Array, size: Vector2i) -> void:
	var entries = []
	for c in cams:
		var pos: Vector3 = c["position"] as Vector3
		entries.append({
			"camera_id": str(c["id"]),
			"image": "images/" + _camera_unique_filename(c),
			"position_m": [pos.x, pos.y, pos.z],
			"look_at_m": [TARGET.x, TARGET.y, TARGET.z],
			"focus_distance_m": float(c["focus_m"]),
			"tier": str(c["tier"]),
			"portrait_roll": bool(c["portrait"]),
			"projected_px_cm": float(c["px_cm"])
		})
	var manifest = {
		"splatviz_version": "M5.4",
		"dataset_type": "nerfstudio_transforms_plus_colmap_binary_sparse",
		"dataset_root": dataset_root,
		"images": "images/CAM##_frame_000001.png",
		"nerfstudio_transforms": "transforms.json",
		"seed_point_cloud": "splatviz_seed_points.ply",
		"resolution_px": [size.x, size.y],
		"layout": layout_name,
		"subject_asset": "SplatVizRobot.glb",
		"validation_note": "Msplat is a local Msplat run. Production conclusions still require gsplat validation.",
		"cameras": entries
	}
	var f = FileAccess.open(dataset_root + "/splatviz_msplat_manifest.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(manifest, "  "))
		f.close()

func _colmap_pose(c: Dictionary) -> Array:
	var pos: Vector3 = c["position"] as Vector3
	var z = (TARGET - pos).normalized()
	var x = Vector3.UP.cross(z).normalized()
	if x.length() < 0.001:
		x = Vector3.RIGHT
	var y = -z.cross(x).normalized()
	if bool(c["portrait"]):
		var old_x = x
		x = y
		y = -old_x
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

func _load_ply_point_cloud(path: String) -> int:
	# M5.4: robust Msplat PLY preview loader. Msplat writes binary little-endian
	# Gaussian PLYs with many attributes, and early short runs can contain NaN
	# Gaussians. Filter invalid vertices and auto-fit tiny COLMAP-scale results
	# into the performer envelope for inspection.
	latest_ply_summary = ""
	latest_ply_valid_points = 0
	if splat_root == null:
		latest_ply_summary = "No splat_root available."
		return 0
	for child in splat_root.get_children():
		child.queue_free()
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		latest_ply_summary = "Could not open PLY."
		return 0
	var vertex_count = 0
	var format = "ascii"
	var props = []
	while not f.eof_reached():
		var line = f.get_line().strip_edges()
		if line.begins_with("format"):
			format = line
		elif line.begins_with("element vertex"):
			var parts = line.split(" ", false)
			if parts.size() >= 3:
				vertex_count = int(parts[2])
		elif line.begins_with("property"):
			var pparts = line.split(" ", false)
			if pparts.size() >= 3:
				props.append({"type": pparts[1], "name": pparts[2]})
		elif line == "end_header":
			break
	var max_points = 90000
	var stride = max(1, int(ceil(float(max(1, vertex_count)) / float(max_points))))
	var raw_points: Array = []
	var invalid_count = 0
	if format.find("binary_little_endian") >= 0:
		f.big_endian = false
		for i in range(vertex_count):
			var vals = _read_ply_vertex_binary(f, props)
			if i % stride != 0:
				continue
			var p = Vector3(float(vals.get("x", 0.0)), float(vals.get("y", 0.0)), float(vals.get("z", 0.0)))
			if _is_valid_ply_point(p):
				raw_points.append(p)
			else:
				invalid_count += 1
	else:
		for i in range(vertex_count):
			if f.eof_reached():
				break
			var row = f.get_line().split(" ", false)
			if i % stride == 0 and row.size() >= 3:
				var p = Vector3(float(row[0]), float(row[1]), float(row[2]))
				if _is_valid_ply_point(p):
					raw_points.append(p)
				else:
					invalid_count += 1
	if raw_points.is_empty():
		latest_ply_summary = "PLY loaded, but every sampled vertex was invalid/NaN. Vertex count: " + str(vertex_count)
		return 0
	var min_p: Vector3 = raw_points[0]
	var max_p: Vector3 = raw_points[0]
	for p in raw_points:
		min_p = Vector3(min(min_p.x, p.x), min(min_p.y, p.y), min(min_p.z, p.z))
		max_p = Vector3(max(max_p.x, p.x), max(max_p.y, p.y), max(max_p.z, p.z))
	var span = max_p - min_p
	var center = (min_p + max_p) * 0.5
	var target_height = 1.803 # 5 ft 11 in robot / performer reference height
	var auto_fit = false
	var scale = 1.0
	if span.y > 0.0001 and span.y < 0.65:
		auto_fit = true
		scale = target_height / span.y
	elif max(span.x, max(span.y, span.z)) < 0.65:
		auto_fit = true
		scale = target_height / max(0.0001, max(span.x, max(span.y, span.z)))
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 0.035)
	if auto_fit:
		mesh.size = Vector3(0.018, 0.018, 0.018)
	mm.mesh = mesh
	mm.instance_count = raw_points.size()
	var out_i = 0
	for p in raw_points:
		var q = p
		if auto_fit:
			q = Vector3((p.x - center.x) * scale, (p.y - min_p.y) * scale, (p.z - center.z) * scale)
		mm.set_instance_transform(out_i, Transform3D(Basis(), q))
		out_i += 1
	mm.visible_instance_count = out_i
	var inst = MultiMeshInstance3D.new()
	inst.name = "Msplat PLY preview valid points"
	inst.multimesh = mm
	inst.material_override = splat_point_material
	splat_root.add_child(inst)
	latest_ply_valid_points = out_i
	var fit_note = "auto-fit to performer envelope" if auto_fit else "native coordinates"
	latest_ply_summary = "vertices=" + str(vertex_count) + ", visible=" + str(out_i) + ", invalid/NaN skipped≈" + str(invalid_count) + ", bbox=" + _vec3_short(span) + ", " + fit_note
	return out_i

func _is_valid_ply_point(p: Vector3) -> bool:
	# NaN check: a NaN is not equal to itself. Also reject absurd coordinates.
	if p.x != p.x or p.y != p.y or p.z != p.z:
		return false
	if absf(p.x) > 100000.0 or absf(p.y) > 100000.0 or absf(p.z) > 100000.0:
		return false
	return true

func _vec3_short(v: Vector3) -> String:
	return "%.3f×%.3f×%.3fm" % [v.x, v.y, v.z]

func _read_ply_vertex_binary(f: FileAccess, props: Array) -> Dictionary:
	var vals = {}
	for p in props:
		var t = str(p["type"])
		var n = str(p["name"])
		var v = 0.0
		if t == "float" or t == "float32":
			v = f.get_float()
		elif t == "double" or t == "float64":
			v = f.get_double()
		elif t == "uchar" or t == "uint8" or t == "char" or t == "int8":
			v = f.get_8()
		elif t == "ushort" or t == "uint16" or t == "short" or t == "int16":
			v = f.get_16()
		elif t == "uint" or t == "uint32" or t == "int" or t == "int32":
			v = f.get_32()
		else:
			v = f.get_float()
		if n == "x" or n == "y" or n == "z":
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
