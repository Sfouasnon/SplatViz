#!/bin/zsh
emulate -L zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
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

GODOT=$(detect_godot) || {
	print -u2 "Could not find Godot. Set GODOT_BIN or install Godot."
	exit 1
}

exec "${GODOT}" --path "${SPLATVIZ_PROJECT}"
