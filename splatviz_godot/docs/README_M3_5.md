# SplatViz M3.5

Fixes Msplat dataset readiness and removes weak-view text from the 3D subject area.

- Run Msplat now verifies that `transforms.json` exists at the dataset root before launching.
- If the selected dataset is not ready, SplatViz exports a fresh Nerfstudio-style dataset automatically.
- The Msplat log now records dataset validation details before running.
- Splat Viability weak-view/add-view warnings remain in the bottom readout, not over the subject.
