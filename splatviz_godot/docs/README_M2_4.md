# SplatViz M2.4 Godot Prototype

M2.4 implements the accepted UI direction from the SplatViz mockup.

## Changes

- Removes the ambiguous Standard mode.
- Adds docked left controls and right Inspector structure modeled after a production 3D tool.
- Adds an Inspector toggle handle.
- Adds persistent Prev Cam / Next Cam controls for Camera POV review.
- Focus mode now draws all cameras in focus-style visualization:
  - orange = too near
  - yellow = acceptable
  - green = critical sharpness
  - blue = performer focus envelope
- Splat Viability mode now draws all camera frustums with unique colors and clips them at the subject, rather than crossing the whole scene.
- Clean renders now export outside the project repo by default:
  - `~/Desktop/SplatViz_Exports/splatviz_clean_m24/images/C##/frame_000001.png`
- Adds Choose Export Folder dialog.
- Keeps SplatVizRobot.glb as the canonical subject and improves the fallback robot if the GLB import fails.

## Validation status

This build is still a prototype. SplatViz visualization is a prediction layer; production conclusions require clean renders and gsplat validation.
