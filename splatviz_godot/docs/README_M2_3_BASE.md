# SplatViz M2.3 Godot Prototype

M2.3 adds the uploaded SplatVizRobot.glb as the default 5 ft 11 in subject and changes camera still export to clean 1080p 16:9 renders. Clean renders hide frustums, diagnostic overlays, camera proxies, rig proxies, and the blue focus envelope before saving PNGs.

## Run

```zsh
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/sfouasnon/Desktop/SplatViz/splatviz_godot
```

## Render output

Clean image paths:

```text
synthetic_stills/clean/images/C01/frame_000001.png
synthetic_stills/clean/images/C02/frame_000001.png
...
synthetic_stills/clean/render_manifest.json
```

Resolution: 1920 x 1080, matching the source 16:9 aspect ratio.

## Validation note

Msplat is a local smoke test. Production claims still need gsplat validation.
