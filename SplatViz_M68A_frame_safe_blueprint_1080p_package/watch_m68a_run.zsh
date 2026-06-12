#!/bin/zsh
emulate -L zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PACKAGE_ROOT=${SCRIPT_DIR}
: ${SPLATVIZ_EXPORT_ROOT:=$HOME/Desktop/SplatViz_Exports}

result_dir="${1:-}"
if [[ -z "${result_dir}" ]]; then
  result_dir=$(python3 - <<'PY' "${SPLATVIZ_EXPORT_ROOT}"
from pathlib import Path
import sys
root = Path(sys.argv[1]).expanduser()
candidates = sorted(
    [p for p in root.glob("splatviz_msplat_result_m68a_1080p_10k_*") if p.is_dir()],
    key=lambda p: p.stat().st_mtime,
    reverse=True,
)
print(candidates[0] if candidates else "")
PY
)
fi

if [[ -z "${result_dir}" || ! -d "${result_dir}" ]]; then
  print -u2 "No result folder found. Pass one explicitly or run the 10K script first."
  exit 1
fi

log_path="${result_dir}/train.log"
pid_path="${result_dir}/train.pid"
splat_path="${result_dir}/splat.ply"

while true; do
  clear
  print "Watching ${result_dir}"
  if [[ -f "${pid_path}" ]]; then
    pid=$(<"${pid_path}")
    if ps -p "${pid}" >/dev/null 2>&1; then
      print "Process: running (PID ${pid})"
    else
      print "Process: not running (stale PID ${pid})"
    fi
  else
    print "Process: PID file not found"
  fi

  if [[ -f "${log_path}" ]]; then
    print ""
    python3 "${PACKAGE_ROOT}/tools/m68a_parse_train_log.py" --pretty "${result_dir}"
    print ""
    print "Recent train.log"
    tail -n 20 "${log_path}" || true
  else
    print ""
    print "train.log not found"
  fi

  if [[ -f "${splat_path}" ]]; then
    print ""
    print "splat.ply: present ($(stat -f %z "${splat_path}") bytes)"
  else
    print ""
    print "splat.ply: missing"
  fi

  sleep 2
done
