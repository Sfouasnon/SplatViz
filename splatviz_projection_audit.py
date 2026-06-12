#!/usr/bin/env python3
"""
SplatViz projection-overlay audit.

Reads a COLMAP binary sparse model from <dataset>/sparse/0 and projects
points3D.bin into every camera image referenced by images.bin. It writes visual
overlays to <dataset>/diagnostics/overlays and a SUMMARY.txt report.

Designed for SplatViz M55 camera-truth validation before running Msplat.
"""
from __future__ import annotations

import argparse
import math
import struct
from pathlib import Path
from typing import BinaryIO, Dict, List, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageFont


# COLMAP camera model id -> number of params.
CAMERA_MODEL_NUM_PARAMS = {
    0: 3,   # SIMPLE_PINHOLE
    1: 4,   # PINHOLE
    2: 4,   # SIMPLE_RADIAL
    3: 5,   # RADIAL
    4: 8,   # OPENCV
    5: 8,   # OPENCV_FISHEYE
    6: 12,  # FULL_OPENCV
    7: 5,   # FOV
    8: 4,   # SIMPLE_RADIAL_FISHEYE
    9: 5,   # RADIAL_FISHEYE
    10: 12, # THIN_PRISM_FISHEYE
}

CAMERA_MODEL_NAME = {
    0: "SIMPLE_PINHOLE",
    1: "PINHOLE",
    2: "SIMPLE_RADIAL",
    3: "RADIAL",
    4: "OPENCV",
    5: "OPENCV_FISHEYE",
    6: "FULL_OPENCV",
    7: "FOV",
    8: "SIMPLE_RADIAL_FISHEYE",
    9: "RADIAL_FISHEYE",
    10: "THIN_PRISM_FISHEYE",
}


def read(fmt: str, f: BinaryIO):
    size = struct.calcsize(fmt)
    b = f.read(size)
    if len(b) != size:
        raise EOFError(f"Expected {size} bytes, got {len(b)}")
    vals = struct.unpack(fmt, b)
    return vals[0] if len(vals) == 1 else vals


def read_c_string(f: BinaryIO) -> str:
    buf = bytearray()
    while True:
        b = f.read(1)
        if not b:
            raise EOFError("Unterminated C string")
        if b == b"\x00":
            return buf.decode("utf-8", errors="replace")
        buf.extend(b)


def read_cameras_bin(path: Path) -> Dict[int, dict]:
    cams = {}
    with path.open("rb") as f:
        n = read("<Q", f)
        for _ in range(n):
            cam_id = read("<i", f)
            model_id = read("<i", f)
            width = read("<Q", f)
            height = read("<Q", f)
            nparams = CAMERA_MODEL_NUM_PARAMS.get(model_id)
            if nparams is None:
                raise ValueError(f"Unsupported COLMAP camera model id {model_id}")
            params = [read("<d", f) for _ in range(nparams)]
            cams[cam_id] = {
                "id": cam_id,
                "model_id": model_id,
                "model": CAMERA_MODEL_NAME.get(model_id, str(model_id)),
                "width": int(width),
                "height": int(height),
                "params": params,
            }
    return cams


def read_images_bin(path: Path) -> Dict[int, dict]:
    imgs = {}
    with path.open("rb") as f:
        n = read("<Q", f)
        for _ in range(n):
            image_id = read("<i", f)
            q = tuple(read("<dddd", f))
            t = tuple(read("<ddd", f))
            camera_id = read("<i", f)
            name = read_c_string(f)
            npts = read("<Q", f)
            pts2d = []
            for j in range(npts):
                x, y = read("<dd", f)
                # COLMAP uses point3D_id_t; SplatViz writes store_64. Treat as unsigned.
                point3d_id = read("<Q", f)
                pts2d.append((x, y, point3d_id))
            imgs[image_id] = {
                "id": image_id,
                "q": q,
                "t": t,
                "camera_id": camera_id,
                "name": name,
                "points2D": pts2d,
            }
    return imgs


def read_points3d_bin(path: Path) -> Tuple[np.ndarray, List[int]]:
    pts = []
    ids = []
    with path.open("rb") as f:
        n = read("<Q", f)
        for _ in range(n):
            pid = read("<Q", f)
            x, y, z = read("<ddd", f)
            _r = read("<B", f)
            _g = read("<B", f)
            _b = read("<B", f)
            _err = read("<d", f)
            track_len = read("<Q", f)
            # image_id int32 + point2D_idx int32 for each track element.
            f.seek(int(track_len) * 8, 1)
            ids.append(int(pid))
            pts.append((x, y, z))
    return np.asarray(pts, dtype=np.float64), ids


