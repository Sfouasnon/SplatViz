#!/usr/bin/env python3
"""Independent CPU 3DGS renderer — re-score held-out views without trusting Msplat's eval.

Why this exists: Msplat reports ~12 dB PSNR on held-out views, but the splat
looks recognizable and correctly colored in a viewer. That contradiction is
usually a measurement bug (e.g. linear-vs-sRGB gamma in the trainer's eval),
not a quality problem. This renders the held-out camera poses ourselves, from
the PLY, using the SAME COLMAP projection we already validated in
splatviz_cut_diagnosis.py, then scores against the ground-truth stills.

Interpretation:
  - if OUR PSNR is much higher than Msplat's ~12 dB  -> Msplat's eval is the
    problem; the splat is actually good.
  - if OUR PSNR is also ~12 dB                        -> the novel-view quality
    is genuinely poor (coverage/overfit); attack training/coverage.

This is a forward, CPU, reference-grade renderer (no GPU). v1 uses SH degree 0
(the DC color term) — enough for a brightness/quality/gamma sanity check; full
view-dependent SH is a later refinement. Conventions: standard Inria 3DGS PLY
(scale = exp(scale_*), opacity = sigmoid(opacity), color = 0.2820948*f_dc+0.5,
rotation quat order w,x,y,z), COLMAP world-to-camera poses (x-right/y-down/
z-forward), low-pass covariance jitter +0.3.

Usage:
  python3 tools/splatviz_cpu_render.py \
      --ply  <result.ply> \
      --dataset <dataset_root with sparse/0 and images/> \
      [--cameras CAM01,CAM09,CAM17,CAM25,CAM33]   # default: every-8th (Msplat test set)
      [--out <render_dir>]

If --cameras is omitted it renders Msplat's implicit test split (every 8th
camera, 0-based), which is what --test-every 8 holds out.
"""
from __future__ import annotations
import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from splatviz_cut_diagnosis import read_ply_vertices, read_colmap_sparse, qvec_to_rotmat

SH_C0 = 0.28209479177387814


def _sigmoid(x):
    return 1.0 / (1.0 + np.exp(-x))


def decode_gaussians(ply: dict) -> dict:
    n = len(ply["x"])
    xyz = np.stack([ply["x"], ply["y"], ply["z"]], axis=1).astype(np.float64)
    # color from SH degree-0 DC term
    if all(k in ply for k in ("f_dc_0", "f_dc_1", "f_dc_2")):
        dc = np.stack([ply["f_dc_0"], ply["f_dc_1"], ply["f_dc_2"]], axis=1)
        color = np.clip(SH_C0 * dc + 0.5, 0.0, 1.0)
    elif all(k in ply for k in ("red", "green", "blue")):
        color = np.stack([ply["red"], ply["green"], ply["blue"]], axis=1) / 255.0
    else:
        color = np.full((n, 3), 0.5)
    opacity = _sigmoid(ply["opacity"]) if "opacity" in ply else np.ones(n)
    scale = np.stack([ply["scale_0"], ply["scale_1"], ply["scale_2"]], axis=1)
    # clamp log-scale before exp so floaters with huge scales don't overflow to inf
    scale = np.exp(np.clip(scale.astype(np.float64), -20.0, 5.0))
    quat = np.stack([ply["rot_0"], ply["rot_1"], ply["rot_2"], ply["rot_3"]], axis=1).astype(np.float64)
    quat /= (np.linalg.norm(quat, axis=1, keepdims=True) + 1e-12)
    opacity = np.asarray(opacity, float)
    # Drop diverged (NaN/Inf) gaussians — a single NaN footprint poisons the
    # transmittance buffer and blacks out the whole frame.
    finite = (np.isfinite(xyz).all(1) & np.isfinite(scale).all(1)
              & np.isfinite(quat).all(1) & np.isfinite(opacity)
              & np.isfinite(color).all(1))
    dropped = int((~finite).sum())
    if dropped:
        print(f"  dropped {dropped:,} non-finite gaussians ({dropped/len(finite):.1%})")
    return {"xyz": xyz[finite], "color": color[finite], "opacity": opacity[finite],
            "scale": scale[finite], "quat": quat[finite]}


def quat_to_R(q: np.ndarray) -> np.ndarray:
    w, x, y, z = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - w * z),     2 * (x * z + w * y)],
        [2 * (x * y + w * z),     1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
        [2 * (x * z - w * y),     2 * (y * z + w * x),     1 - 2 * (x * x + y * y)],
    ])


def intrinsics_from_colmap(cam: dict):
    model, params = cam["model"], cam["params"]
    if model in (0, 5):      # SIMPLE_PINHOLE / SIMPLE_RADIAL
        f, cx, cy = params[0], params[1], params[2]
        return f, f, cx, cy
    # PINHOLE (1) and most others: fx, fy, cx, cy
    return params[0], params[1], params[2], params[3]


