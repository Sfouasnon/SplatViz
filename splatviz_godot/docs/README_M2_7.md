# SplatViz M2.7

Targeted cleanup after M2.6 validation.

## Changes

- Focus DOF/focus-plane numbers moved out of the 3D frustum and into a bottom-right Focus Readout panel.
- Focus inspector now contains only focus-relevant information: distance to subject, sensor/capture specs, recommended focus target, critical sharpness zone, DoF, and guidance.
- Focus overlay opacity reduced again for readability.
- Splat Viability overlay opacity reduced.
- Splat Viability now supports two modes:
  - All frustums
  - Selected only
- Top toolbar actions remain wired:
  - Scene -> Rig / Lighting
  - Cameras -> Camera POV
  - Analysis -> Compare Layouts
  - Export -> Choose Export Folder
  - Help -> navigation help
- Clean exports continue to write outside the project repo by default.

## Validation Goals

1. Confirm the Focus Readout appears at bottom right in Focus mode.
2. Confirm no focus numbers are drawn inside 3D frustums.
3. Confirm Splat Viability all/selected-only frustum toggle works.
4. Confirm Analysis opens the Compare Layouts panel.
5. Confirm clean renders still export correctly.
