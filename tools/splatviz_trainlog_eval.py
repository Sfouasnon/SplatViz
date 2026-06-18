#!/usr/bin/env python3
"""Parse Msplat training logs to tabulate held-out eval metrics across runs.

Msplat trains with `--eval --test-every 8`, so every run already scores a set
of held-out test views and prints, e.g.:

    Starting msplat-train ... target iterations 10000
    Loaded 31 train cameras, 5 test cameras
    ...
    === Evaluation (5 test views) ===
      PSNR:  11.9996
      SSIM:  0.5308
      L1:    0.1579
      Gaussians: 51,254

This reads one or more such logs and prints a comparison table — the cheapest
possible A/B (e.g. 10K vs 30K) since the numbers already exist in the logs.

Usage:
  python3 tools/splatviz_trainlog_eval.py LOG [LOG ...]
  python3 tools/splatviz_trainlog_eval.py ~/Desktop/SplatViz_Exports/*/train.log
  python3 tools/splatviz_trainlog_eval.py --label 10K a/train.log --label 30K b/train.log
"""
from __future__ import annotations
import argparse
import json
import re
import sys
from pathlib import Path

RE = {
    "iters": re.compile(r"target iterations\s+(\d+)"),
    "cams": re.compile(r"Loaded\s+(\d+)\s+train cameras,\s+(\d+)\s+test cameras"),
    "psnr": re.compile(r"PSNR:\s*([0-9.]+)"),
    "ssim": re.compile(r"SSIM:\s*([0-9.]+)"),
    "l1": re.compile(r"L1:\s*([0-9.]+)"),
    "gauss": re.compile(r"Gaussians:\s*([0-9,]+)"),
    "saved": re.compile(r"Saved\s+(.*\.ply)"),
    "test_views": re.compile(r"Evaluation\s*\((\d+)\s+test views\)"),
}


def parse_log(path: Path) -> dict:
    text = path.read_text(errors="replace")
    d: dict = {"log": str(path)}

    def last(key):
        m = RE[key].findall(text)
        return m[-1] if m else None

    it = last("iters");           d["iters"] = int(it) if it else None
    cams = RE["cams"].findall(text)
    if cams:
        d["train_cams"], d["test_cams"] = int(cams[-1][0]), int(cams[-1][1])
    for k in ("psnr", "ssim", "l1"):
        v = last(k)
        d[k] = float(v) if v else None
    g = last("gauss");            d["gaussians"] = int(g.replace(",", "")) if g else None
    s = last("saved");            d["ply"] = s
    # did the run even reach the eval block?
    d["evaluated"] = d["psnr"] is not None
    return d


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("logs", nargs="*", type=Path)
    ap.add_argument("--label", action="append", nargs=2, metavar=("LABEL", "LOG"),
                    default=[], help="explicit label for a log (repeatable)")
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    entries = []  # (label, Path)
    for label, log in args.label:
        entries.append((label, Path(log)))
    for log in args.logs:
        entries.append((log.parent.name or log.stem, log))
    if not entries:
        print("Provide at least one log path.", file=sys.stderr)
        return 2

    rows = []
    for label, log in entries:
        if not log.exists():
            print(f"WARN: missing {log}", file=sys.stderr)
            continue
        d = parse_log(log)
        d["label"] = label
        rows.append(d)
    if not rows:
        return 2

    # table
    md = ["# Msplat held-out eval — run comparison", ""]
    md.append("| run | iters | train/test cams | PSNR (dB) | SSIM | L1 | Gaussians |")
    md.append("|---|---|---|---|---|---|---|")
    for d in rows:
        tc = f"{d.get('train_cams','?')}/{d.get('test_cams','?')}"
        psnr = f"{d['psnr']:.2f}" if d.get("psnr") is not None else "—"
        ssim = f"{d['ssim']:.4f}" if d.get("ssim") is not None else "—"
        l1 = f"{d['l1']:.4f}" if d.get("l1") is not None else "—"
        g = f"{d['gaussians']:,}" if d.get("gaussians") else "—"
        md.append(f"| {d['label']} | {d.get('iters','?')} | {tc} | {psnr} | {ssim} | {l1} | {g} |")
    md.append("")

    # deltas vs first evaluated run
    base = next((d for d in rows if d.get("psnr") is not None), None)
    if base:
        md += ["## Deltas vs " + base["label"], ""]
        for d in rows:
            if d is base or d.get("psnr") is None:
                continue
            dp = d["psnr"] - base["psnr"]
            ds = (d["ssim"] - base["ssim"]) if (d.get("ssim") and base.get("ssim")) else float("nan")
            md.append(f"- **{d['label']}**: {dp:+.2f} dB PSNR, {ds:+.4f} SSIM vs {base['label']}")
        md.append("")
        # quality flag
        worst = min(d["psnr"] for d in rows if d.get("psnr") is not None)
        if worst < 18:
            md.append(f"> ⚠️ Held-out PSNR as low as {worst:.1f} dB — well below the ~28+ dB "
                      f"a well-generalizing 3DGS reaches. Investigate alignment/coverage "
                      f"before reading too much into iteration deltas.")
            md.append("")

    out_dir = args.out or Path.cwd()
    (out_dir / "TRAINLOG_EVAL.md").write_text("\n".join(md) + "\n")
    (out_dir / "trainlog_eval.json").write_text(json.dumps(rows, indent=2))
    print("\n".join(md))
    print(f"\nWritten: {out_dir}/TRAINLOG_EVAL.md  +  trainlog_eval.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