def qvec_to_R(q: Tuple[float, float, float, float]) -> np.ndarray:
    qw, qx, qy, qz = q
    return np.array([
        [1 - 2 * qy * qy - 2 * qz * qz, 2 * qx * qy - 2 * qw * qz, 2 * qx * qz + 2 * qw * qy],
        [2 * qx * qy + 2 * qw * qz, 1 - 2 * qx * qx - 2 * qz * qz, 2 * qy * qz - 2 * qw * qx],
        [2 * qx * qz - 2 * qw * qy, 2 * qy * qz + 2 * qw * qx, 1 - 2 * qx * qx - 2 * qy * qy],
    ], dtype=np.float64)


def intrinsics(cam: dict) -> Tuple[float, float, float, float]:
    params = cam["params"]
    model = cam["model"]
    if model == "SIMPLE_PINHOLE":
        f, cx, cy = params[:3]
        return float(f), float(f), float(cx), float(cy)
    if model == "PINHOLE":
        fx, fy, cx, cy = params[:4]
        return float(fx), float(fy), float(cx), float(cy)
    if model.startswith("SIMPLE_RADIAL"):
        f, cx, cy = params[:3]
        return float(f), float(f), float(cx), float(cy)
    if model in {"RADIAL", "RADIAL_FISHEYE", "FOV"}:
        f, cx, cy = params[:3]
        return float(f), float(f), float(cx), float(cy)
    if model in {"OPENCV", "OPENCV_FISHEYE", "FULL_OPENCV", "THIN_PRISM_FISHEYE"}:
        fx, fy, cx, cy = params[:4]
        return float(fx), float(fy), float(cx), float(cy)
    raise ValueError(f"Unsupported intrinsics model {model}")


def resolve_image_path(dataset: Path, sparse: Path, name: str) -> Path | None:
    candidates = [
        sparse / name,
        dataset / "images" / name,
        sparse / "images" / name,
        dataset / name,
    ]
    for p in candidates:
        if p.exists():
            return p
    return None


def pick_points(uv: np.ndarray, max_pts: int) -> np.ndarray:
    if max_pts <= 0 or len(uv) <= max_pts:
        return uv
    idx = np.linspace(0, len(uv) - 1, max_pts).astype(int)
    return uv[idx]


def draw_overlay(img_path: Path, out_path: Path, label_lines: List[str], uv: np.ndarray, max_draw: int) -> None:
    im = Image.open(img_path).convert("RGB")
    d = ImageDraw.Draw(im)
    pts = pick_points(uv, max_draw)
    for x, y in pts:
        r = 4
        d.ellipse((x - r, y - r, x + r, y + r), outline=(255, 0, 0), width=2)
    # top-left diagnostic label
    font = ImageFont.load_default()
    text = "\n".join(label_lines)
    pad = 8
    # Approximate label box size. Textbbox may be absent on older Pillow.
    try:
        box = d.multiline_textbbox((pad, pad), text, font=font, spacing=4)
        w = box[2] - box[0] + 2 * pad
        h = box[3] - box[1] + 2 * pad
    except Exception:
        w = 620
        h = 76
    d.rectangle((0, 0, w, h), fill=(0, 0, 0))
    d.multiline_text((pad, pad), text, fill=(255, 230, 120), font=font, spacing=4)
    im.save(out_path)


