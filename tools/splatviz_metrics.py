#!/usr/bin/env python3
"""SplatViz quality metrics — objective PSNR / SSIM / LPIPS on held-out views.

Phase 3 (Issue 2): replace eyeballing the sprite preview with numbers.

Compares a folder of RENDERED images (your trained splat rendered at the
held-out camera poses) against the GROUND-TRUTH stills for those same poses,
matched by filename stem. Emits a per-camera table (worst views first), an
aggregate summary, and a spatial-pattern check that flags whether the worst
views cluster on one side of the rig (the classic basis/pose smell).

PSNR and SSIM are always available (numpy + OpenCV). LPIPS is optional and
activates automatically if `torch` and `lpips` are importable; otherwise it is
reported as unavailable with an install hint.

Usage:
  python3 tools/splatviz_metrics.py \
      --rendered  path/to/rendered_holdout_dir \
      --ground-truth path/to/gt_dir \
      [--manifest holdout_manifest.json]   # adds camera poses -> spatial check
      [--out path/to/report_dir]           # default: <rendered>/../metrics
"""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path

import numpy as np

try:
    import cv2  # OpenCV: Gaussian windows for SSIM, robust image IO
    _HAVE_CV2 = True
except Exception:
    _HAVE_CV2 = False

IMG_EXTS = {".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff", ".exr"}


# --------------------------------------------------------------------------- IO
def _load_rgb01(path: Path) -> np.ndarray:
    """Load an image as float32 RGB in [0,1]; drop alpha; HxWx3."""
    if _HAVE_CV2:
        arr = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
        if arr is None:
            raise IOError(f"could not read {path}")
        if arr.ndim == 2:
            arr = cv2.cvtColor(arr, cv2.COLOR_GRAY2RGB)
        elif arr.shape[2] == 4:
            arr = cv2.cvtColor(arr, cv2.COLOR_BGRA2RGB)
        else:
            arr = cv2.cvtColor(arr, cv2.COLOR_BGR2RGB)
    else:
        from PIL import Image
        arr = np.asarray(Image.open(path).convert("RGB"))
    arr = arr.astype(np.float32)
    if arr.max() > 1.5:  # 8-bit or 16-bit -> normalize
        arr = arr / (65535.0 if arr.max() > 255.0 else 255.0)
    return np.clip(arr, 0.0, 1.0)


def _match_size(a: np.ndarray, b: np.ndarray) -> tuple[np.ndarray, np.ndarray, bool]:
    """Resize b to a's resolution if they differ. Returns (a, b, resized?)."""
    if a.shape[:2] == b.shape[:2]:
        return a, b, False
    if _HAVE_CV2:
        b2 = cv2.resize(b, (a.shape[1], a.shape[0]), interpolation=cv2.INTER_AREA)
    else:
        from PIL import Image
        b2 = np.asarray(
            Image.fromarray((b * 255).astype(np.uint8)).resize((a.shape[1], a.shape[0]))
        ).astype(np.float32) / 255.0
    return a, b2, True


# ----------------------------------------------------------------------- METRICS
def psnr(a: np.ndarray, b: np.ndarray) -> float:
    mse = float(np.mean((a - b) ** 2))
    if mse <= 1e-12:
        return float("inf")
    return float(10.0 * np.log10(1.0 / mse))


def ssim(a: np.ndarray, b: np.ndarray) -> float:
    """Mean SSIM (Wang et al. 2004), 11x11 Gaussian window, sigma 1.5, per channel."""
    C1 = (0.01) ** 2
    C2 = (0.03) ** 2

    def _blur(x):
        if _HAVE_CV2:
            return cv2.GaussianBlur(x, (11, 11), 1.5)
        return _np_gaussian_blur(x, 1.5)

    vals = []
    for c in range(a.shape[2]):
        x = a[:, :, c].astype(np.float64)
        y = b[:, :, c].astype(np.float64)
        mu_x = _blur(x)
        mu_y = _blur(y)
        mu_x2, mu_y2, mu_xy = mu_x * mu_x, mu_y * mu_y, mu_x * mu_y
        sig_x = _blur(x * x) - mu_x2
        sig_y = _blur(y * y) - mu_y2
        sig_xy = _blur(x * y) - mu_xy
        num = (2 * mu_xy + C1) * (2 * sig_xy + C2)
        den = (mu_x2 + mu_y2 + C1) * (sig_x + sig_y + C2)
        vals.append(np.mean(num / den))
    return float(np.mean(vals))


