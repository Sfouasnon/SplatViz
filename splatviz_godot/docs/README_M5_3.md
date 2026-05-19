# SplatViz M5.3

Purpose: test whether the remaining NaN-heavy Msplat output is caused by the synthetic COLMAP sparse seed being internally trackless.

Changes:
- Preserves M5.2 final-refresh polling fix.
- Preserves M5.1 quaternion order fix: COLMAP qvec is written as qw, qx, qy, qz.
- Preserves M5.0/M4.9 image hierarchy fixes.
- Adds synthetic projected 2D observations to images.bin.
- Adds matching tracks to points3D.bin.
- Writes sparse/0/splatviz_colmap_seed_audit_m53.txt.
- train.log now reports colmap_seed_tracks_policy, source seed vertices, kept 3D points, total synthetic observations, and pose convention.

The seed tracks are not COLMAP/GLOMAP triangulation. They are a deterministic ground-truth bridge from the SplatViz-authored camera/seed geometry, intended to test whether Msplat behaves better with a coherent COLMAP sparse model.
