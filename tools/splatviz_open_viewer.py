#!/usr/bin/env python3
"""Open a trained splat .ply in a local desktop viewer for visual QC.

Phase 3 (Issue 2), visual side. The in-app sprite preview ignores anisotropy
and SH, so it can't be trusted for quality. This opens the .ply in a real local
splat viewer instead.

The viewer app is configurable and remembered between runs (stored in
tools/.splatviz_viewer.json), so after the first call it's a one-liner.

Usage:
  python3 tools/splatviz_open_viewer.py <result.ply> [--app "App Name"]
  python3 tools/splatviz_open_viewer.py <result.ply> --reveal   # just show in Finder
  python3 tools/splatviz_open_viewer.py --set-app "App Name"     # remember an app
"""
from __future__ import annotations
import argparse
import json
import platform
import subprocess
import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parent / ".splatviz_viewer.json"


def _load_cfg() -> dict:
    if CONFIG.exists():
        try:
            return json.loads(CONFIG.read_text())
        except Exception:
            return {}
    return {}


def _save_cfg(cfg: dict) -> None:
    CONFIG.write_text(json.dumps(cfg, indent=2))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ply", type=Path, nargs="?", help="path to the trained .ply")
    ap.add_argument("--app", type=str, default=None, help="local viewer app name (remembered)")
    ap.add_argument("--set-app", type=str, default=None, help="remember an app and exit")
    ap.add_argument("--reveal", action="store_true", help="reveal in file manager instead of opening")
    args = ap.parse_args()

    cfg = _load_cfg()

    if args.set_app:
        cfg["app"] = args.set_app
        _save_cfg(cfg)
        print(f"Saved viewer app: {args.set_app}")
        return 0

    if args.ply is None:
        print("ERROR: provide a .ply path (or use --set-app to configure).", file=sys.stderr)
        return 2
    ply = args.ply
    if not ply.exists():
        print(f"ERROR: no such file: {ply}", file=sys.stderr)
        return 2

    app = args.app or cfg.get("app")
    if args.app:
        cfg["app"] = args.app
        _save_cfg(cfg)

    system = platform.system()

    if args.reveal or not app:
        if system == "Darwin":
            subprocess.run(["open", "-R", str(ply)])
        elif system == "Linux":
            subprocess.run(["xdg-open", str(ply.parent)])
        elif system == "Windows":
            subprocess.run(["explorer", "/select,", str(ply)])
        if not app:
            print("No viewer app configured. Revealed the .ply in your file manager.")
            print('Set one once with:  python3 tools/splatviz_open_viewer.py --set-app "Your Viewer"')
            print("then drag the .ply in, or re-run and it will open automatically.")
        return 0

    print(f"Opening {ply.name} in {app} …")
    if system == "Darwin":
        rc = subprocess.run(["open", "-a", app, str(ply)]).returncode
    elif system == "Linux":
        rc = subprocess.run([app, str(ply)]).returncode
    elif system == "Windows":
        rc = subprocess.run(["cmd", "/c", "start", "", app, str(ply)]).returncode
    else:
        print(f"Unsupported platform: {system}", file=sys.stderr)
        return 2
    if rc != 0:
        print(f"Could not launch '{app}'. Check the app name, or use --reveal to drag it in manually.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
