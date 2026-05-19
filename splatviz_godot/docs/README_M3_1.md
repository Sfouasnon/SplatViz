# SplatViz M3.1

Adds an in-app Msplat terminal tab.

## New workflow

1. Open the Msplat tab from the top toolbar or left panel.
2. Click **Find Latest Dataset** or **Export Dataset**.
3. Click **Run Smoke Test**.
4. Watch `train.log` in the terminal panel.
5. Click **Load Latest Splat** when `splat.ply` exists.

The app still calls the external Python environment at `~/msplat-env/bin/msplat-train`; this keeps Python isolated from the Godot runtime.

Msplat remains a local smoke test. Production conclusions remain gsplat-validation required.
