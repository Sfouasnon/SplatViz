#!/usr/bin/env python3
import json
import os
import re
import sys
from pathlib import Path


STEP_RE = re.compile(r"\bstep=(\d+)\b")
SPLATS_RE = re.compile(r"\bsplats=(\d+)\b")
EXIT_RE = re.compile(r"SplatViz run finished with exit code\s+(-?\d+)")
FLOAT_RE = re.compile(r"[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?")


def metric_value(text: str, label: str):
    patterns = [
        rf"^{re.escape(label)}:\s*({FLOAT_RE.pattern})",
        rf"\b{re.escape(label)}[=\s:]+({FLOAT_RE.pattern})\b",
    ]
    for pattern in patterns:
        m = re.search(pattern, text, re.MULTILINE)
        if m:
            try:
                return float(m.group(1))
            except ValueError:
                return None
    return None


def resolve_result(arg: str | None) -> Path:
    if arg:
        p = Path(arg).expanduser().resolve()
        if p.is_file():
            return p.parent
        return p
    export_root = Path(os.environ.get("SPLATVIZ_EXPORT_ROOT", str(Path.home() / "Desktop" / "SplatViz_Exports"))).expanduser()
    candidates = sorted(
        [p for p in export_root.glob("splatviz_msplat_result_m68a_1080p_10k_*") if p.is_dir()],
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    if not candidates:
        raise SystemExit("No M68A result folder found.")
    return candidates[0]


def parse_result(result_dir: Path) -> dict:
    log_path = result_dir / "train.log"
    text = log_path.read_text(errors="replace") if log_path.exists() else ""
    last_step = 0
    last_splats = None
    for match in STEP_RE.finditer(text):
        last_step = max(last_step, int(match.group(1)))
    for match in SPLATS_RE.finditer(text):
        last_splats = int(match.group(1))
    exit_code = None
    m_exit = EXIT_RE.search(text)
    if m_exit:
        exit_code = int(m_exit.group(1))
    metrics = {
        "psnr": metric_value(text, "PSNR"),
        "ssim": metric_value(text, "SSIM"),
        "l1": metric_value(text, "L1"),
    }
    splat_path = result_dir / "splat.ply"
    preflight_path = result_dir / "preflight_summary.json"
    preflight = {}
    if preflight_path.exists():
        try:
            preflight = json.loads(preflight_path.read_text())
        except Exception:
            preflight = {}
    pid_path = result_dir / "train.pid"
    pid = None
    if pid_path.exists():
        try:
            pid = int(pid_path.read_text().strip())
        except Exception:
            pid = None
    return {
        "result_dir": str(result_dir),
        "train_log": str(log_path),
        "log_exists": log_path.exists(),
        "pid": pid,
        "last_step": last_step,
        "last_splats": last_splats,
        "exit_code": exit_code,
        "splat_ply_path": str(splat_path),
        "splat_ply_exists": splat_path.exists(),
        "splat_ply_size_bytes": splat_path.stat().st_size if splat_path.exists() else 0,
        "metrics": metrics,
        "preflight": preflight,
    }


def print_pretty(summary: dict) -> None:
    print(f"Result: {summary['result_dir']}")
    print(f"Log: {summary['train_log']}")
    print(f"PID: {summary.get('pid')}")
    print(f"Last step: {summary.get('last_step')}")
    print(f"Last splats: {summary.get('last_splats')}")
    print(f"Exit code: {summary.get('exit_code')}")
    print(f"splat.ply: {'present' if summary.get('splat_ply_exists') else 'missing'} ({summary.get('splat_ply_size_bytes')} bytes)")
    metrics = summary.get("metrics", {})
    print(f"PSNR: {metrics.get('psnr')}")
    print(f"SSIM: {metrics.get('ssim')}")
    print(f"L1: {metrics.get('l1')}")


def main() -> int:
    pretty = False
    arg = None
    argv = sys.argv[1:]
    if argv and argv[0] == "--pretty":
        pretty = True
        argv = argv[1:]
    if argv:
        arg = argv[0]
    summary = parse_result(resolve_result(arg))
    if pretty:
        print_pretty(summary)
    else:
        print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
