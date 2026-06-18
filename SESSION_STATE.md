# SplatViz — state as of 2026-06-18

Handoff snapshot after the diagnosis + quality-tuning session. Pairs with
IMPROVEMENT_PLAN.md (original plan) and the git history.

## What's fixed / validated

- **Issue 5 (frustum FOV mismatch):** fixed — `capture_math.gd` is the single
  source of truth; overlays use real capture FOV. (commit dcc8182)
- **Issue 1 (cut-in-half splats):** root cause was a degenerate seed PLY
  (producer/consumer type mismatch wrote 20k origin points). Fixed + guarded.
  (commit 59fac0c)
- **Pipeline validated end-to-end:** the reprojection overlay proved the COLMAP
  poses, intrinsics (fx=fy=1817.77), seed geometry (1.76 m robot), and the CPU
  renderer's projection are all correct. SplatViz's plan→export job is sound.
- **`--keep-crs` fix:** Msplat defaulted to auto-normalizing the scene, saving
  splats in a non-metric frame (broke verification + the blueprint pipeline).
  SplatViz now passes `--keep-crs` (Main.gd). **Needs app rebuild.**
- The macOS app builds and launches (PACKAGING.md, export_presets.cfg).

## Locked training config

```
msplat-train --input <dataset>/sparse/0 --output <out>.ply \
  --num-iters 15000 --keep-crs --densify-grad-thresh 0.001 \
  --eval --test-every 8
```

Chosen for **stability + reproducibility** (the prerequisite for fair layout
comparison), not max detail. Produces ~16k usable Gaussians, clean render,
~28 dB PSNR on training views.

## Quality trajectory (our DC-only renderer, training views)

| run | Gaussians | NaN % | PSNR | SSIM | note |
|---|---|---|---|---|---|
| 10K no keep-crs | — | — | 12.5 | 0.21 | wrong frame (false 12 dB) |
| 10K keep-crs | 67k | 12% | 22.1 | 0.57 | frame fixed |
| 30K grad 0.0005 | 167k | **71%** | 22.1 | 0.77 | runaway densification — rejected |
| **15K grad 0.001** | **19.5k** | 16% | **27.9** | 0.58 | **locked: clean + stable** |

Notes: the steady ~12–16% NaN across healthy runs is almost certainly Msplat
tagging pruned/dead Gaussians (benign — the renderer drops them); only the
runaway 30K hit 71%. SSIM↓ with leaner splats is the detail-vs-cleanliness
tradeoff; PSNR↑ because fewer floaters.

## New tools (all in tools/, verified)

- `splatviz_cut_diagnosis.py` — cut-plane / pose-parity diagnosis
- `inspect_ply.py`, `seed_vs_result_bbox.py` — PLY/seed inspectors
- `frame_check.py` — PLY-vs-camera frame + NaN report
- `reproject_overlay.py` — stamp seed points on a GT still (pose validation)
- `cpu_render.py` — independent CPU forward renderer (DC-only color, drops NaN)
- `splatviz_metrics.py` — PSNR/SSIM/LPIPS on rendered vs GT
- `splatviz_holdout_split.py` — toggleable held-out split
- `splatviz_ab_compare.py` — compare runs (e.g. 10K vs 30K)
- `splatviz_trainlog_eval.py` — parse Msplat eval blocks across logs
- `splatviz_layout_eval.py` — rank camera layouts vs a fixed validation set
- `splatviz_open_viewer.py` — open a PLY in a local desktop viewer
- `tools/tests/test_phase3_metrics.py` — 21 passing self-tests

## Next: layout optimization (chosen direction)

1. Build a fixed **validation dome** in SplatViz: ~12 viewpoints between/above
   the candidate camera positions, exported as a dataset (held out from all
   layouts). This is the fair yardstick — only possible because the scene is
   synthetic.
2. For each candidate layout (start: current 36-cam vs a 24-cam): export, train
   with the locked config, producing one PLY each.
3. `splatviz_layout_eval.py --validation <dome> --layout <label> <ply> ...`
   ranks them → the optimal rig, provable with a number.

## Known open items

- Trainer detail vs stability: the locked config favors stability; a polished
  final hero render may want a denser config + NaN stripping.
- NaN stripping: add a one-liner to drop NaN Gaussians from shipped PLYs.
- Full SH in cpu_render (currently DC-only; undersells color/detail).
- Report/blueprint layer (Issue 4) and 4DGS + better CG asset / FBX import
  (see splatviz-asset-roadmap) still ahead.
