# SplatViz M5.2

Fixes the Msplat terminal/progress stall observed after M5.1 runs completed in train.log but the UI remained stuck at the densification display.

Key change: SplatViz no longer stops polling when `splat.ply` appears or when a bare `Saved` line appears. Msplat writes the PLY before final evaluation/exit markers, so polling now continues until the log contains the SplatViz completion markers (`SplatViz run finished...` and `splat_ply=present`).

Preserves M5.1 camera quaternion order fix and M5.0/M4.9 dataset hierarchy fixes.
