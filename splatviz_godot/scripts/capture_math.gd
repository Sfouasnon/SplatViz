class_name CaptureMath
extends RefCounted
# Single source of truth for SplatViz capture-camera math.
#
# Phase 1 of the Main.gd module split (see IMPROVEMENT_PLAN.md, 2026-06-11).
# Every function here is STATIC and PURE: same inputs -> same outputs, no scene
# or instance state. Anything that needs scene state (e.g. the live subject
# bounds used by aim targets) stays in Main.gd and passes results in explicitly.
#
# CRITICAL INVARIANT (Issue 5 fix): all camera visualization (frustum overlays,
# focus zones) and all capture/export paths (stills, COLMAP, transforms.json)
# must derive their geometry from THIS file, so what the user sees in the
# viewport is exactly what the render and the dataset contain.

# --- Capture camera constants (moved from Main.gd M66D) ---
const LANDSCAPE_VFOV_DEG := 33.09
const PORTRAIT_VFOV_DEG := 58.77
const CAPTURE_KEEP_ASPECT := Camera3D.KEEP_HEIGHT
const CAPTURE_NEAR := 0.05
const CAPTURE_FAR := 4000.0


static func capture_vfov_deg(c: Dictionary) -> float:
	# Per-camera vertical FOV actually used by the capture cameras.
	# This—NOT a hardcoded value—must drive every frustum visualization.
	return PORTRAIT_VFOV_DEG if bool(c.get("portrait", false)) else LANDSCAPE_VFOV_DEG


static func capture_axes_from_target(c: Dictionary, aim_target: Vector3) -> Dictionary:
	# World-space camera basis aimed at aim_target.
	# Portrait orientation is expressed as a 90-degree roll of the basis
	# (right <- up, up <- -right), exactly matching _m66d_apply_capture_camera.
	var pos: Vector3 = c["position"] as Vector3
	var forward := (aim_target - pos).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length() < 0.001:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	if bool(c.get("portrait", false)):
		var old_right := right
		right = up
		up = -old_right
	return {
		"position": pos,
		"forward": forward,
		"right": right,
		"up": up,
		"back": -forward
	}


static func capture_transform(c: Dictionary, aim_target: Vector3) -> Transform3D:
	var axes := capture_axes_from_target(c, aim_target)
	return Transform3D(
		Basis(axes["right"] as Vector3, axes["up"] as Vector3, axes["back"] as Vector3),
		axes["position"] as Vector3
	)


static func capture_intrinsics(c: Dictionary, size: Vector2i) -> Dictionary:
	# Pinhole intrinsics implied by the capture camera (KEEP_HEIGHT => fy from vfov).
	var vfov := capture_vfov_deg(c)
	var fy := float(size.y) / (2.0 * tan(deg_to_rad(vfov) * 0.5))
	var fx := fy
	return {
		"fx": fx,
		"fy": fy,
		"cx": float(size.x) * 0.5,
		"cy": float(size.y) * 0.5,
		"vfov": vfov,
		"hfov": rad_to_deg(2.0 * atan(float(size.x) / max(1.0, 2.0 * fx)))
	}


static func frustum_half_extents(c: Dictionary, distance: float, aspect: float) -> Vector2:
	# Half width/height of the visible image rectangle at a given forward
	# distance, in the (possibly portrait-rolled) camera basis from
	# capture_axes_from_target. Because the portrait roll lives in the basis,
	# NO width/height swap is applied here; with the rolled axes these extents
	# reproduce the rendered framing exactly.
	var half_h := tan(deg_to_rad(capture_vfov_deg(c)) * 0.5) * distance
	return Vector2(half_h * aspect, half_h)


static func frustum_corner_points(c: Dictionary, aim_target: Vector3, distance: float, aspect: float) -> Array:
	# Four world-space corners of the image rectangle at a forward distance.
	# Order: top-right, top-left, bottom-left, bottom-right (in camera basis).
	var axes := capture_axes_from_target(c, aim_target)
	var origin: Vector3 = axes["position"] as Vector3
	var fwd: Vector3 = axes["forward"] as Vector3
	var right: Vector3 = axes["right"] as Vector3
	var up: Vector3 = axes["up"] as Vector3
	var he := frustum_half_extents(c, distance, aspect)
	var center := origin + fwd * distance
	return [
		center + right * he.x + up * he.y,
		center - right * he.x + up * he.y,
		center - right * he.x - up * he.y,
		center + right * he.x - up * he.y
	]


static func project_point(c: Dictionary, aim_target: Vector3, size: Vector2i, p: Vector3) -> Dictionary:
	# Project a world point through the capture camera's pinhole model.
	# Returns {} when the point is behind the camera, else {"x","y","depth"}
	# in pixel coordinates (image y down). Used by parity tests and audits.
	var axes := capture_axes_from_target(c, aim_target)
	var rel: Vector3 = p - (axes["position"] as Vector3)
	var depth := rel.dot(axes["forward"] as Vector3)
	if depth <= 0.001:
		return {}
	var intr := capture_intrinsics(c, size)
	var x_cam := rel.dot(axes["right"] as Vector3)
	var y_cam := rel.dot(axes["up"] as Vector3)
	return {
		"x": float(intr["cx"]) + float(intr["fx"]) * x_cam / depth,
		"y": float(intr["cy"]) - float(intr["fy"]) * y_cam / depth,
		"depth": depth
	}


static func variant_to_vec3(v: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if typeof(v) == TYPE_VECTOR3:
		return v as Vector3
	if typeof(v) == TYPE_ARRAY:
		var a: Array = v as Array
		if a.size() >= 3:
			return Vector3(float(a[0]), float(a[1]), float(a[2]))
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v as Dictionary
		if d.has("x") and d.has("y") and d.has("z"):
			return Vector3(float(d["x"]), float(d["y"]), float(d["z"]))
		if d.has("left_pct") and d.has("right_pct"):
			return fallback
		# Mojibake tolerance carried over from Main.gd: some historical JSON
		# payloads have "x" corrupted to an en-dash by a past patch script.
		# TODO(cleanup): drop once old payloads are migrated/regenerated.
		if d.has("–") and d.has("y") and d.has("z"):
			return Vector3(float(d["–"]), float(d["y"]), float(d["z"]))
	return fallback


static func vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]
