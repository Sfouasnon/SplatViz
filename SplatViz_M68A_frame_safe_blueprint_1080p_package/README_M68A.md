# SplatViz M68A Frame-Safe Blueprint 1080p Package

This package wraps the current SplatViz app state without changing camera math, Splat View, Gaussian preview, or msplat source code.

Use it to:

1. Verify the current frame-safe 12/24/36 preset state.
2. Launch the Godot app.
3. Export a real Frame-Safe 36 layout report.
4. Build a real 1080p Frame-Safe 36 dataset.
5. Start a local 10K `msplat-train` run.
6. Watch that run.
7. Record a compact snapshot into the existing project history file.

Codex did not run the expensive report export, dataset build, or msplat training. Those steps are local user-run commands only.

## Defaults

- `SPLATVIZ_PROJECT`: `~/Desktop/SplatViz/splatviz_godot`
- `SPLATVIZ_EXPORT_ROOT`: `~/Desktop/SplatViz_Exports`
- `SPLATVIZ_LAYOUT`: `Frame-Safe 36-Camera Multi-Tier`
- `SPLATVIZ_RENDER_W`: `1920`
- `SPLATVIZ_RENDER_H`: `1080`
- `SPLATVIZ_ITERS`: `10000`
- `SPLATVIZ_SAVE_EVERY`: `500`
- `SPLATVIZ_DENSIFY_GRAD_THRESH`: `0.0005`
- `MSPLAT_BIN`: auto-detect `~/msplat-env/bin/msplat-train` first, then `PATH`

## Install

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A_frame_safe_blueprint_1080p_package
./install_m68a_frame_safe_blueprint_1080p.zsh
```

## Verify

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A_frame_safe_blueprint_1080p_package
./tools/verify_m68a_patch.zsh
```

## Launch

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A_frame_safe_blueprint_1080p_package
./launch_m68a.zsh
```

## Export Frame-Safe 36 Layout Report

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A_frame_safe_blueprint_1080p_package
./export_m68a_layout_report.zsh
```

Optional:

```bash
INSTALLATION_MODE=Mixed ./export_m68a_layout_report.zsh
OUT=~/Desktop/SplatViz_Exports/custom_layout_report ./export_m68a_layout_report.zsh
```

## Build 1080p Dataset

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A_frame_safe_blueprint_1080p_package
./build_m68a_1080p_dataset.zsh
```

Optional:

```bash
OUT=~/Desktop/SplatViz_Exports/custom_dataset ./build_m68a_1080p_dataset.zsh
```

## Run 10K Msplat

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A_frame_safe_blueprint_1080p_package
./run_m68a_1080p_10k.zsh
```

Optional:

```bash
DATASET=~/Desktop/SplatViz_Exports/splatviz_msplat_dataset_m68a_1080p_frame_safe36_20260528_120000 ./run_m68a_1080p_10k.zsh
OUT=~/Desktop/SplatViz_Exports/custom_result ./run_m68a_1080p_10k.zsh
MSPLAT_BIN=~/msplat-env/bin/msplat-train ./run_m68a_1080p_10k.zsh
```

## Watch A Run

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A_frame_safe_blueprint_1080p_package
./watch_m68a_run.zsh
```

Optional:

```bash
./watch_m68a_run.zsh ~/Desktop/SplatViz_Exports/splatviz_msplat_result_m68a_1080p_10k_20260528_120000
```

## Record Snapshot

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A_frame_safe_blueprint_1080p_package
./record_m68a_snapshot.zsh
```

Optional:

```bash
DATASET=~/Desktop/SplatViz_Exports/splatviz_msplat_dataset_m68a_1080p_frame_safe36_20260528_120000 \
OUT=~/Desktop/SplatViz_Exports/splatviz_msplat_result_m68a_1080p_10k_20260528_121000 \
./record_m68a_snapshot.zsh
```

## Storage Warning

Real report exports, clean image datasets, and msplat result folders can consume substantial disk space. Keep `SPLATVIZ_EXPORT_ROOT` outside the Godot project and clean older runs periodically.

## Notes

- Dataset gating follows subject QC, not volume QC.
- Volume warnings remain planning notes and do not automatically block 1080p training export.
- The report and dataset scripts use the current app logic. They do not patch `Main.gd`.
