#!/bin/zsh
emulate -L zsh
set -euo pipefail

: ${SPLATVIZ_PROJECT:=$HOME/Desktop/SplatViz/splatviz_godot}

detect_godot() {
  if [[ -n "${GODOT_BIN:-}" && -x "${GODOT_BIN}" ]]; then
    print -- "${GODOT_BIN}"
    return 0
  fi
  local candidate
  for candidate in \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "$(command -v godot 2>/dev/null || true)"
  do
    if [[ -n "${candidate}" && -x "${candidate}" ]]; then
      print -- "${candidate}"
      return 0
    fi
  done
  return 1
}

if [[ ! -d "${SPLATVIZ_PROJECT}" ]]; then
  print -u2 "Missing Godot project at ${SPLATVIZ_PROJECT}"
  exit 1
fi

GODOT=$(detect_godot) || {
  print -u2 "Could not find Godot. Set GODOT_BIN or install Godot."
  exit 1
}

nohup "${GODOT}" --path "${SPLATVIZ_PROJECT}" >/dev/null 2>&1 &
print "Launched SplatViz from ${SPLATVIZ_PROJECT}"