def _np_gaussian_blur(x: np.ndarray, sigma: float) -> np.ndarray:
    """Separable Gaussian fallback when OpenCV is unavailable."""
    radius = 5
    ax = np.arange(-radius, radius + 1)
    k = np.exp(-(ax ** 2) / (2 * sigma * sigma))
    k /= k.sum()
    pad = np.pad(x, ((radius, radius), (radius, radius)), mode="reflect")
    tmp = np.apply_along_axis(lambda m: np.convolve(m, k, mode="valid"), 1, pad)
    out = np.apply_along_axis(lambda m: np.convolve(m, k, mode="valid"), 0, tmp)
    return out


# --------------------------------------------------------------------- LPIPS (opt)
class _LPIPS:
    def __init__(self):
        self.ok = False
        try:
            import torch
            import lpips
            self._torch = torch
            self._net = lpips.LPIPS(net="alex")
            self._net.eval()
            self.ok = True
        except Exception as e:
            self._reason = str(e)

    def score(self, a: np.ndarray, b: np.ndarray) -> float:
        torch = self._torch
        # to [-1,1], NCHW
        ta = torch.from_numpy(a.transpose(2, 0, 1)[None]).float() * 2 - 1
        tb = torch.from_numpy(b.transpose(2, 0, 1)[None]).float() * 2 - 1
        with torch.no_grad():
            return float(self._net(ta, tb).item())


