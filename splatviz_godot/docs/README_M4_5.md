# SplatViz M4.5

Force-refreshes SplatViz-authored COLMAP sparse metadata before every Msplat run, fixing stale images.bin paths from older datasets. The image NAME policy is C##.png, with images mirrored to sparse/0/images/C##.png. Adds log validation for the bad sparse/0/images/images/C##.png path.
