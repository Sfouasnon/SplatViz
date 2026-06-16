#!/bin/bash
#
# Build SplatViz.app (standalone macOS app) from the Godot project.
# Double-click this file in Finder, or run it from Terminal.
#
# One-time prerequisite: in the Godot editor, install the macOS export
# templates (Editor > Manage Export Templates > Download and Install).
# See PACKAGING.md.
#
set -uo pipefail

# --- locate this script's folder (repo root) ------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/splatviz_godot"
OUTPUT="$SCRIPT_DIR/SplatViz.app"
PRESET="macOS"

echo "SplatViz macOS packager"
echo "  project: $PROJECT_DIR"
echo "  output:  $OUTPUT"
echo

if [ ! -f "$PROJECT_DIR/project.godot" ]; then
  echo "ERROR: project.godot not found at $PROJECT_DIR" >&2
  exit 1
fi

# --- find the Godot 4.6 binary --------------------------------------------
# Override by exporting GODOT=/path/to/Godot before running.
find_godot() {
  if [ -n "${GODOT:-}" ] && [ -x "$GODOT" ]; then echo "$GODOT"; return; fi
  local candidates=()
  # app bundles in common locations (any name containing "Godot")
  while IFS= read -r app; do
    candidates+=("$app/Contents/MacOS/Godot")
  done < <(ls -d /Applications/*Godot*.app "$HOME/Applications/"*Godot*.app 2>/dev/null)
  candidates+=("/Applications/Godot.app/Contents/MacOS/Godot")
  for c in "${candidates[@]}"; do
    [ -x "$c" ] && { echo "$c"; return; }
  done
  # PATH fallbacks
  command -v godot 2>/dev/null && return
  command -v godot4 2>/dev/null && return
}

GODOT_BIN="$(find_godot)"
if [ -z "${GODOT_BIN:-}" ] || [ ! -x "$GODOT_BIN" ]; then
  echo "ERROR: could not find the Godot editor binary." >&2
  echo "Fix: set GODOT to its path and re-run, e.g." >&2
  echo '  GODOT="/Applications/Godot.app/Contents/MacOS/Godot" bash build_macos_app.command' >&2
  exit 1
fi
echo "Using Godot: $GODOT_BIN"
"$GODOT_BIN" --version 2>/dev/null | head -1
echo

# --- import once, then export ---------------------------------------------
# A headless import pass resolves resources so the first export doesn't ship
# a half-imported project.
echo "Importing project (first run can take a minute)…"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1

echo "Exporting \"$PRESET\" preset…"
rm -rf "$OUTPUT"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "$PRESET" "$OUTPUT"
STATUS=$?

echo
if [ $STATUS -eq 0 ] && [ -d "$OUTPUT" ]; then
  echo "✅ Built: $OUTPUT"
  echo
  echo "First launch (unsigned app, one time):"
  echo "  right-click SplatViz.app > Open > Open,  OR run:"
  echo "  xattr -dr com.apple.quarantine \"$OUTPUT\""
  echo
  open -R "$OUTPUT"
else
  echo "❌ Export failed (status $STATUS)." >&2
  echo "Most common cause: macOS export templates not installed." >&2
  echo "In the Godot editor: Editor > Manage Export Templates > Download and Install." >&2
  echo "Then re-run this script. See PACKAGING.md for details." >&2
  exit 1
fi
