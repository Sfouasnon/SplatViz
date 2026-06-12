#!/usr/bin/env python3
"""Regression tests for splatviz_cut_diagnosis.py.

Generates synthetic COLMAP datasets and 3DGS PLYs — one healthy, three with
deliberately injected bugs — and asserts the diagnosis tool catches each:

  1. clean dataset + full splat   -> exit 0, ALL PROBES CLEAN
  2. splat guillotined at z~0     -> exit 2, CUT CONFIRMED on z
  3. cameras rolled 180 (x<0 side)-> exit 2, ROLLED + HALF-SPACE
  4. cameras facing away (x<0)    -> exit 2, BEHIND + HALF-SPACE

Run:  python3 tools/tests/test_cut_diagnosis.py
"""
from __future__ import annotations

import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

TOOL = Path(__file__).resolve().parent.parent / "splatviz_cut_diagnosis.py"
RNG = np.random.default_rng(7)


def rot_for(pos, target, mode="ok"):
    fwd = target - pos
    fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    if mode == "flip_up":
        up = -up
    if mode == "neg_fwd":
        fwd = -fwd
    return np.stack([right, -up, fwd])  # COLMAP rows: x right, y down, z fwd


def rotmat_to_qvec(R):
    tr = np.trace(R)
    if tr > 0:
        s = np.sqrt(tr + 1) * 2
        return np.array([0.25 * s, (R[2, 1] - R[1, 2]) / s, (R[0, 2] - R[2, 0]) / s, (R[1, 0] - R[0, 1]) / s])
    i = int(np.argmax(np.diag(R)))
    if i == 0:
        s = np.sqrt(1 + R[0, 0] - R[1, 1] - R[2, 2]) * 2
        return np.array([(R[2, 1] - R[1, 2]) / s, 0.25 * s, (R[0, 1] + R[1, 0]) / s, (R[0, 2] + R[2, 0]) / s])
    if i == 1:
        s = np.sqrt(1 + R[1, 1] - R[0, 0] - R[2, 2]) * 2
        return np.array([(R[0, 2] - R[2, 0]) / s, (R[0, 1] + R[1, 0]) / s, 0.25 * s, (R[1, 2] + R[2, 1]) / s])
    s = np.sqrt(1 + R[2, 2] - R[0, 0] - R[1, 1]) * 2
    return np.array([(R[1, 0] - R[0, 1]) / s, (R[0, 2] + R[2, 0]) / s, (R[1, 2] + R[2, 1]) / s, 0.25 * s])


def write_sparse(root: Path, bug_mode: str | None = None) -> None:
    """12-camera ring with Komodo-X/24mm landscape intrinsics + ellipsoid seed."""
    sp = root / "sparse" / "0"
    sp.mkdir(parents=True, exist_ok=True)
    w, h = 1920, 1080
    fy = h / (2 * np.tan(np.radians(33.09) / 2))
    target = np.array([0.0, 1.62, 0.0])
    with open(sp / "cameras.bin", "wb") as fc, open(sp / "images.bin", "wb") as fi:
        fc.write(struct.pack("<Q", 12))
        fi.write(struct.pack("<Q", 12))
        for i in range(12):
            a = 2 * np.pi * i / 12
            pos = np.array([4.5 * np.cos(a), 1.6, 4.5 * np.sin(a)])
            mode = bug_mode if (bug_mode and pos[0] < 0) else "ok"
            R = rot_for(pos, target, mode)
            t = -R @ pos
            fc.write(struct.pack("<iiQQ", i + 1, 1, w, h))
            fc.write(struct.pack("<4d", fy, fy, w / 2, h / 2))
            fi.write(struct.pack("<I", i + 1))
            fi.write(struct.pack("<7d", *rotmat_to_qvec(R), *t))
            fi.write(struct.pack("<I", i + 1))
            fi.write(f"CAM{i + 1:02d}_frame_000001.png".encode() + b"\x00")
            fi.write(struct.pack("<Q", 0))
    pts = RNG.normal(0, 1, (3000, 3)) * [0.25, 0.5, 0.15] + [0, 1.1, 0]
    with open(sp / "points3D.bin", "wb") as f:
        f.write(struct.pack("<Q", len(pts)))
        for j, (x, y, z) in enumerate(pts):
            f.write(struct.pack("<Q", j))
            f.write(struct.pack("<3d", x, y, z))
            f.write(bytes([200, 200, 200]))
            f.write(struct.pack("<d", 0.5))
            f.write(struct.pack("<Q", 0))


def write_result_ply(path: Path, cut: bool = False) -> None:
    pts = RNG.normal(0, 1, (20000, 3)) * [0.3, 0.55, 0.2] + [0, 1.1, 0]
    if cut:
        pts = pts[pts[:, 2] < 0.02]
    opa = RNG.normal(2.0, 1.0, len(pts))
    with open(path, "wb") as f:
        f.write((
            "ply\nformat binary_little_endian 1.0\n"
            f"element vertex {len(pts)}\n"
            + "".join(f"property float {p}\n" for p in ["x", "y", "z", "opacity"])
            + "end_header\n"
        ).encode())
        f.write(np.column_stack([pts, opa]).astype("<f4").tobytes())


def run(args: list[str], cwd: Path):
    r = subprocess.run([sys.executable, str(TOOL), *args], capture_output=True, text=True, cwd=cwd)
    return r.returncode, r.stdout + r.stderr


def main() -> int:
    fails = 0
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        write_sparse(root / "clean")
        write_sparse(root / "rolled", "flip_up")
        write_sparse(root / "facing_away", "neg_fwd")
        write_result_ply(root / "full.ply")
        write_result_ply(root / "cut.ply", cut=True)

        cases = [
            ("clean", ["--dataset", "clean", "--result-ply", "full.ply", "--out", "o1"], 0, "ALL PROBES CLEAN"),
            ("cut ply", ["--result-ply", "cut.ply", "--out", "o2"], 2, "CUT CONFIRMED"),
            ("rolled cams", ["--dataset", "rolled", "--out", "o3"], 2, "ROLLED"),
            ("facing away", ["--dataset", "facing_away", "--out", "o4"], 2, "BEHIND CAMERA"),
        ]
        for name, args, want_rc, want_text in cases:
            rc, out = run(args, root)
            ok = rc == want_rc and want_text in out
            print(f"{'PASS' if ok else 'FAIL'}: {name} (exit {rc}, expected {want_rc}, marker {want_text!r})")
            if not ok:
                fails += 1
                print(out[-1200:])
    print(f"\n{4 - fails}/4 passed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
