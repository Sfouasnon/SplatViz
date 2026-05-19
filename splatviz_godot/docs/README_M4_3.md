# SplatViz M4.3

- Run Msplat now auto-upgrades older datasets that only contain transforms.json/images.
- If sparse/0/cameras.bin, images.bin, points3D.bin or splatviz_seed_points.ply are missing, SplatViz rebuilds those files in place from dataset/images before launching msplat-train.
- Find Latest Dataset now scans any folder containing msplat_dataset in the name and prefers datasets with COLMAP binary sparse metadata.
- Msplat input path should now point to sparse/0 when binary sparse metadata is present.
