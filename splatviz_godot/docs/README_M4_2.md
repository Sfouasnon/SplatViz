# SplatViz M4.2

Msplat integration pass.

- Adds Msplat progress label + progress bar parsed from `step=` lines in `train.log`.
- Keeps a more verbose Msplat log header with dataset validation, COLMAP binary status, selected input path, and process exit code.
- Exports COLMAP-style binary sparse metadata in addition to Nerfstudio `transforms.json`:
  - `sparse/0/cameras.bin`
  - `sparse/0/images.bin`
  - `sparse/0/points3D.bin`
- Mirrors images into `sparse/0/images/` so the COLMAP input path can resolve image names.
- Uses the COLMAP sparse folder as the Msplat input path when binary files are present.

Note: `points3D.bin` is still a SplatViz-authored synthetic seed point cloud, not a triangulated COLMAP/GLOMAP solve. If Msplat still returns zero Gaussians, the next step is true known-pose triangulation or integrating COLMAP/GLOMAP.
