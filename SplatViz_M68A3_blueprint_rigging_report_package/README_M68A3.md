# SplatViz M68A3 Blueprint / Rigging Report Package

1. What changed.

- The layout report now reads like a rigging/build packet instead of a QC/debug export.
- The report adds production specs, build mode, stage metadata, performer height, production camera labels, and larger plan/elevation drawings.
- The index and build summary now foreground capture/stage/performer specs, not PASS/WARNING/FAIL/INVALID boxes.
- The camera schedule now shows field-use install data first and keeps internal IDs as a cross-reference.
- The report defaults to `Sound Stage / Wood Floor` preview context and adds visible performer height rulers on the front and side elevations.
- The 3D height scale was also moved beside the robot and the height text was repositioned to reduce occlusion.

2. What did not change.

- Frame-safe camera math was not rewritten.
- Dataset gating semantics were not changed.
- Msplat training scripts and msplat source were not changed.
- No true anisotropic 3DGS renderer was added.
- Training/dataset exports remain clean; rigging visuals are report-facing only.

3. Install command.

```zsh
cd ~/Desktop/SplatViz/SplatViz_M68A3_blueprint_rigging_report_package
./install_m68a3_blueprint_rigging_report.zsh
```

4. Verify command.

```zsh
cd ~/Desktop/SplatViz/SplatViz_M68A3_blueprint_rigging_report_package
./tools/verify_m68a3_patch.zsh
```

5. Launch command.

```zsh
cd ~/Desktop/SplatViz/SplatViz_M68A3_blueprint_rigging_report_package
./launch_m68a3.zsh
```

6. Manual UI test steps.

1. Launch SplatViz.
2. Open Settings.
3. Set Capture Specs, Stage Specs, Performer Specs.
4. Set performer/subject height.
5. Set Camera Label Scheme to `AA-ID 36 Camera Grid`.
6. Export Layout Report.
7. Open `index.html`.
8. Confirm index reads like a build summary.
9. Open Top Plan and confirm drawing is large with AA-ID labels.
10. Open Front/Side Elevation and confirm height scale.
11. Open Camera Schedule and confirm it is a rigging schedule, not a QC debug report.
12. Confirm `camera_layout.json` still contains QC/provenance data.

7. How to set production specs.

- Use the top-bar `Settings` button.
- Edit `Capture Specs`, `Stage Specs`, `Performer Specs`, `Stage Name`, `Floor Type / Surface`, `Build Mode`, and `Performer / Subject Height (m)`.
- Click `Apply` before exporting the report.

8. How to choose camera label scheme.

- Open `Settings`.
- Choose `C01-C36`, `AA-ID 36 Camera Grid`, or `Custom comma-separated labels`.
- For custom labels, provide a comma-separated list matching the current camera count exactly.
- If the count does not match, the report falls back safely and records a warning in the payload.

9. Known limitations.

- The live app title remains `SplatViz M68A2`; this patch is focused on blueprint/report cleanup rather than a wider app relabel.
- Rigging-facing HTML suppresses QC/debug emphasis, but `camera_layout.json` and the CSV still preserve technical cross-reference data.
- The packet is a layout and aiming reference, not a stamped engineering document.
- True PLY quality inspection and anisotropic viewer work remain deferred.

Reminder: true anisotropic 3DGS viewer quality is deferred to the next phase.
