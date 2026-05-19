# SplatViz M3.0

Adds the first Msplat smoke-test loop:

- Export Msplat Dataset: writes 1080p clean renders plus COLMAP-style `sparse/0` camera metadata.
- Run Msplat Smoke Test: launches `~/msplat-env/bin/msplat-train` in a background zsh script and writes logs to the export folder.
- Load Latest Splat: loads `splat.ply` back onto the same SplatViz stage as a sampled PLY point-cloud preview.

Default outputs:

- `~/Desktop/SplatViz_Exports/splatviz_msplat_dataset_m30`
- `~/Desktop/SplatViz_Exports/splatviz_msplat_result_m30/splat.ply`
- `~/Desktop/SplatViz_Exports/splatviz_msplat_result_m30/train.log`

Msplat remains a local smoke test. Production conclusions still require gsplat validation.
