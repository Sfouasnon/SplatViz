# SplatViz Godot M4.8

Progress/status repair pass for the Msplat Terminal.

## Changes
- Progress bar no longer stalls at 2% during Msplat densification.
- Parses `Densified: A -> B gaussians` lines and reports current Gaussian count before step logs appear.
- Parses comma-formatted splat counts such as `29,350`.
- Parses `step= N` progress and computes real percentage against selected target iterations.
- Detects `Saved`, `SplatViz run finished`, `splat_ply=present`, Traceback, and RuntimeError.
- Shows final PSNR / SSIM / L1 metrics in the progress label when present.

## Notes
The M4.7 run completed successfully at 10,000 iterations with 29,350 Gaussians, PSNR 10.5930, SSIM 0.4519, and L1 0.2065. M4.8 is a UI/status fix; it does not change the COLMAP or Msplat dataset export policy.
