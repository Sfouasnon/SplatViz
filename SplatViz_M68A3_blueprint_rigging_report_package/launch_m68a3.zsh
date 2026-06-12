#!/bin/zsh
emulate -L zsh
set -euo pipefail

: ${SPLATVIZ_PROJECT:=$HOME/Desktop/SplatViz/splatviz_godot}
: ${GODOT_BIN:=/Applications/Godot.app/Contents/MacOS/Godot}

exec "${GODOT_BIN}" --path "${SPLATVIZ_PROJECT}"
