#!/usr/bin/env python3
"""Layout optimization — rank camera layouts by how well their splat reconstructs
a FIXED synthetic validation viewpoint set.

This is the core SplatViz question: which camera layout is optimal for this stage
and performer? Because the scene is synthetic, we can render a fixed set of
"judge" viewpoints (a validation dome) as ground truth, then score every
candidate layout's trained splat against that SAME set — a fair comparison that
real-world capture can't do.

Workflow:
  1. In SplatViz, build a fixed VALIDATION layout (a dome/ring of viewpoints
     distinct from your candidate layouts) and export it as a dataset. Its
     images/ are the GT yardstick; its sparse/0 gives the poses to render from.
  2. For each candidate layout: export its training dataset, train Msplat with
     the locked config (--keep-crs --num-iters 30000 --densify-grad-thresh 0.0005),
     producing one PLY per layout.
  3. Run this tool: it renders the validation poses from each layout's PLY and
     scores them against the validation GT, then ranks the layouts.

Usage:
  python3 tools/splatviz_layout_eval.py \
      --validation <validation_dataset_root> \
      --layout 36cam  /path/to/layout_36cam.ply \
      --layout 24cam  /path/to/layout_24cam.ply \
      --layout 48cam  /path/to/layout_48cam.ply \
      [--scale 0.5]   # render at half-res for speed (relative scores hold)
      [--out ~/Desktop/layout_eval]
"""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from splatviz_cut_diagnosis import read_ply_vertices, read_colmap_sparse, qvec_to_rotmat
from splatviz_cpu_render import decode_gaussians, render_view, intrinsics_from_colmap
from splatviz_metrics import psnr, ssim, _load_rgb01, _match_size


def eval_layout(ply_path: Path, val_dataset: Path, scale: float) -> dict:
    g = decode_gaussians(read_ply_vertices(ply_path))
    cameras, images, _ = read_colmap_sparse(val_dataset / "sparse" / "0")
    rows = []
    for im in sorted(images.values(), key=lambda i: i["name"]):
        gt_path = val_dataset / "images" / im["name"]
        if not gt_path.exists():
            continue
        R = qvec_to_rotmat(im["qvec"]); t = im["tvec"]
        cam = cameras[im["camera_id"]]
        fx, fy, cx, cy = intrinsics_from_colmap(cam)
        W, H = cam["width"], cam["height"]
        if scale != 1.0:
            W, H = int(W * scale), int(H * scale)
            fx, fy, cx, cy = fx * scale, fy * scale, cx * scale, cy * scale
        rgb = render_view(g, R, t, fx, fy, cx, cy, W, H)
        gt = _load_rgb01(gt_path)
        rgb, gt, _ = _match_size(rgb, gt)
        rows.append({"view": Path(im["name"]).stem,
                     "psnr": psnr(rgb, gt), "ssim": ssim(rgb, gt)})
    if not rows:
        return {"n": 0}
    fin = [r["psnr"] for r in rows if np.isfinite(r["psnr"])]
    return {
        "n": len(rows),
        "psnr_mean": float(np.mean(fin)) if fin else float("nan"),
        "psnr_min": float(np.min(fin)) if fin else float("nan"),
        "ssim_mean": float(np.mean([r["ssim"] for r in rows])),
        "per_view": rows,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--validation", type=Path, required=True,
                    help="validation dataset root (sparse/0 + images/)")
    ap.add_argument("--layout", action="append", nargs=2, metavar=("LABEL", "PLY"),
                    required=True, help="repeatable: a candidate layout's label + trained PLY")
    ap.add_argument("--scale", type=float, default=0.5, help="render scale for speed (default 0.5)")
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    results = []
    for label, ply in args.layout:
        print(f"Evaluating layout '{label}' …")
        r = eval_layout(Path(ply), args.validation, args.scale)
        r["label"] = label
        results.append(r)
        if r["n"]:
            print(f"  {label}: PSNR {r['psnr_mean']:.2f} (min {r['psnr_min']:.2f})  "
                  f"SSIM {r['ssim_mean']:.4f}  over {r['n']} validation views")

    ranked = sorted([r for r in results if r.get("n")],
                    key=lambda r: r["psnr_mean"], reverse=True)

    md = ["# SplatViz layout optimization", "",
          f"Each layout's splat scored against {ranked[0]['n'] if ranked else 0} "
          f"fixed validation viewpoints (held out from all layouts).", "",
          "| rank | layout | PSNR (dB) | min PSNR | SSIM |", "|---|---|---|---|---|"]
    for i, r in enumerate(ranked, 1):
        md.append(f"| {i} | {r['label']} | {r['psnr_mean']:.2f} | "
                  f"{r['psnr_min']:.2f} | {r['ssim_mean']:.4f} |")
    md.append("")
    if ranked:
        best = ranked[0]
        md.append(f"**Optimal layout: {best['label']}** "
                  f"({best['psnr_mean']:.2f} dB mean on the validation dome).")
        if len(ranked) > 1:
            d = best["psnr_mean"] - ranked[1]["psnr_mean"]
            md.append(f"Margin over 2nd ({ranked[1]['label']}): {d:+.2f} dB.")
            if d < 0.3:
                md.append("_Margin is within noise — these layouts are effectively equivalent; "
                          "prefer the cheaper/simpler rig._")

    out_dir = args.out or Path.cwd() / "layout_eval"
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "LAYOUT_EVAL.md").write_text("\n".join(md) + "\n")
    (out_dir / "layout_eval.json").write_text(json.dumps(results, indent=2))
    print("\n".join(md))
    print(f"\nWritten: {out_dir}/LAYOUT_EVAL.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
