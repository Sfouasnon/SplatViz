# SplatViz M4.0

UI repair pass for the Msplat Terminal.

- Replaces the container-based Msplat Terminal with a fixed explicit layout so labels no longer collapse vertically.
- Keeps terminal no-wrap scrolling.
- Makes sparse/seed-cloud status explicit in the terminal.
- SplatViz currently exports a synthetic seed PLY with Nerfstudio transforms; this is not a true COLMAP sparse reconstruction. If Msplat continues to produce zero Gaussians, the next bridge is COLMAP binary cameras/images/points3D export.