def render_view(g: dict, R: np.ndarray, t: np.ndarray, fx, fy, cx, cy, W, H,
                bg=0.0) -> np.ndarray:
    xyz, color, opacity, scale, quat = g["xyz"], g["color"], g["opacity"], g["scale"], g["quat"]
    # camera-space centers
    p_cam = xyz @ R.T + t
    z = p_cam[:, 2]
    front = z > 1e-4
    idx = np.where(front)[0]
    if idx.size == 0:
        return np.full((H, W, 3), bg, np.float32)

    u = fx * p_cam[idx, 0] / z[idx] + cx
    v = fy * p_cam[idx, 1] / z[idx] + cy

    img = np.full((H, W, 3), bg, np.float64)
    T = np.ones((H, W), np.float64)  # transmittance

    # front-to-back order
    order = idx[np.argsort(z[idx])]

    # precompute per-gaussian camera-space rotation contribution lazily in loop
    for gi in order:
        zc = z[gi]
        # 3D covariance
        Rq = quat_to_R(quat[gi])
        S = np.diag(scale[gi])
        M = Rq @ S
        Sigma3d = M @ M.T
        cov_cam = R @ Sigma3d @ R.T
        x, y = p_cam[gi, 0], p_cam[gi, 1]
        J = np.array([[fx / zc, 0.0, -fx * x / (zc * zc)],
                      [0.0, fy / zc, -fy * y / (zc * zc)]])
        cov2d = J @ cov_cam @ J.T
        cov2d[0, 0] += 0.3
        cov2d[1, 1] += 0.3
        if not np.isfinite(cov2d).all():
            continue
        a, b, c = cov2d[0, 0], cov2d[0, 1], cov2d[1, 1]
        det = a * c - b * b
        if not np.isfinite(det) or det <= 1e-12:   # NaN-safe (NaN<=x is False)
            continue
        # conic = inverse(cov2d)
        ic = np.array([c, -b, a]) / det
        # 3-sigma radius from larger eigenvalue (disc >= 0 for symmetric 2x2)
        mid = 0.5 * (a + c)
        lam = mid + np.sqrt(max(mid * mid - det, 0.0))
        if not np.isfinite(lam) or lam <= 0:
            continue
        rad = int(np.ceil(3.0 * np.sqrt(lam)))
        rad = max(1, min(rad, max(W, H)))   # cap pathological footprints
        # u,v were computed over idx (sorted); map global gi -> its position in idx
        pos = np.searchsorted(idx, gi)
        cu, cv = u[pos], v[pos]
        x0 = max(int(np.floor(cu - rad)), 0)
        x1 = min(int(np.ceil(cu + rad)), W - 1)
        y0 = max(int(np.floor(cv - rad)), 0)
        y1 = min(int(np.ceil(cv + rad)), H - 1)
        if x1 < x0 or y1 < y0:
            continue
        ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
        dx = xs - cu
        dy = ys - cv
        power = -0.5 * (ic[0] * dx * dx + ic[2] * dy * dy) - ic[1] * dx * dy
        alpha = opacity[gi] * np.exp(np.clip(power, -50, 0))
        alpha = np.clip(alpha, 0.0, 0.99)
        Tw = T[y0:y1 + 1, x0:x1 + 1]
        w = alpha * Tw
        for ch in range(3):
            img[y0:y1 + 1, x0:x1 + 1, ch] += w * color[gi, ch]
        T[y0:y1 + 1, x0:x1 + 1] = Tw * (1.0 - alpha)

    return np.clip(img, 0.0, 1.0).astype(np.float32)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ply", type=Path, required=True)
    ap.add_argument("--dataset", type=Path, required=True, help="root with sparse/0 and images/")
    ap.add_argument("--cameras", type=str, default="", help="comma list; default = every-8th test split")
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()

    g = decode_gaussians(read_ply_vertices(args.ply))
    cameras, images, _ = read_colmap_sparse(args.dataset / "sparse" / "0")

    # order images by name for a stable index (matches CAM01..CAM36)
    imgs = sorted(images.values(), key=lambda im: im["name"])
    if args.cameras:
        want = {s.strip() for s in args.cameras.split(",") if s.strip()}
        sel = [im for im in imgs if Path(im["name"]).stem in want
               or im["name"] in want or Path(im["name"]).stem.split("_")[0] in want]
    else:
        sel = [im for i, im in enumerate(imgs) if i % 8 == 0]  # Msplat --test-every 8

    out = args.out or (args.dataset / "cpu_holdout_render")
    out.mkdir(parents=True, exist_ok=True)

    def _save_png(path, rgb01):
        arr = (np.clip(rgb01, 0, 1) * 255).astype(np.uint8)
        try:
            from PIL import Image
            Image.fromarray(arr, "RGB").save(str(path))
        except Exception:
            import cv2
            cv2.imwrite(str(path), cv2.cvtColor(arr, cv2.COLOR_RGB2BGR))

    print(f"Rendering {len(sel)} held-out views from {len(g['xyz']):,} gaussians "
          f"(SH deg-0 color)…")
    for im in sel:
        R = qvec_to_rotmat(im["qvec"])
        t = im["tvec"]
        cam = cameras[im["camera_id"]]
        fx, fy, cx, cy = intrinsics_from_colmap(cam)
        W, H = cam["width"], cam["height"]
        rgb = render_view(g, R, t, fx, fy, cx, cy, W, H)
        outp = out / Path(im["name"]).name
        _save_png(outp, rgb)
        print(f"  wrote {outp.name}  ({W}x{H})")

    print(f"\nRenders in: {out}")
    print("Score them against the ground-truth stills:")
    print(f"  python3 tools/splatviz_metrics.py --rendered {out} "
          f"--ground-truth {args.dataset}/images")
    print("\nIf this PSNR is much higher than Msplat's ~12 dB, Msplat's eval is the bug.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
