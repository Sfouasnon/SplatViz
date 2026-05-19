# SplatViz M5.1

Fixes the Msplat dataset intrinsics conflict discovered after the M4.9 naming/hierarchy pass.

Changes:

- keeps M4.9 unique filenames and sparse/0 image co-location
- removes top-level `fl_x`, `fl_y`, `cx`, and `cy` from `transforms.json`
- keeps per-frame intrinsics only, matching the exact Godot render camera used for each view
- logs a transforms audit before running Msplat:
  - `transforms_top_level_intrinsics=absent`
  - `transforms_frame_count=...`
  - `transforms_sample_frame_flx=...`
- bumps export/result folders to M5.1 naming

Expected run validation:

```text
colmap_missing_image_count=0
transforms_top_level_intrinsics=absent
```
