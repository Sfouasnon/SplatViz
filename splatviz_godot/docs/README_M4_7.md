# SplatViz M4.7

This build fixes the image naming and COLMAP/Msplat folder hierarchy.

## Key changes

- Clean renders now use unique filenames inside each camera folder:
  - `images/C01/CAM01_frame_000001.png`
  - `images/C18/CAM18_frame_000001.png`
- Msplat dataset images are flattened with unique filenames:
  - `images/CAM01_frame_000001.png`
- COLMAP `images.bin` writes the same unique filename as the image `NAME` field.
- Msplat COLMAP input now mirrors images directly into `sparse/0/`:
  - `sparse/0/CAM01_frame_000001.png`
- `sparse/0/images/` is retained only as a compatibility mirror.

## Reason

Msplat resolves COLMAP image names relative to the folder passed to `--input`.
If `images.bin` says `CAM01_frame_000001.png` and SplatViz passes `sparse/0`, the file needs to exist at `sparse/0/CAM01_frame_000001.png`.
