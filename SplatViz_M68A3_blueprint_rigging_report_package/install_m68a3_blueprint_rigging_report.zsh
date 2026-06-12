#!/bin/zsh
emulate -L zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PAYLOAD="${SCRIPT_DIR}/payload/Main.gd"
TARGET="${HOME}/Desktop/SplatViz/splatviz_godot/scripts/Main.gd"
BACKUP="${TARGET}.m68a3_backup"

if [[ ! -f "${PAYLOAD}" ]]; then
	print -u2 "Missing payload: ${PAYLOAD}"
	exit 1
fi

if [[ ! -f "${TARGET}" ]]; then
	print -u2 "Missing target file: ${TARGET}"
	exit 1
fi

if [[ ! -f "${BACKUP}" ]]; then
	cp "${TARGET}" "${BACKUP}"
	print "Backup created: ${BACKUP}"
else
	print "Backup already exists: ${BACKUP}"
fi

cp "${PAYLOAD}" "${TARGET}"
print "Installed M68A3 blueprint / rigging report patch to ${TARGET}"
print ""
print "Next commands:"
print "  cd ${SCRIPT_DIR}"
print "  ./tools/verify_m68a3_patch.zsh"
print "  ./launch_m68a3.zsh"
