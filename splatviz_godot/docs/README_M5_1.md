# SplatViz M5.1

M5.1 makes the COLMAP quaternion export explicit and auditable.

- `_quat_from_rotation_rows()` now returns an explicit array in COLMAP order: `[qw, qx, qy, qz]`.
- `_colmap_pose()` writes the same explicit `[qw, qx, qy, qz, tx, ty, tz]` order used by COLMAP `images.bin` and `images.txt`.
- Quaternions are normalized before export.
- Msplat logs now include `colmap_quaternion_order=qw_qx_qy_qz`.
- M5.0 hierarchy and intrinsics fixes are preserved.

Run a 10K validation first. Add the 30K validation preset after the M5.1 result is inspected.
