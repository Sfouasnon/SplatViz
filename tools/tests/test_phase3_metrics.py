#!/usr/bin/env python3
"""Self-tests for the Phase 3 quality harness (metrics + holdout split).

Run: python3 tools/tests/test_phase3_metrics.py
Generates synthetic fixtures with known properties and asserts the metrics and
the split behave correctly. No GPU, no real dataset needed.
"""
from __future__ import annotations
import json
import sys
import tempfile
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import splatviz_metrics as M
import splatviz_holdout_split as H

PASS, FAIL = 0, 0


def check(name, cond, detail=""):
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"  PASS  {name}")
    else:
        FAIL += 1
        print(f"  FAIL  {name}  {detail}")


def _save(path, arr01):
    import cv2
    bgr = cv2.cvtColor((np.clip(arr01, 0, 1) * 255).astype(np.uint8), cv2.COLOR_RGB2BGR)
    cv2.imwrite(str(path), bgr)


def test_metric_math():
    print("metric math:")
    rng = np.random.default_rng(0)
    img = rng.random((64, 64, 3)).astype(np.float32)

    # identical -> PSNR inf, SSIM ~1
    check("identical PSNR is inf", not np.isfinite(M.psnr(img, img)))
    check("identical SSIM ~1.0", abs(M.ssim(img, img) - 1.0) < 1e-3,
          f"got {M.ssim(img, img):.5f}")

    # known-variance noise -> PSNR near 10*log10(1/mse)
    noise = rng.normal(0, 0.05, img.shape).astype(np.float32)
    noisy = np.clip(img + noise, 0, 1)
    mse = float(np.mean((img - noisy) ** 2))
    expected = 10 * np.log10(1.0 / mse)
    check("noisy PSNR matches closed form", abs(M.psnr(img, noisy) - expected) < 0.01,
          f"got {M.psnr(img, noisy):.3f} vs {expected:.3f}")

    # more noise -> lower PSNR and lower SSIM (monotonic)
    noisier = np.clip(img + rng.normal(0, 0.15, img.shape), 0, 1).astype(np.float32)
    check("more noise -> lower PSNR", M.psnr(img, noisier) < M.psnr(img, noisy))
    check("more noise -> lower SSIM", M.ssim(img, noisier) < M.ssim(img, noisy))

    # SSIM bounded
    s = M.ssim(img, noisier)
    check("SSIM within (-1,1]", -1.0 <= s <= 1.0, f"got {s:.4f}")


def test_metrics_end_to_end():
    print("metrics tool end-to-end:")
    with tempfile.TemporaryDirectory() as d:
        d = Path(d)
        ren, gt = d / "ren", d / "gt"
        ren.mkdir(); gt.mkdir()
        rng = np.random.default_rng(1)
        for i in range(5):
            base = rng.random((48, 48, 3)).astype(np.float32)
            # degrade the renders progressively so worst-first ordering is testable
            deg = np.clip(base + rng.normal(0, 0.02 * (i + 1), base.shape), 0, 1)
            _save(gt / f"CAM{i:02d}.png", base)
            _save(ren / f"CAM{i:02d}.png", deg)
        out = d / "metrics"
        rc = M.main.__wrapped__ if hasattr(M.main, "__wrapped__") else None
        # call via argv
        argv = ["prog", "--rendered", str(ren), "--ground-truth", str(gt), "--out", str(out)]
        old = sys.argv
        sys.argv = argv
        try:
            ret = M.main()
        finally:
            sys.argv = old
        check("metrics main returns 0", ret == 0)
        report = json.loads((out / "metrics.json").read_text())
        check("scored all 5 views", report["aggregate"]["n"] == 5)
        psnrs = [r["psnr"] for r in report["per_view"]]
        check("per-view sorted worst-first", psnrs == sorted(psnrs))
        check("CAM04 (most degraded) is worst", report["per_view"][0]["name"] == "CAM04")


def _fake_transforms(n=12):
    """Ring of n cameras around origin -> transforms.json-like dict."""
    frames = []
    for i in range(n):
        a = 2 * np.pi * i / n
        pos = np.array([np.cos(a), 0.1, np.sin(a)]) * 2.0
        M4 = np.eye(4)
        M4[:3, 3] = pos
        frames.append({
            "file_path": f"images/CAM{i:02d}.png",
            "fl_x": 1000, "fl_y": 1000, "cx": 24, "cy": 24, "w": 48, "h": 48,
            "transform_matrix": M4.tolist(),
        })
    return {"frames": frames, "camera_model": "PINHOLE"}


def test_holdout_split():
    print("holdout split:")
    with tempfile.TemporaryDirectory() as d:
        d = Path(d)
        (d / "images").mkdir()
        for i in range(12):
            _save(d / "images" / f"CAM{i:02d}.png", np.zeros((48, 48, 3), np.float32))
        (d / "transforms.json").write_text(json.dumps(_fake_transforms(12)))

        def run(mode, count=None, cameras=""):
            out = d / f"out_{mode}_{count}_{cameras or 'x'}"
            argv = ["prog", "--dataset", str(d), "--mode", mode, "--out", str(out)]
            if count is not None:
                argv += ["--count", str(count)]
            if cameras:
                argv += ["--cameras", cameras]
            old = sys.argv
            sys.argv = argv
            try:
                ret = H.main()
            finally:
                sys.argv = old
            man = json.loads((out / "holdout_manifest.json").read_text())
            return ret, man, out

        ret, man, out = run("spread", count=4)
        check("spread returns 0", ret == 0)
        check("spread holds out 4", man["holdout_count"] == 4)
        check("spread train = 8", man["train_count"] == 8)
        check("train+holdout = total", man["holdout_count"] + man["train_count"] == 12)
        check("GT stills staged", len(list((out / "holdout_gt").glob("*.png"))) == 4)
        tt = json.loads((out / "train_transforms.json").read_text())
        check("train_transforms excludes holdout", len(tt["frames"]) == 8)
        # spread should not pick adjacent-only cams: check angular spread of picks
        picks = [c["name"] for c in man["holdout_cameras"]]
        idxs = sorted(int(p[3:5]) for p in picks)
        gaps = [(idxs[(i + 1) % len(idxs)] - idxs[i]) % 12 for i in range(len(idxs))]
        check("spread picks are distributed (no gap > 6)", max(gaps) <= 6,
              f"idxs={idxs} gaps={gaps}")

        ret, man, _ = run("single")
        check("single holds out 1", man["holdout_count"] == 1)

        ret, man, _ = run("dense")
        check("dense holds out 8", man["holdout_count"] == 8)

        ret, man, _ = run("none")
        check("none holds out 0", man["holdout_count"] == 0)

        ret, man, _ = run("explicit", cameras="CAM03,CAM07")
        names = sorted(c["name"] for c in man["holdout_cameras"])
        check("explicit picks exactly named", names == ["CAM03.png", "CAM07.png"], names)


if __name__ == "__main__":
    test_metric_math()
    test_metrics_end_to_end()
    test_holdout_split()
    print(f"\n{PASS} passed, {FAIL} failed")
    sys.exit(1 if FAIL else 0)