def run(dataset_str: str, max_pts: int, max_draw: int) -> int:
    dataset = Path(dataset_str).expanduser().resolve()
    sparse = dataset / "sparse" / "0"
    cameras_path = sparse / "cameras.bin"
    images_path = sparse / "images.bin"
    points_path = sparse / "points3D.bin"
    for p in (cameras_path, images_path, points_path):
        if not p.exists():
            raise FileNotFoundError(p)

    cams = read_cameras_bin(cameras_path)
    imgs = read_images_bin(images_path)
    pts3d, point_ids = read_points3d_bin(points_path)

    if max_pts > 0 and len(pts3d) > max_pts:
        sample_idx = np.linspace(0, len(pts3d) - 1, max_pts).astype(int)
        pts_for_overlay = pts3d[sample_idx]
    else:
        pts_for_overlay = pts3d

    odir = dataset / "diagnostics" / "overlays"
    odir.mkdir(parents=True, exist_ok=True)
    summary_path = dataset / "diagnostics" / "SUMMARY.txt"

    lines = []
    def emit(s: str = "") -> None:
        print(s)
        lines.append(s)

    emit(f"Dataset: {dataset}")
    emit(f"cameras={len(cams)}  images={len(imgs)}  points3D={len(pts3d)}")
    emit("")
    emit("points3D bounds:")
    if len(pts3d):
        for i, ax in enumerate("XYZ"):
            arr = pts3d[:, i]
            emit(f"  {ax}: [{arr.min():.3f}, {arr.max():.3f}]  span={np.ptp(arr):.3f}")
    emit("")
    emit(f"{'Camera':<34} {'front':>8} {'inbounds':>9} {'%':>7} {'v_span':>8}  status")
    emit("-" * 78)

    good = low = zero = visual_risk = 0
    for im in sorted(imgs.values(), key=lambda x: x["name"]):
        cam = cams[im["camera_id"]]
        fx, fy, cx, cy = intrinsics(cam)
        R = qvec_to_R(im["q"])
        t = np.asarray(im["t"], dtype=np.float64)
        cam_pts = pts_for_overlay @ R.T + t
        z = cam_pts[:, 2]
        front_mask = z > 1e-6
        front = int(front_mask.sum())
        uv = np.empty((0, 2), dtype=np.float64)
        inb = 0
        pct = 0.0
        v_span = 0.0
        if front:
            cp = cam_pts[front_mask]
            u = fx * cp[:, 0] / cp[:, 2] + cx
            v = fy * cp[:, 1] / cp[:, 2] + cy
            w, h = int(cam["width"]), int(cam["height"])
            mask = (u >= 0) & (u < w) & (v >= 0) & (v < h)
            uv = np.stack([u[mask], v[mask]], axis=1)
            inb = int(mask.sum())
            pct = 100.0 * inb / len(pts_for_overlay)
            if inb:
                v_span = float(np.ptp(uv[:, 1]))
        if inb == 0:
            status = "ZERO"
            zero += 1
        elif pct < 5.0:
            status = "low"
            low += 1
        else:
            status = "GOOD"
            good += 1
        # A broad portrait/wide camera with v-span near zero is usually a visual failure even if in-bounds.
        if inb > 20 and v_span < 30.0:
            status += "+VSPAN_RISK"
            visual_risk += 1

        emit(f"  {im['name']:<32} {front:>8} {inb:>9} {pct:>6.1f}% {v_span:>8.1f}  {status}")

        img_path = resolve_image_path(dataset, sparse, im["name"])
        if img_path is not None:
            qn = float(np.linalg.norm(np.asarray(im["q"])))
            C = -R.T @ t
            label = [
                im["name"],
                f"front={front} in-bounds={inb}/{len(pts_for_overlay)} ({pct:.1f}%) v-span={v_span:.1f}",
                f"fx={fx:.0f} fy={fy:.0f} cx={cx:.0f} cy={cy:.0f} {cam['width']}x{cam['height']} qnorm={qn:.4f}",
                f"C=({C[0]:.3f}, {C[1]:.3f}, {C[2]:.3f})",
            ]
            out_path = odir / f"{Path(im['name']).stem}_overlay.png"
            draw_overlay(img_path, out_path, label, uv, max_draw=max_draw)
        else:
            emit(f"    image file missing for overlay: {im['name']}")

    emit("")
    emit(f"Summary: {good} GOOD  {low} low  {zero} ZERO  {visual_risk} v-span risk")
    if zero or low:
        emit("Result: FAIL NUMERIC — inspect ZERO/low camera overlays before training.")
    elif visual_risk:
        emit("Result: FAIL VISUAL-RISK — dots are in-bounds but may be collapsed; inspect overlays before training.")
    else:
        emit("Result: NUMERIC PASS — still inspect overlays visually before training.")
    emit(f"Overlays: {odir}")

    emit("")
    emit(f"{'Camera':<34} {'cx':>8} {'cy':>8} {'cz':>8}  qnorm")
    emit("  " + "-" * 58)
    for im in sorted(imgs.values(), key=lambda x: x["name"]):
        R = qvec_to_R(im["q"])
        t = np.asarray(im["t"], dtype=np.float64)
        C = -R.T @ t
        qn = float(np.linalg.norm(np.asarray(im["q"])))
        emit(f"  {im['name']:<32} {C[0]:>8.3f} {C[1]:>8.3f} {C[2]:>8.3f}  {qn:.4f}")

    summary_path.write_text("\n".join(lines) + "\n")
    return 0 if not (zero or low or visual_risk) else 2


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", required=True, help="SplatViz dataset root containing sparse/0")
    ap.add_argument("--max-pts", type=int, default=0, help="Max 3D points to project; 0 = all")
    ap.add_argument("--max-draw", type=int, default=1200, help="Max dots drawn per overlay")
    args = ap.parse_args()
    raise SystemExit(run(args.dataset, args.max_pts, args.max_draw))


if __name__ == "__main__":
    main()
