#!/usr/bin/env python3
"""Compare seed point cloud bbox vs trained result bbox to localize a 'cut'.

Distinguishes:
  H1 (trainer clip): seed spans full object, result is truncated -> Msplat pruning.
  H2 (seed already half): seed itself is truncated -> SplatViz seeding/export geometry.

Usage:
  python3 tools/seed_vs_result_bbox.py --seed <seed.ply> --result <result.ply>
"""
import argparse
from pathlib import Path
import numpy as np

# reuse the binary/ascii PLY parser from the diagnosis tool
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from splatviz_cut_diagnosis import read_ply_vertices


def bbox_report(name: str, ply: dict) -> np.ndarray:
    xyz = np.stack([ply["x"], ply["y"], ply["z"]], axis=1)
    lo, hi = xyz.min(axis=0), xyz.max(axis=0)
    ext = hi - lo
    print(f"\n== {name}  ({len(xyz):,} points) ==")
    for i, ax in enumerate("xyz"):
        # edge density: fraction of points within 5% of each end vs the peak bin
        v = xyz[:, i]
        bins = 64
        hist, edges = np.histogram(v, bins=bins)
        peak = hist.max() if hist.max() else 1
        lo_dens = hist[0] / peak
        hi_dens = hist[-1] / peak
        wall_lo = "WALL" if lo_dens > 0.30 else "taper"
        wall_hi = "WALL" if hi_dens > 0.30 else "taper"
        print(f"  {ax}: [{lo[i]:+.3f}, {hi[i]:+.3f}]  ext={ext[i]:.3f}  "
              f"min-end {lo_dens:4.0%} {wall_lo:5s} | max-end {hi_dens:4.0%} {wall_hi}")
    return ext


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=Path, required=True)
    ap.add_argument("--result", type=Path, required=True)
    args = ap.parse_args()

    seed = bbox_report("SEED  " + args.seed.name, read_ply_vertices(args.seed))
    res = bbox_report("RESULT " + args.result.name, read_ply_vertices(args.result))

    print("\n== per-axis extent ratio (result / seed) ==")
    for i, ax in enumerate("xyz"):
        r = res[i] / seed[i] if seed[i] else float("nan")
        verdict = "  <-- TRUNCATED vs seed" if r < 0.65 else ""
        print(f"  {ax}: {r:5.0%}{verdict}")

    print("\nInterpretation:")
    print("  - If an axis shows a WALL on one end AND result/seed extent < 65% on that axis,")
    print("    the trainer clipped it (H1) -> fix Msplat scene-extent / densify-prune.")
    print("  - If the SEED itself shows a WALL / tiny extent on that axis,")
    print("    the seed cloud was already half (H2) -> fix SplatViz seeding geometry.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
