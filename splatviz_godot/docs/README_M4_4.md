# SplatViz M4.4

Fixes COLMAP image path names for Msplat. M4.3 wrote `images/C##.png` into `images.bin`, while Msplat resolves COLMAP image names as `<sparse input>/images/<NAME>`, producing `images/images/C##.png`. M4.4 writes `C##.png` in `images.bin` and mirrors PNGs under `sparse/0/images/`.

Also logs `colmap_resolved_image_C01=present/MISSING` before launching Msplat.
