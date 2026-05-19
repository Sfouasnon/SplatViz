# SplatViz M3.6

Msplat zero-Gaussian fix attempt. M3.5 proved Msplat could parse the SplatViz Nerfstudio dataset, but the run initialized 0 Gaussians. M3.6 exports `splatviz_seed_points.ply` and references it from `transforms.json` using Nerfstudio point-cloud keys so Msplat has deterministic synthetic initialization geometry.

If Gaussians still remain 0, the installed Msplat loader is ignoring Nerfstudio seed point clouds and the next bridge should write COLMAP binary `cameras.bin/images.bin/points3D.bin` or use a small external converter.
