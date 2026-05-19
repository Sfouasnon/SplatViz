# SplatViz M2.5 Godot Prototype

M2.5 is a targeted cleanup after M2.4 validation.

## What changed

- Patched the included `SplatVizRobot.glb` so every GLB primitive explicitly declares triangle mode. This should improve Godot import reliability and reduce fallback-proxy usage.
- Opaque docked side panels and a repaired top toolbar so UI no longer visually overlays the viewport with transparent clutter.
- Removed noisy always-visible camera labels; only the selected camera is labelled by default.
- Focus mode still transforms all cameras to focus style, but non-selected cameras are now faint context instead of a solid orange/yellow wall.
- Focus envelope opacity reduced.
- Export folder remains outside the project repo by default: `~/Desktop/SplatViz_Exports`.

## Validation targets

1. Confirm the actual robot GLB appears instead of the fallback robot.
2. Confirm Focus mode is readable enough to rotate through the scene.
3. Confirm side panels look docked, not translucent overlays.
4. Confirm clean renders still write to the external export folder.
