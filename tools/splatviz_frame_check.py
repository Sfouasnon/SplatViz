#!/usr/bin/env python3
"""Print the PLY frame vs the COLMAP camera frame, to find the render mismatch.

Our CPU renderer draws the subject tiny/displaced -> the PLY and the camera
poses are in different scales/origins. This prints the numbers needed to
compute the corrective transform: PLY bounding box + camera-center geometry +
the first camera's intrinsics.

Usage:
  python3 tools/splatviz_frame_check.py --ply <result.ply> --dataset <dataset_root>
"""
from __future__ import annotations
import argparse
import sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from splatviz_cut_diagnosis import read_ply_vertices, read_colmap_sparse, qvec_to_rotmat


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ply", type=Path, required=True)
    ap.add_argument("--dataset", type=Path, required=True)
    args = ap.parse_args()

    ply = read_ply_vertices(args.ply)
    xyz = np.stack([ply["x"], ply["y"], ply["z"]], axis=1)
    finite = np.isfinite(xyz).all(axis=1)
    n_nan = int((~finite).sum())
    xyz = xyz[finite]
    lo, hi = xyz.min(axis=0), xyz.max(axis=0)
    ctr, size = (lo + hi) / 2, hi - lo
    print("=== PLY (gaussian means, finite only) ===")
    print(f"  count   : {len(xyz):,}  (NaN/Inf dropped: {n_nan:,})")
    print(f"  bbox min: [{lo[0]:+.4f}, {lo[1]:+.4f}, {lo[2]:+.4f}]")
    print(f"  bbox max: [{hi[0]:+.4f}, {hi[1]:+.4f}, {hi[2]:+.4f}]")
    print(f"  center  : [{ctr[0]:+.4f}, {ctr[1]:+.4f}, {ctr[2]:+.4f}]")
    print(f"  size    : [{size[0]:.4f}, {size[1]:.4f}, {size[2]:.4f}]  (max {size.max():.4f})")

    cameras, images, pts = read_colmap_sparse(args.dataset / "sparse" / "0")
    centers = []
    for im in images.values():
        R = qvec_to_rotmat(im["qvec"])
        centers.append(-R.T @ im["tvec"])
    C = np.array(centers)
    clo, chi = C.min(axis=0), C.max(axis=0)
    cctr = C.mean(axis=0)
    dist = np.linalg.norm(C - ctr, axis=1)  # camera distance to PLY center
    print("\n=== COLMAP cameras ===")
    print(f"  count       : {len(C)}")
    print(f"  center bbox : min [{clo[0]:+.3f},{clo[1]:+.3f},{clo[2]:+.3f}]  "
          f"max [{chi[0]:+.3f},{chi[1]:+.3f},{chi[2]:+.3f}]")
    print(f"  centroid    : [{cctr[0]:+.3f}, {cctr[1]:+.3f}, {cctr[2]:+.3f}]")
    print(f"  dist to PLY-center: mean {dist.mean():.3f}  min {dist.min():.3f}  max {dist.max():.3f}")
    print(f"  ratio (cam dist / PLY size): {dist.mean() / max(size.max(),1e-9):.2f}")

    if pts.shape[0]:
        plo, phi = pts.min(axis=0), pts.max(axis=0)
        print(f"\n  COLMAP sparse points: {pts.shape[0]}  "
              f"bbox size [{(phi-plo)[0]:.3f},{(phi-plo)[1]:.3f},{(phi-plo)[2]:.3f}]")

    cam0 = list(cameras.values())[0]
    print(f"\n=== first camera intrinsics ===")
    print(f"  model={cam0['model']} W={cam0['width']} H={cam0['height']} params={cam0['params']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
