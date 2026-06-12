#!/bin/zsh
emulate -L zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
: ${SPLATVIZ_PROJECT:=$HOME/Desktop/SplatViz/splatviz_godot}

MAIN_GD="${SPLATVIZ_PROJECT}/scripts/Main.gd"
PAYLOAD_MAIN="${SCRIPT_DIR}/payload/Main.gd"
BACKUP_MAIN="${SPLATVIZ_PROJECT}/scripts/Main.gd.bak_m68a1_workflow_usability_hotfix"

if [[ ! -f "${MAIN_GD}" ]]; then
	print -u2 "Missing target file: ${MAIN_GD}"
	exit 1
fi

if [[ ! -f "${PAYLOAD_MAIN}" ]]; then
	print -u2 "Missing packaged payload: ${PAYLOAD_MAIN}"
	exit 1
fi

if [[ ! -f "${BACKUP_MAIN}" ]]; then
	cp -p "${MAIN_GD}" "${BACKUP_MAIN}"
	print "Backup created: ${BACKUP_MAIN}"
else
	print "Backup already exists: ${BACKUP_MAIN}"
fi

if cmp -s "${PAYLOAD_MAIN}" "${MAIN_GD}"; then
	print "Main.gd already matches the packaged M68A1 hotfix."
else
	cp -p "${PAYLOAD_MAIN}" "${MAIN_GD}"
	print "Patched: ${MAIN_GD}"
fi

print ""
print "Next commands:"
print "  cd ${SCRIPT_DIR}"
print "  ./tools/verify_m68a1_patch.zsh"
print "  ./launch_m68a1.zsh"