# ------------------------------------------------------------------------- DRIVER
def _index_dir(d: Path) -> dict[str, Path]:
    out = {}
    for p in sorted(d.iterdir()):
        if p.suffix.lower() in IMG_EXTS:
            out[p.stem] = p
    return out


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--rendered", type=Path, required=True, help="dir of trained-splat renders")
    ap.add_argument("--ground-truth", type=Path, required=True, help="dir of GT stills")
    ap.add_argument("--manifest", type=Path, default=None, help="holdout_manifest.json (adds poses)")
    ap.add_argument("--out", type=Path, default=None, help="report output dir")
    args = ap.parse_args()

    ren = _index_dir(args.rendered)
    gt = _index_dir(args.ground_truth)
    common = sorted(set(ren) & set(gt))
    if not common:
        print("ERROR: no matching filename stems between the two folders.", file=sys.stderr)
        print(f"  rendered stems (sample): {list(ren)[:5]}", file=sys.stderr)
        print(f"  gt stems (sample):       {list(gt)[:5]}", file=sys.stderr)
        return 2

    poses = {}
    if args.manifest and args.manifest.exists():
        man = json.loads(args.manifest.read_text())
        for cam in man.get("holdout_cameras", []):
            stem = Path(cam.get("image", "")).stem
            if "position" in cam:
                poses[stem] = np.asarray(cam["position"], dtype=float)

    lp = _LPIPS()

    rows = []
    for stem in common:
        a = _load_rgb01(ren[stem])
        b = _load_rgb01(gt[stem])
        a, b, resized = _match_size(a, b)
        row = {
            "name": stem,
            "psnr": psnr(a, b),
            "ssim": ssim(a, b),
            "lpips": (lp.score(a, b) if lp.ok else None),
            "resized": resized,
        }
        rows.append(row)

    rows.sort(key=lambda r: r["psnr"])  # worst first

    finite_psnr = [r["psnr"] for r in rows if np.isfinite(r["psnr"])]
    agg = {
        "n": len(rows),
        "psnr_mean": float(np.mean(finite_psnr)) if finite_psnr else float("inf"),
        "psnr_median": float(np.median(finite_psnr)) if finite_psnr else float("inf"),
        "psnr_min": float(np.min(finite_psnr)) if finite_psnr else float("inf"),
        "ssim_mean": float(np.mean([r["ssim"] for r in rows])),
        "ssim_min": float(np.min([r["ssim"] for r in rows])),
    }
    if lp.ok:
        agg["lpips_mean"] = float(np.mean([r["lpips"] for r in rows]))
        agg["lpips_max"] = float(np.max([r["lpips"] for r in rows]))

    # Spatial-pattern check: do the worst views cluster on one side of the rig?
    spatial_note = "n/a (no manifest poses)"
    if poses and len(finite_psnr) >= 4:
        pos = {r["name"]: poses[r["name"]] for r in rows if r["name"] in poses}
        if len(pos) >= 4:
            names = list(pos)
            P = np.array([pos[n] for n in names])
            center = P.mean(axis=0)
            half = len(rows) // 2
            worst = {r["name"] for r in rows[:half]}
            best = {r["name"] for r in rows[half:]}
            # find axis with largest separation of worst-vs-best centroids
            wc = np.mean([pos[n] - center for n in names if n in worst], axis=0)
            bc = np.mean([pos[n] - center for n in names if n in best], axis=0)
            sep = wc - bc
            axis = int(np.argmax(np.abs(sep)))
            axis_name = "xyz"[axis]
            if np.max(np.abs(sep)) > 0.15 * np.max(np.abs(P - center)):
                spatial_note = (
                    f"WORST views cluster toward {'+-'[sep[axis] < 0]}{axis_name} "
                    f"(separation {sep[axis]:+.3f} m) — suggests a pose/basis asymmetry, "
                    f"not uniform quality loss. Worth checking those cameras' extrinsics."
                )
            else:
                spatial_note = "no strong spatial clustering — quality loss looks uniform."

    out_dir = args.out or (args.rendered.parent / "metrics")
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "metrics.json").write_text(json.dumps({"aggregate": agg, "per_view": rows,
                                                      "spatial": spatial_note}, indent=2))

    # markdown report
    md = []
    md.append("# SplatViz holdout quality metrics\n")
    md.append(f"Compared {agg['n']} held-out views (rendered vs ground truth).\n")
    md.append("## Aggregate\n")
    md.append(f"- PSNR: mean {agg['psnr_mean']:.2f} dB, median {agg['psnr_median']:.2f}, min {agg['psnr_min']:.2f}")
    md.append(f"- SSIM: mean {agg['ssim_mean']:.4f}, min {agg['ssim_min']:.4f}")
    if lp.ok:
        md.append(f"- LPIPS: mean {agg['lpips_mean']:.4f}, max {agg['lpips_max']:.4f} (lower is better)")
    else:
        md.append("- LPIPS: unavailable (install `torch` + `lpips` to enable)")
    md.append(f"\n**Spatial pattern:** {spatial_note}\n")
    md.append("## Per-view (worst first)\n")
    head = "| view | PSNR (dB) | SSIM |" + (" LPIPS |" if lp.ok else "")
    sep = "|---|---|---|" + ("---|" if lp.ok else "")
    md.append(head)
    md.append(sep)
    for r in rows:
        p = "inf" if not np.isfinite(r["psnr"]) else f"{r['psnr']:.2f}"
        line = f"| {r['name']} | {p} | {r['ssim']:.4f} |"
        if lp.ok:
            line += f" {r['lpips']:.4f} |"
        md.append(line)
    (out_dir / "METRICS_REPORT.md").write_text("\n".join(md) + "\n")

    # console summary
    print("\n".join(md[:9]))
    print(f"\nReports: {out_dir}/METRICS_REPORT.md  +  metrics.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
