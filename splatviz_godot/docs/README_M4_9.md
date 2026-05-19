# SplatViz Godot M4.9

M4.9 hardens the Msplat dataset handoff after the hierarchy/naming diagnosis.

- clean renders use unique camera-specific filenames: `CAM##_frame_000001.png`
- Msplat dataset root keeps a human-readable `images/` folder
- COLMAP/Msplat input folder `sparse/0/` now contains the PNGs directly beside `cameras.bin`, `images.bin`, and `points3D.bin`
- Run Msplat performs a hierarchy validation before launch and refuses to run if any expected image file is missing
- train.log now reports `colmap_expected_image_count`, `colmap_resolved_image_count`, and `colmap_missing_image_count`
- selected dataset detection recognizes `images.bin` as well as text sparse metadata
- progress parsing from M4.8 is preserved

Expected key log lines:

```text
colmap_resolved_image_CAM01=present
colmap_bad_double_images_path=MISSING
colmap_name_policy=m49_CAM##_frame_000001.png
colmap_expected_image_count=36
colmap_resolved_image_count=36
colmap_missing_image_count=0
```
