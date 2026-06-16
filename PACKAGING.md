# Packaging SplatViz as a macOS app

This turns the Godot project into a standalone **SplatViz.app** you can launch
by double-clicking — no need to open the Godot editor.

## One-time setup (export templates)

The exporter needs Godot's macOS export templates installed once. They must
match your editor version (4.6).

1. Open the Godot editor and load this project (`splatviz_godot/project.godot`).
2. Menu: **Editor > Manage Export Templates**.
3. Click **Download and Install**. (~700 MB; takes a minute.)

That's it — you won't repeat this unless you upgrade Godot.

## Build the app

### Option A — double-click (recommended)

In Finder, double-click **`build_macos_app.command`** at the project root.
It locates Godot, exports the `macOS` preset, and produces **`SplatViz.app`**
next to the script, then reveals it in Finder.

If macOS blocks the `.command` file the first time, right-click it >
**Open** > **Open**. If the script can't find Godot, run it from Terminal
pointing at your install:

```
GODOT="/Applications/Godot.app/Contents/MacOS/Godot" bash build_macos_app.command
```

### Option B — from the editor GUI

1. **Project > Export…**
2. The **macOS** preset is already defined (`export_presets.cfg`).
3. Click **Export Project…**, save as `SplatViz.app` at the project root,
   leave "Export With Debug" unchecked.

## First launch (unsigned app)

The app is ad-hoc signed (so it runs on Apple Silicon and Intel) but not
notarized, so Gatekeeper flags it the first time. Either:

- Right-click **SplatViz.app > Open > Open**, or
- Clear the quarantine flag once:
  ```
  xattr -dr com.apple.quarantine SplatViz.app
  ```

After that it launches normally on every run.

## Rebuilding after code changes

Any time you change the project (e.g. `scripts/Main.gd`), just run the build
again — re-run `build_macos_app.command`. The old `SplatViz.app` is replaced.

## About the Python companion tools

The `tools/` scripts (cut diagnosis, holdout metrics, seed/PLY inspectors,
viewer launcher) are command-line utilities, not part of the app bundle. They
run with the Mac's Python 3 from Terminal, e.g.:

```
python3 tools/splatviz_metrics.py --rendered <renders> --ground-truth <gt>
```

They sit alongside the app intentionally: the app plans and exports datasets;
the tools analyze the trained results. If you later want any of them reachable
from inside the app, that's a wiring task in `Main.gd` (shell-out buttons),
separate from packaging.

## Notes

- The preset excludes `*.bak` files and `_archive/` from the bundle.
- Output is a **universal** binary (Apple Silicon + Intel).
- To share with someone else's Mac, they'll hit the same Gatekeeper prompt;
  proper distribution would need an Apple Developer ID + notarization, which we
  can add to the preset later if needed.
