# SplatViz M68A1 Workflow / Usability Hotfix

This package installs a small M68A workflow hotfix on top of the current SplatViz Godot project and verifies it without running msplat, full dataset exports, or full expensive camera export jobs.

## What Changed

1. Output parent folders for selected renders, full renders, layout reports, and dataset exports now use `YYYYMMDD_HHMMSS` timestamps.
2. Render, report, and dataset manifests now include `export_timestamp`, `layout_profile`, `render_width`, `render_height`, `camera_count`, `subject_qc_counts`, and `volume_qc_counts`.
3. Splat Viability camera navigation now refreshes `selected_index`, metadata, selected frustum state, and the viewport consistently.
4. Camera POV now has dedicated Previous / Next buttons, a camera ID/status readout, and safe `[` / `]` shortcuts.
5. The app now starts with the inspector collapsed and selected-frustum-only clutter defaults.
6. A `Show All Frustums` toggle now reveals all frustums while keeping the selected camera emphasized.
7. The Splat Viewer now loads basic ASCII and `binary_little_endian` PLY files for workflow validation and labels the view clearly as a debug preview.
8. Splat View now exposes `Fit To Splat` and `Reset View`.

## What Did Not Change

1. No msplat training scripts were changed.
2. No expensive dataset export, full camera export, or msplat training was run by Codex.
3. Frame-safe camera math and dataset gating semantics were not broadened.
4. This patch does not implement true anisotropic 3DGS rasterization or quality judgment inside the viewer.
5. Existing user files are not moved or deleted by the installer.

## Install

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A1_workflow_usability_hotfix_package
./install_m68a1_workflow_usability_hotfix.zsh
```

## Verify

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A1_workflow_usability_hotfix_package
./tools/verify_m68a1_patch.zsh
```

## Launch

```bash
cd ~/Desktop/SplatViz/SplatViz_M68A1_workflow_usability_hotfix_package
./launch_m68a1.zsh
```

## Manual UI Test Steps

1. Launch the app.
2. Confirm the inspector is collapsed.
3. Confirm only the selected camera frustum is visible at startup.
4. Toggle `Show All Frustums` on and off.
5. Open `Splat Viability`.
6. Test `Previous Camera` and `Next Camera`.
7. Open `Camera POV`.
8. Test `Previous Camera` and `Next Camera`.
9. Export a small manual camera render and confirm the parent output folder name is timestamped.
10. Open `Splat View`.
11. Load a `.ply`.
12. Confirm the file path, count, bounds summary, and `Fit To Splat` behavior.

## Known Limitations

1. Splat View is a debug point preview only.
2. The preview is explicitly labeled `Debug point preview — not final anisotropic 3DGS rasterization.`
3. True anisotropic 3DGS viewer quality is deferred to the next phase.
