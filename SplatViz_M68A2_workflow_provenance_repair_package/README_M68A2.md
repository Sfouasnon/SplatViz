# SplatViz M68A2 Workflow / Provenance Repair

This package installs the M68A2 workflow/provenance repair on top of the current SplatViz Godot project and verifies it without running msplat, expensive full training, or expensive full export jobs.

## What Changed

1. App-facing release text now uses `SplatViz M68A2`, with centralized `SPLATVIZ_RELEASE_LABEL` and `SPLATVIZ_EXPORT_TAG`.
2. Selected render, full render, layout report, and dataset parent folders now default to M68A2 timestamped names.
3. Render/report/dataset manifests now include `export_timestamp`, `app_release_label`, `export_tag`, `layout_profile`, `render_width`, `render_height`, `camera_count`, `subject_qc_counts`, and `volume_qc_counts`.
4. Still Viewer now recursively discovers nested `png/jpg/jpeg/webp` stills from dataset roots and camera subfolders, keeps natural camera/file ordering, and shows provenance/path status.
5. Camera POV no longer draws a dim full-frame overlay panel. Previous/Next buttons are pushed to the left/right frame edges, with camera status at the frame edge instead of over the subject.
6. Splat View now reports PLY path, count, bounds, preview mode, provenance, and debug-only bounds toggles. The debug preview keeps original point coordinates and removes the extra crop filter that made results look clipped.
7. The performer height scale is now placed beside the robot, and the height labels/title are offset away from the robot/frustum overlap.

## What Did Not Change

1. No msplat training scripts were changed.
2. No expensive full dataset export, full camera export, or msplat training was run by Codex.
3. Frame-safe camera math and dataset gating semantics were not broadened.
4. This patch does not implement true anisotropic 3DGS rasterization or quality judgment inside the viewer.
5. Existing user files are not moved or deleted by the installer.

## Install

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A2_workflow_provenance_repair_package
./install_m68a2_workflow_provenance_repair.zsh
```

## Verify

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A2_workflow_provenance_repair_package
./tools/verify_m68a2_patch.zsh
```

## Launch

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A2_workflow_provenance_repair_package
./launch_m68a2.zsh
```

## Manual UI Test Steps

1. Install and verify M68A2.
2. Launch app.
3. Confirm title says `SplatViz M68A2`.
4. Confirm selected frustum only by default.
5. Open `Camera POV`.
6. Confirm `Previous Camera` and `Next Camera` are at the left/right frame edges and not over subject center.
7. Confirm Camera POV is not dim/desaturated by a full-screen overlay.
8. Open `Still Viewer`.
9. Select a dataset root with nested images.
10. Confirm it finds all PNG/JPG files and Prev/Next works.
11. Export one selected camera render.
12. Confirm the output folder uses the `m68a2` timestamped parent name.
13. Open `Splat View`.
14. Load a PLY.
15. Confirm count, bounds, path, provenance warning, and `Fit To Splat` behavior.

## Known Limitations

1. Splat View is still a debug point preview only.
2. The preview is explicitly labeled `Debug point preview — not final anisotropic 3DGS rasterization.`
3. `Original Coordinates` refers to the points themselves; the preview camera is still auto-framed for inspection.
4. True anisotropic PLY quality and final 3DGS viewer work remain deferred.

## Deferred Viewer Work

True anisotropic 3DGS viewer quality and quality judgment are deferred to the next phase.
