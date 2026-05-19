# SplatViz M3.8

Adds a dedicated Splat View tab for importing and viewing PLY results on the same stage with cameras, rig proxies, frustums and focus overlays hidden.

Adds Msplat training iteration presets and a Run Longer 10k action. The current msplat-train CLI does not expose a resume flag, so longer runs retrain from the selected/exported dataset rather than resuming an existing splat.ply.

SplatViz exports a synthetic seed point cloud (`splatviz_seed_points.ply`) automatically with Nerfstudio-style datasets. This is not a true COLMAP sparse reconstruction. If Msplat continues to emit zero Gaussians, the next bridge is COLMAP binary sparse export or another initializer supported by Msplat.
