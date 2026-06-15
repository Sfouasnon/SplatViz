#!/usr/bin/env python3
"""SplatViz holdout split — reserve cameras for objective quality evaluation.

Phase 3 (Issue 2). Held-out cameras are excluded from training; after training
you render the splat at those poses and score them with splatviz_metrics.py.
Because they were never trained on, the score is a true generalization signal.

The strategy is TOGGLEABLE via --mode:
  spread   N spatially-spread cameras via farthest-point sampling (default, N=4)
  single   one camera (most central / index 0)
  dense    N spread cameras with a larger default (N=8)
  none     no holdout (score on training views — measures memorization)
  explicit use exactly the cameras named in --cameras

Reads cameras from transforms.json (preferred: carries intrinsics + poses) or,
if absent, from a COLMAP sparse/0 model. Writes:
  <out>/holdout_manifest.json   held-out cams: name, image, intrinsics, pose, position
  <out>/holdout_gt/             copies of the held-out ground-truth stills
  <out>/train_transforms.json   transforms.json with held-out frames removed
  <out>/train_list.txt          training image filenames
  <out>/holdout_list.txt        held-out image filenames

Usage:
  python3 tools/splatviz_holdout_split.py --dataset <dataset_root> \
      [--mode spread] [--count 4] [--cameras CAM05,CAM12] [--out <dir>]
"""
from __future__ import annotations
import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    from splatviz_cut_diagnosis import read_colmap_sparse, qvec_to_rotmat
except Exception:
    read_colmap_sparse = None
    qvec_to_rotmat = None


def _cams_from_transforms(tj: dict) -> list[dict]:
    cams = []
    for fr in tj.get("frames", []):
        M = np.asarray(fr["transform_matrix"], dtype=float)  # camera-to-world
        pos = M[:3, 3]
        cams.append({
            "name": Path(fr.get("file_path", "")).name,
            "image": fr.get("file_path", ""),
            "position": pos.tolist(),
            "intrinsics": {k: fr.get(k) for k in ("fl_x", "fl_y", "cx", "cy", "w", "h")},
            "transform_matrix": fr["transform_matrix"],
            "_frame": fr,
        })
    return cams


def _cams_from_colmap(sparse_dir: Path) -> list[dict]:
    cameras, images, _ = read_colmap_sparse(sparse_dir)
    cams = []
    for img in images.values():
        R = qvec_to_rotmat(img["qvec"])          # world->cam
        t = img["tvec"]
        center = -R.T @ t                         # camera center in world
        cams.append({
            "name": Path(img["name"]).name,
            "image": img["name"],
            "position": center.tolist(),
            "intrinsics": cameras.get(img["camera_id"], {}),
            "transform_matrix": None,
            "_frame": None,
        })
    return cams


def _farthest_point_select(cams: list[dict], k: int) -> list[int]:
    """Indices of k cameras maximally spread by 3D position (farthest-point sampling)."""
    P = np.array([c["position"] for c in cams], dtype=float)
    n = len(cams)
    if k >= n:
        return list(range(n))
    # seed with the camera farthest from the centroid
    centroid = P.mean(axis=0)
    first = int(np.argmax(np.linalg.norm(P - centroid, axis=1)))
    chosen = [first]
    d = np.linalg.norm(P - P[first], axis=1)
    while len(chosen) < k:
        nxt = int(np.argmax(d))
        chosen.append(nxt)
        d = np.minimum(d, np.linalg.norm(P - P[nxt], axis=1))
    return sorted(chosen)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dataset", type=Path, required=True)
    ap.add_argument("--mode", choices=["spread", "single", "dense", "none", "explicit"],
                    default="spread")
    ap.add_argument("--count", type=int, default=None, help="override holdout count")
    ap.add_argument("--cameras", type=str, default="", help="comma list for --mode explicit")
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    ds = args.dataset
    tj_path = ds / "transforms.json"
    if tj_path.exists():
        tj = json.loads(tj_path.read_text())
        cams = _cams_from_transforms(tj)
        source = "transforms.json"
    elif (ds / "sparse" / "0").exists() and read_colmap_sparse:
        tj = None
        cams = _cams_from_colmap(ds / "sparse" / "0")
        source = "colmap sparse/0"
    else:
        print(f"ERROR: no transforms.json or sparse/0 under {ds}", file=sys.stderr)
        return 2
    if not cams:
        print("ERROR: no cameras found in dataset", file=sys.stderr)
        return 2

    # choose holdout indices
    if args.mode == "none":
        hold_idx = []
    elif args.mode == "explicit":
        want = {s.strip() for s in args.cameras.split(",") if s.strip()}
        hold_idx = [i for i, c in enumerate(cams)
                    if c["name"] in want or Path(c["name"]).stem in want]
        if not hold_idx:
            print(f"ERROR: none of {sorted(want)} matched dataset cameras", file=sys.stderr)
            print(f"  available (sample): {[c['name'] for c in cams[:6]]}", file=sys.stderr)
            return 2
    else:
        default_k = {"spread": 4, "single": 1, "dense": 8}[args.mode]
        k = args.count if args.count is not None else default_k
        k = max(1, min(k, len(cams) - 1))  # always leave training views
        hold_idx = _farthest_point_select(cams, k)

    hold = set(hold_idx)
    holdout = [cams[i] for i in hold_idx]
    train = [c for i, c in enumerate(cams) if i not in hold]

    out = args.out or (ds / "holdout_eval")
    out.mkdir(parents=True, exist_ok=True)

    # manifest
    manifest = {
        "dataset": str(ds),
        "source": source,
        "mode": args.mode,
        "holdout_count": len(holdout),
        "train_count": len(train),
        "holdout_cameras": [{k: c[k] for k in ("name", "image", "position",
                                               "intrinsics", "transform_matrix")}
                            for c in holdout],
    }
    (out / "holdout_manifest.json").write_text(json.dumps(manifest, indent=2))
    (out / "holdout_list.txt").write_text("\n".join(c["name"] for c in holdout) + "\n")
    (out / "train_list.txt").write_text("\n".join(c["name"] for c in train) + "\n")

    # training transforms.json with holdout removed
    if tj is not None:
        train_tj = dict(tj)
        hold_names = {c["name"] for c in holdout}
        train_tj["frames"] = [fr for fr in tj["frames"]
                              if Path(fr.get("file_path", "")).name not in hold_names]
        train_tj["splatviz_holdout_removed"] = sorted(hold_names)
        (out / "train_transforms.json").write_text(json.dumps(train_tj, indent=2))

    # stage held-out ground-truth stills for the metrics tool
    gt_dir = out / "holdout_gt"
    gt_dir.mkdir(exist_ok=True)
    copied = 0
    for c in holdout:
        src = ds / c["image"]
        if not src.exists():
            src = ds / "images" / c["name"]
        if src.exists():
            shutil.copy2(src, gt_dir / c["name"])
            copied += 1

    print(f"mode={args.mode}  holdout={len(holdout)}  train={len(train)}  (source: {source})")
    print("held-out cameras:", ", ".join(c["name"] for c in holdout) or "(none)")
    print(f"GT stills staged: {copied}/{len(holdout)} -> {gt_dir}")
    print(f"manifest: {out/'holdout_manifest.json'}")
    if tj is not None:
        print(f"train transforms: {out/'train_transforms.json'}")
    print("\nNext: train on the training set, render the splat at the held-out poses,")
    print(f"then: python3 tools/splatviz_metrics.py --rendered <renders> "
          f"--ground-truth {gt_dir} --manifest {out/'holdout_manifest.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
