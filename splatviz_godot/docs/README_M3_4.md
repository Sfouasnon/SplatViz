# SplatViz M3.4

- Moves Splat Viability add-view warnings out of the 3D subject area into the bottom readout panel.
- Renames the separate reconstruction window to Msplat Terminal.
- Adds Nerfstudio-style `transforms.json` export because msplat rejects text-only COLMAP `cameras.txt/images.txt` datasets and expects either COLMAP binary, Nerfstudio, or Polycam input.
- Keeps COLMAP text files as debug metadata only.
- Existing clean image folders can be converted into an Msplat dataset with `transforms.json`.
