# SplatViz M3.2

Msplat workflow cleanup pass.

- Keeps Msplat as a top-toolbar tab only.
- Removes duplicate Msplat controls from the left panel.
- Bottom-docks the Msplat terminal so it no longer covers the performer.
- Adds Browse Dataset Folder… for selecting a SplatViz Msplat dataset root or a clean rendered images folder.
- If an images folder is selected, SplatViz builds a COLMAP-style dataset from those images using the current synthetic camera metadata.
- Uses a TextEdit terminal panel to prevent long terminal output from wrapping into vertical single-character columns.

Msplat remains a smoke-test path. Production layout confidence should continue to be validated against gsplat.
