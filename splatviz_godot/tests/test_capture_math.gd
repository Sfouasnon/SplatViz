extends SceneTree
# Headless unit + parity tests for capture_math.gd.
#
# Run from the splatviz_godot/ directory:
#   godot --headless --script tests/test_capture_math.gd
#
# Exit code 0 = all pass, 1 = failures (CI-friendly).

const EPS := 0.0001

var _fails: int = 0
var _passes: int = 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("FAIL: " + label)


func _check_near(a: float, b: float, label: String, eps: float = EPS) -> void:
	_check(absf(a - b) <= eps, label + " (%f vs %f)" % [a, b])


func _init() -> void:
	var CM = load("res://scripts/capture_math.gd")
	var size := Vector2i(1920, 1080)
	var aspect := float(size.x) / float(size.y)
	var land := {"position": Vector3(4.0, 1.6, 3.0), "portrait": false}
	var port := {"position": Vector3(4.0, 1.6, 3.0), "portrait": true}
	var target := Vector3(0.0, 1.62, 0.0)

	# --- vfov selection ---
	_check_near(CM.capture_vfov_deg(land), 33.09, "landscape vfov")
	_check_near(CM.capture_vfov_deg(port), 58.77, "portrait vfov")

	# --- axes: orthonormal, aimed at target ---
	for c in [land, port]:
		var tag: String = "portrait" if bool(c["portrait"]) else "landscape"
		var axes: Dictionary = CM.capture_axes_from_target(c, target)
		var f: Vector3 = axes["forward"]
		var r: Vector3 = axes["right"]
		var u: Vector3 = axes["up"]
		_check_near(f.length(), 1.0, tag + " forward unit")
		_check_near(r.length(), 1.0, tag + " right unit")
		_check_near(u.length(), 1.0, tag + " up unit")
		_check_near(f.dot(r), 0.0, tag + " f.r orthogonal")
		_check_near(f.dot(u), 0.0, tag + " f.u orthogonal")
		_check_near(r.dot(u), 0.0, tag + " r.u orthogonal")
		var to_target: Vector3 = (target - (c["position"] as Vector3)).normalized()
		_check_near(f.dot(to_target), 1.0, tag + " forward aims at target")

	# --- portrait basis is a 90-degree roll of landscape basis ---
	var la: Dictionary = CM.capture_axes_from_target(land, target)
	var pa: Dictionary = CM.capture_axes_from_target(port, target)
	_check(((pa["right"] as Vector3) - (la["up"] as Vector3)).length() < EPS, "portrait right == landscape up")
	_check(((pa["up"] as Vector3) + (la["right"] as Vector3)).length() < EPS, "portrait up == -landscape right")
	_check(((pa["forward"] as Vector3) - (la["forward"] as Vector3)).length() < EPS, "portrait forward unchanged")

	# --- transform basis columns match axes ---
	var xf: Transform3D = CM.capture_transform(land, target)
	_check(((xf.basis.x as Vector3) - (la["right"] as Vector3)).length() < EPS, "transform basis.x == right")
	_check(((xf.basis.y as Vector3) - (la["up"] as Vector3)).length() < EPS, "transform basis.y == up")
	_check(((xf.basis.z as Vector3) - (la["back"] as Vector3)).length() < EPS, "transform basis.z == back")
	_check((xf.origin - (land["position"] as Vector3)).length() < EPS, "transform origin == position")

	# --- intrinsics: KEEP_HEIGHT pinhole ---
	for c in [land, port]:
		var tag2: String = "portrait" if bool(c["portrait"]) else "landscape"
		var intr: Dictionary = CM.capture_intrinsics(c, size)
		var vfov_deg: float = CM.capture_vfov_deg(c)
		var expect_fy: float = float(size.y) / (2.0 * tan(deg_to_rad(vfov_deg) * 0.5))
		_check_near(float(intr["fy"]), expect_fy, tag2 + " fy from vfov")
		_check_near(float(intr["fx"]), float(intr["fy"]), tag2 + " fx == fy")
		_check_near(float(intr["cx"]), 960.0, tag2 + " cx centered")
		_check_near(float(intr["cy"]), 540.0, tag2 + " cy centered")

	# --- THE ISSUE 5 PARITY TEST ---
	# The four frustum corner points at any depth must project exactly onto the
	# image corners through the capture intrinsics. If overlay geometry and
	# render intrinsics ever diverge again (as with the old hardcoded 36 deg),
	# this fails.
	for c in [land, port]:
		var tag3: String = "portrait" if bool(c["portrait"]) else "landscape"
		var depth := 5.0
		var corners: Array = CM.frustum_corner_points(c, target, depth, aspect)
		var expected_px := [
			Vector2(1920.0, 0.0),    # +right +up -> right edge, top
			Vector2(0.0, 0.0),       # -right +up -> left edge, top
			Vector2(0.0, 1080.0),    # -right -up -> left edge, bottom
			Vector2(1920.0, 1080.0)  # +right -up -> right edge, bottom
		]
		for i in range(4):
			var uv: Dictionary = CM.project_point(c, target, size, corners[i] as Vector3)
			_check(not uv.is_empty(), tag3 + " corner %d in front of camera" % i)
			if not uv.is_empty():
				_check_near(float(uv["x"]), (expected_px[i] as Vector2).x, tag3 + " corner %d px x" % i, 0.01)
				_check_near(float(uv["y"]), (expected_px[i] as Vector2).y, tag3 + " corner %d px y" % i, 0.01)
				_check_near(float(uv["depth"]), depth, tag3 + " corner %d depth" % i, 0.01)

	# --- frustum half extents: aspect and fov scaling ---
	var he: Vector2 = CM.frustum_half_extents(land, 10.0, aspect)
	_check_near(he.y, tan(deg_to_rad(33.09) * 0.5) * 10.0, "half height at 10m")
	_check_near(he.x / he.y, aspect, "extent aspect ratio")
	var he_port: Vector2 = CM.frustum_half_extents(port, 10.0, aspect)
	_check(he_port.y > he.y, "portrait vertical extent larger (wider vfov)")

	# --- regression: old hardcoded 36 deg must NOT match capture vfov ---
	_check(absf(tan(deg_to_rad(36.0) * 0.5) - tan(deg_to_rad(CM.capture_vfov_deg(land)) * 0.5)) > 0.01,
		"sanity: 36 deg legacy value differs from capture vfov (Issue 5 guard)")

	# --- variant_to_vec3 ---
	_check((CM.variant_to_vec3(Vector3(1, 2, 3)) - Vector3(1, 2, 3)).length() < EPS, "vec3 passthrough")
	_check((CM.variant_to_vec3([1.0, 2.0, 3.0]) - Vector3(1, 2, 3)).length() < EPS, "array to vec3")
	_check((CM.variant_to_vec3({"x": 1.0, "y": 2.0, "z": 3.0}) - Vector3(1, 2, 3)).length() < EPS, "dict to vec3")
	_check((CM.variant_to_vec3({"left_pct": 1.0, "right_pct": 2.0}, Vector3.ONE) - Vector3.ONE).length() < EPS, "margin dict falls back")
	_check((CM.variant_to_vec3({"–": 1.0, "y": 2.0, "z": 3.0}) - Vector3(1, 2, 3)).length() < EPS, "mojibake en-dash key tolerated")
	_check((CM.variant_to_vec3(null, Vector3.UP) - Vector3.UP).length() < EPS, "null falls back")
	_check((CM.vec3_to_array(Vector3(1, 2, 3)) as Array) == [1.0, 2.0, 3.0], "vec3 to array")

	print("capture_math tests: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
