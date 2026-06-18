#!/usr/bin/env python3
"""Reproject the COLMAP seed points onto a ground-truth still — the decisive test.

The seed (COLMAP sparse points) is KNOWN-correct geometry: the ~1.76 m robot.
If we project it into a camera with the same convention the CPU renderer uses
and the dots land ON the robot in that camera's ground-truth still, then the
projection + poses are correct — and any bad render is the TRAINED splat's
fault (real geometry failure). If the dots land tiny/offset/rotated, the
projection convention (or the exported poses) is the bug.

Usage:
  python3 tools/splatviz_reproject_overlay.py --dataset <root> [--cameras CAM02,CAM05]
Writes <dataset>/reproject_overlay/CAM##_overlay.png and prints in-frame stats.
"""
from __future__ import annotations
import argparse
import sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from splatviz_cut_diagnosis import read_colmap_sparse, qvec_to_rotmat


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", type=Path, required=True)
    ap.add_argument("--cameras", type=str, default="CAM02,CAM05")
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    from PIL import Image
    cameras, images, pts = read_colmap_sparse(args.dataset / "sparse" / "0")
    if pts.shape[0] == 0:
        print("No COLMAP sparse points found.", file=sys.stderr)
        return 2

    want = {s.strip() for s in args.cameras.split(",") if s.strip()}
    out = args.out or (args.dataset / "reproject_overlay")
    out.mkdir(parents=True, exist_ok=True)

    by_stem = {}
    for im in images.values():
        by_stem[Path(im["name"]).stem.split("_")[0]] = im

    for cam_key in sorted(want):
        im = by_stem.get(cam_key)
        if im is None:
            print(f"  {cam_key}: not found", file=sys.stderr)
            continue
        R = qvec_to_rotmat(im["qvec"])
        t = im["tvec"]
        cam = cameras[im["camera_id"]]
        fx, fy, cx, cy = cam["params"][0], cam["params"][1], cam["params"][2], cam["params"][3]
        W, H = cam["width"], cam["height"]

        p_cam = pts @ R.T + t
        z = p_cam[:, 2]
        front = z > 1e-6
        u = fx * p_cam[front, 0] / z[front] + cx
        v = fy * p_cam[front, 1] / z[front] + cy
        in_frame = (u >= 0) & (u < W) & (v >= 0) & (v < H)
        n_front = int(front.sum())
        n_in = int(in_frame.sum())

        # load GT still and stamp red dots
        gt_path = args.dataset / "images" / im["name"]
        if gt_path.exists():
            img = np.asarray(Image.open(gt_path).convert("RGB")).copy()
        else:
            img = np.zeros((H, W, 3), np.uint8)
        uu = u[in_frame].astype(int)
        vv = v[in_frame].astype(int)
        for du in range(-1, 2):
            for dv in range(-1, 2):
                xs = np.clip(uu + du, 0, W - 1)
                ys = np.clip(vv + dv, 0, H - 1)
                img[ys, xs] = [255, 30, 30]
        Image.fromarray(img).save(str(out / f"{cam_key}_overlay.png"))

        # where do the dots land? (bbox of projected points in pixels)
        if n_in:
            print(f"  {cam_key}: {n_in}/{n_front} seed pts in-frame; "
                  f"u[{uu.min()}-{uu.max()}] v[{vv.min()}-{vv.max()}]  (frame {W}x{H})")
        else:
            print(f"  {cam_key}: 0 in-frame of {n_front} in-front — projection/pose mismatch")

    print(f"\nOverlays: {out}")
    print("Open one: red dots should trace the robot in the still. If they do, the")
    print("projection is correct and the trained splat's geometry is the problem.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
