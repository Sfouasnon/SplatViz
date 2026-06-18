#!/usr/bin/env python3
"""SplatViz A/B run comparator — settle 10K vs 30K (etc.) with numbers.

Phase 3 quality experiments. Scores two or more training runs against the SAME
held-out ground-truth views and prints a side-by-side comparison with deltas,
so "30K looks better" becomes "+2.1 dB PSNR, +0.03 SSIM, -0.04 LPIPS on the
held-out views, and the gain is concentrated on the lower-tier cameras."

Reuses the tested metric functions from splatviz_metrics.py (PSNR/SSIM always,
LPIPS if torch+lpips installed).

Each --run is a label plus its rendered-holdout dir plus the ground-truth dir
(the GT is usually identical across runs — the same held-out cameras):

  python3 tools/splatviz_ab_compare.py \
      --run 10K  /path/renders_10k  /path/holdout_gt \
      --run 30K  /path/renders_30k  /path/holdout_gt \
      [--manifest holdout_manifest.json]   # per-camera spatial labels
      [--out  /path/compare_dir]

The first --run is the baseline; deltas are reported relative to it.
"""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from splatviz_metrics import (
    psnr, ssim, _load_rgb01, _index_dir, _match_size, _LPIPS,
)


def _score_run(rendered: Path, gt: Path, lp) -> dict:
    ren, gtd = _index_dir(rendered), _index_dir(gt)
    common = sorted(set(ren) & set(gtd))
    per = {}
    for stem in common:
        a = _load_rgb01(ren[stem])
        b = _load_rgb01(gtd[stem])
        a, b, _ = _match_size(a, b)
        per[stem] = {
            "psnr": psnr(a, b),
            "ssim": ssim(a, b),
            "lpips": (lp.score(a, b) if lp.ok else None),
        }
    return per


def _agg(per: dict) -> dict:
    finite = [v["psnr"] for v in per.values() if np.isfinite(v["psnr"])]
    out = {
        "n": len(per),
        "psnr_mean": float(np.mean(finite)) if finite else float("inf"),
        "ssim_mean": float(np.mean([v["ssim"] for v in per.values()])) if per else 0.0,
    }
    lp = [v["lpips"] for v in per.values() if v["lpips"] is not None]
    if lp:
        out["lpips_mean"] = float(np.mean(lp))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--run", action="append", nargs=3, metavar=("LABEL", "RENDERED", "GT"),
                    required=True, help="repeatable; first is the baseline")
    ap.add_argument("--manifest", type=Path, default=None)
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    if len(args.run) < 2:
        print("Provide at least two --run entries to compare.", file=sys.stderr)
        return 2

    lp = _LPIPS()

    runs = []  # list of (label, per_view, agg)
    for label, ren, gt in args.run:
        per = _score_run(Path(ren), Path(gt), lp)
        if not per:
            print(f"ERROR: run '{label}' had no matching views between\n"
                  f"  {ren}\n  {gt}", file=sys.stderr)
            return 2
        runs.append((label, per, _agg(per)))

    base_label, base_per, base_agg = runs[0]
    has_lpips = "lpips_mean" in base_agg

    # ---- comparison table ----
    lines = ["# SplatViz A/B run comparison", ""]
    lines.append(f"Held-out views scored: {base_agg['n']}  (baseline: **{base_label}**)")
    lines.append("")
    head = "| run | PSNR (dB) | ΔPSNR | SSIM | ΔSSIM |" + (" LPIPS | ΔLPIPS |" if has_lpips else "")
    sep = "|---|---|---|---|---|" + ("---|---|" if has_lpips else "")
    lines += [head, sep]
    for label, per, agg in runs:
        dp = agg["psnr_mean"] - base_agg["psnr_mean"]
        ds = agg["ssim_mean"] - base_agg["ssim_mean"]
        row = (f"| {label} | {agg['psnr_mean']:.2f} | {dp:+.2f} | "
               f"{agg['ssim_mean']:.4f} | {ds:+.4f} |")
        if has_lpips:
            dl = agg.get("lpips_mean", float('nan')) - base_agg.get("lpips_mean", float('nan'))
            row += f" {agg.get('lpips_mean', float('nan')):.4f} | {dl:+.4f} |"
        lines.append(row)
    lines.append("")

    # ---- verdict ----
    best = max(runs, key=lambda r: r[2]["psnr_mean"])
    margin = best[2]["psnr_mean"] - base_agg["psnr_mean"]
    if best[0] == base_label:
        verdict = f"Baseline **{base_label}** is best (no run beat it on mean PSNR)."
    elif margin < 0.2:
        verdict = (f"**{best[0]}** edges out {base_label} by only {margin:+.2f} dB — "
                   f"within noise; the extra cost may not be worth it.")
    else:
        verdict = (f"**{best[0]}** wins: {margin:+.2f} dB mean PSNR over {base_label}.")
    lines += ["## Verdict", "", verdict, ""]

    # ---- where the change concentrates (best vs baseline, per view) ----
    if best[0] != base_label:
        per_best = best[1]
        deltas = []
        for stem in sorted(set(base_per) & set(per_best)):
            d = per_best[stem]["psnr"] - base_per[stem]["psnr"]
            if np.isfinite(d):
                deltas.append((d, stem))
        deltas.sort(reverse=True)
        if deltas:
            lines += ["## Per-view ΔPSNR (best − baseline), biggest gains first", ""]
            lines += ["| view | ΔPSNR (dB) |", "|---|---|"]
            for d, stem in deltas:
                lines.append(f"| {stem} | {d:+.2f} |")
            lines.append("")
            spread = deltas[0][0] - deltas[-1][0]
            if spread > 1.0:
                lines.append(f"_Gain is uneven across views (spread {spread:.1f} dB) — "
                             f"some camera positions benefit far more, which is a coverage/"
                             f"layout signal worth inspecting._")

    out_dir = args.out or Path.cwd() / "ab_compare"
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "AB_COMPARE.md").write_text("\n".join(lines) + "\n")
    (out_dir / "ab_compare.json").write_text(json.dumps(
        {"runs": [{"label": l, "aggregate": a} for l, _, a in runs],
         "baseline": base_label, "verdict": verdict}, indent=2))

    print("\n".join(lines))
    print(f"\nWritten: {out_dir}/AB_COMPARE.md  +  ab_compare.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
