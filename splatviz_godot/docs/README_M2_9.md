# SplatViz M2.9

M2.9 focuses on UI layout stabilization and first camera editing controls.

## Changes
- Docked panels are re-laid out every frame so the right inspector stays pinned to the far right and gaps from window resizing are reduced.
- Analysis comparison copy is reorganized into professional sections: Angle Density, Resolution Decision, Roll Strategy, and Redundancy Policy.
- Added Edit Camera mode.
- Edit Camera controls support inward/outward moves, azimuth nudges, height nudges, roll toggle, and reset layout.
- Selected camera edits update focus distance, projected px/cm, frustum geometry, and inspector text immediately.
- Camera top-bar button now opens Edit Camera.
- Focus readout keeps the color legend: ORANGE too near, YELLOW acceptable, GREEN critical sharpness.

## Notes
- Edit Mode is button-based in this build. A true 3D transform gizmo/drag handle should follow once this behavior is validated.
- SplatViz predictions still require msplat/gsplat validation.
