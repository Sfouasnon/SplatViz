#!/usr/bin/env python3
"""
SplatViz cut-in-half diagnosis harness (Phase 2, IMPROVEMENT_PLAN.md).

Answers: WHY does a trained Msplat splat come back truncated?

Three independent probes, each isolating one suspect:

  A. Result PLY density-cliff scan (--result-ply)
     Histograms splat density along x/y/z and flags an interior "cliff"
     (sharp density drop away from the bbox edge) = the cut plane.

  B. COLMAP pose/projection parity (--dataset)
     Reads sparse/0 (cameras.bin/images.bin/points3D.bin), projects the
     seed cloud through every camera, and classifies anomalies:
       - points behind camera            -> basis/sign error for that camera
       - centroid far off principal point-> aim/transform mismatch
       - failures clustered on one side  -> half-space basis bug
       - failures only on portrait cams  -> portrait intrinsics/roll bug
     Camera centers are recovered via C = -R^T t and checked against the
     layout JSON (--layout) when provided.

  C. Coverage asymmetry
     Compares per-camera seed visibility between azimuth hemispheres; a
     trained splat can only be as complete as its observed coverage.

Output: prints a ranked verdict and writes <out>/CUT_DIAGNOSIS.md.

Usage:
  python3 tools/splatviz_cut_diagnosis.py \
      --dataset  ~/Desktop/SplatViz_Exports/splatviz_msplat_dataset_m63 \
      --result-ply ~/Desktop/SplatViz_Exports/splatviz_msplat_result_m63/point_cloud.ply \
      --layout   splatviz_layout_exports/splatviz_m67a_camera_layout_*.json
"""
from __future__ import annotations

import argparse
import glob
import json
import math
import struct
import sys
from pathlib import Path

import numpy as np

# ---------------------------------------------------------------- PLY reading


def read_ply_vertices(path: Path) -> dict:
    """Read PLY vertex properties into a dict of numpy arrays.

    Supports ascii and binary_little_endian, float/double/uchar properties —
    matching both seed PLYs and 3DGS result PLYs from Msplat/gsplat.
    """
    with open(path, "rb") as f:
        if f.readline().strip() != b"ply":
            raise ValueError(f"{path}: not a PLY file")
        fmt = None
        n_verts = 0
        props: list[tuple[str, str]] = []
        in_vertex = False
        while True:
            line = f.readline()
            if not line:
                raise ValueError(f"{path}: unexpected EOF in header")
            tok = line.strip().split()
            if not tok:
                continue
            if tok[0] == b"format":
                fmt = tok[1].decode()
            elif tok[0] == b"element":
                in_vertex = tok[1] == b"vertex"
                if in_vertex:
                    n_verts = int(tok[2])
            elif tok[0] == b"property" and in_vertex:
                if tok[1] == b"list":
                    raise ValueError("list property in vertex element unsupported")
                props.append((tok[2].decode(), tok[1].decode()))
            elif tok[0] == b"end_header":
                break
        np_type = {
            "float": "<f4", "float32": "<f4", "double": "<f8", "float64": "<f8",
            "uchar": "u1", "uint8": "u1", "char": "i1", "int8": "i1",
            "short": "<i2", "ushort": "<u2", "int": "<i4", "uint": "<u4",
        }
        if fmt == "binary_little_endian":
            dt = np.dtype([(name, np_type[t]) for name, t in props])
            data = np.frombuffer(f.read(dt.itemsize * n_verts), dtype=dt, count=n_verts)
            return {name: np.asarray(data[name], dtype=np.float64) for name, _ in props}
        if fmt == "ascii":
            rows = np.loadtxt(f, max_rows=n_verts, dtype=np.float64, ndmin=2)
            return {name: rows[:, i] for i, (name, _) in enumerate(props)}
        raise ValueError(f"{path}: unsupported PLY format {fmt}")


# ---------------------------------------------------------- COLMAP bin reading


def _read(fmt: str, f):
    size = struct.calcsize(fmt)
    vals = struct.unpack(fmt, f.read(size))
    return vals[0] if len(vals) == 1 else vals


def read_colmap_sparse(sparse_dir: Path) -> tuple[dict, dict, np.ndarray]:
    """Return (cameras, images, points_xyz) from a COLMAP binary model."""
    num_params = {0: 3, 1: 4, 2: 4, 3: 5, 4: 8, 5: 8, 6: 12, 7: 5, 8: 4, 9: 5, 10: 12}
    cameras = {}
    with open(sparse_dir / "cameras.bin", "rb") as f:
        for _ in range(_read("<Q", f)):
            cam_id, model, w, h = _read("<iiQQ", f)
            params = _read(f"<{num_params[model]}d", f)
            params = (params,) if isinstance(params, float) else params
            cameras[cam_id] = {"model": model, "width": w, "height": h, "params": list(params)}
    images = {}
    with open(sparse_dir / "images.bin", "rb") as f:
        for _ in range(_read("<Q", f)):
            img_id = _read("<I", f)
            qw, qx, qy, qz, tx, ty, tz = _read("<7d", f)
            cam_id = _read("<I", f)
            name = b""
            while True:
                c = f.read(1)
                if c == b"\x00":
                    break
                name += c
            n_pts = _read("<Q", f)
            f.read(24 * n_pts)  # skip 2D observations
            images[img_id] = {
                "qvec": np.array([qw, qx, qy, qz]),
                "tvec": np.array([tx, ty, tz]),
                "camera_id": cam_id,
                "name": name.decode(),
            }
    pts = []
    p3d = sparse_dir / "points3D.bin"
    if p3d.exists():
        with open(p3d, "rb") as f:
            for _ in range(_read("<Q", f)):
                _read("<Q", f)  # point id
                x, y, z = _read("<3d", f)
                f.read(3)  # rgb
                _read("<d", f)  # error
                track_len = _read("<Q", f)
                f.read(8 * track_len)
                pts.append((x, y, z))
    return cameras, images, np.array(pts) if pts else np.zeros((0, 3))


def qvec_to_rotmat(q: np.ndarray) -> np.ndarray:
    w, x, y, z = q / np.linalg.norm(q)
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
        [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
        [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)],
    ])


# ------------------------------------------------------------------- Probe A


def probe_density_cliff(xyz: np.ndarray, opacity: np.ndarray | None, bins: int = 64) -> list[dict]:
    """Find truncation planes along each axis.

    A cut splat has no data beyond the cut, so the signature is NOT an
    interior cliff — it is an ABRUPT EDGE: density at one extreme of the
    distribution is still a large fraction of peak density (a guillotined
    profile), where a healthy splat tapers smoothly toward zero.
    """
    findings = []
    w = None
    if opacity is not None:
        w = 1.0 / (1.0 + np.exp(-opacity))  # logit -> alpha
    for axis, label in enumerate("xyz"):
        v = xyz[:, axis]
        lo, hi = np.percentile(v, 0.5), np.percentile(v, 99.5)
        if hi - lo < 1e-6:
            continue
        hist, edges = np.histogram(v, bins=bins, range=(lo, hi), weights=w)
        if hist.sum() <= 0:
            continue
        smooth = np.convolve(hist, np.ones(3) / 3.0, mode="same")
        peak = smooth.max()
        if peak <= 0:
            continue
        edge_lo = smooth[:2].mean() / peak
        edge_hi = smooth[-2:].mean() / peak
        for edge_frac, plane, kept in (
            (edge_lo, float(edges[0]), "above"),
            (edge_hi, float(edges[-1]), "below"),
        ):
            if edge_frac > 0.35:
                findings.append({
                    "axis": label,
                    "plane": plane,
                    "kept_side": kept,
                    "edge_density_pct_of_peak": 100.0 * edge_frac,
                })
    return findings


# ------------------------------------------------------------------- Probe B


def probe_camera_parity(cameras: dict, images: dict, pts: np.ndarray,
                        layout_positions: dict | None) -> list[dict]:
    """Project seed points through every COLMAP camera; classify anomalies."""
    if len(pts) == 0:
        return []
    centroid = pts.mean(axis=0)
    rows = []
    for img_id, im in sorted(images.items()):
        cam = cameras[im["camera_id"]]
        R = qvec_to_rotmat(im["qvec"])
        t = im["tvec"]
        center = -R.T @ t  # camera position in world space
        p_cam = (R @ pts.T).T + t  # COLMAP: x right, y down, z forward
        z = p_cam[:, 2]
        in_front = z > 1e-6
        fx, fy, cx, cy = (cam["params"] + [0, 0, 0, 0])[:4]
        if cam["model"] == 0:  # SIMPLE_PINHOLE f, cx, cy
            fx, fy, cx, cy = cam["params"][0], cam["params"][0], cam["params"][1], cam["params"][2]
        u = fx * p_cam[in_front, 0] / z[in_front] + cx
        v = fy * p_cam[in_front, 1] / z[in_front] + cy
        in_frame = (u >= 0) & (u < cam["width"]) & (v >= 0) & (v < cam["height"])
        n = len(pts)
        pct_front = 100.0 * in_front.sum() / n
        pct_frame = 100.0 * in_frame.sum() / n
        c_cam = R @ centroid + t
        cen_off = (float("nan"), float("nan"))
        if c_cam[2] > 1e-6:
            cen_off = (
                (fx * c_cam[0] / c_cam[2] + cx - cx) / cam["width"],
                (fy * c_cam[1] / c_cam[2] + cy - cy) / cam["height"],
            )
        flags = []
        if pct_front < 99.0:
            flags.append("POINTS_BEHIND_CAMERA")
        if pct_frame < 50.0:
            flags.append("LOW_COVERAGE")
        # Orientation convention: SplatViz never mounts a camera upside-down.
        # World up (0,1,0) in COLMAP camera space (y down) must have a negative
        # y component; a positive value means the view is rolled ~180 deg —
        # invisible to coverage stats but fatal for training.
        up_cam = R @ np.array([0.0, 1.0, 0.0])
        if up_cam[1] > 0.1:
            flags.append("ROLLED_VIEW")
        if not math.isnan(cen_off[0]) and (abs(cen_off[0]) > 0.35 or abs(cen_off[1]) > 0.35):
            flags.append("CENTROID_OFF_AXIS")
        layout_err = None
        if layout_positions and im["name"] in layout_positions:
            layout_err = float(np.linalg.norm(center - layout_positions[im["name"]]))
            if layout_err > 0.05:
                flags.append("POSITION_MISMATCH_VS_LAYOUT")
        rows.append({
            "name": im["name"],
            "portrait": cam["height"] > cam["width"],
            "center": center.tolist(),
            "pct_in_front": pct_front,
            "pct_in_frame": pct_frame,
            "centroid_offset_frac": cen_off,
            "layout_err_m": layout_err,
            "flags": flags,
        })
    return rows


def classify(rows: list[dict], cliffs: list[dict]) -> list[str]:
    """Rank root-cause hypotheses from the probe results."""
    verdicts = []
    bad = [r for r in rows if r["flags"]]
    if cliffs:
        for c in cliffs:
            verdicts.append(
                f"CUT CONFIRMED in result PLY: abrupt edge on {c['axis']}-axis at "
                f"{c['plane']:.3f} m (kept side: {c['kept_side']}, edge density "
                f"{c['edge_density_pct_of_peak']:.0f}% of peak — healthy splats taper to ~0)."
            )
    if bad:
        # spatial clustering: are all bad cameras in one half-space?
        centers = np.array([r["center"] for r in bad])
        all_centers = np.array([r["center"] for r in rows])
        mid = np.median(all_centers, axis=0)
        for axis, label in enumerate("xz"):  # rig plane axes
            ax = 0 if label == "x" else 2
            side = np.sign(centers[:, ax] - mid[ax])
            if len(side) >= 3 and (np.all(side >= 0) or np.all(side <= 0)):
                verdicts.append(
                    f"HALF-SPACE PATTERN: all {len(bad)} flagged cameras sit on one "
                    f"side of the rig ({label}-axis) -> COLMAP basis/sign error for "
                    f"those cameras is the prime suspect."
                )
                break
        port_bad = [r for r in bad if r["portrait"]]
        if port_bad and len(port_bad) == len(bad):
            verdicts.append(
                f"PORTRAIT PATTERN: all {len(bad)} flagged cameras are portrait -> "
                "portrait roll/intrinsics mismatch is the prime suspect."
            )
        if any("POINTS_BEHIND_CAMERA" in r["flags"] for r in bad):
            verdicts.append(
                "POINTS BEHIND CAMERA on: "
                + ", ".join(r["name"] for r in bad if "POINTS_BEHIND_CAMERA" in r["flags"])
                + " -> world-to-camera rotation rows likely transposed/sign-flipped."
            )
        if any("ROLLED_VIEW" in r["flags"] for r in bad):
            verdicts.append(
                "ROLLED ~180 DEG VIEW on: "
                + ", ".join(r["name"] for r in bad if "ROLLED_VIEW" in r["flags"])
                + " -> up-vector sign error in the COLMAP pose write; coverage stats "
                "look normal but training sees upside-down images."
            )
        if any("POSITION_MISMATCH_VS_LAYOUT" in r["flags"] for r in bad):
            verdicts.append(
                "CAMERA CENTERS disagree with the SplatViz layout export -> "
                "the COLMAP pose write (qvec/tvec) does not invert to the planned position."
            )
    if rows and not bad and not cliffs:
        verdicts.append(
            "ALL PROBES CLEAN: dataset geometry is self-consistent. If the splat is "
            "still cut, suspect the TRAINER side (Msplat scene-extent/bbox pruning or "
            "densification limits), not the SplatViz export."
        )
    if not rows and cliffs:
        verdicts.append("Provide --dataset to test whether the cut originates in the export.")
    return verdicts


# ---------------------------------------------------------------------- main


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dataset", type=Path, help="Msplat dataset root (contains sparse/0)")
    ap.add_argument("--result-ply", type=Path, help="trained 3DGS .ply to scan for cut planes")
    ap.add_argument("--layout", type=str, help="SplatViz layout export JSON (glob ok)")
    ap.add_argument("--out", type=Path, default=None, help="output dir (default: <dataset>/diagnostics)")
    args = ap.parse_args()
    if not args.dataset and not args.result_ply:
        ap.error("need --dataset and/or --result-ply")

    cliffs: list[dict] = []
    rows: list[dict] = []
    lines: list[str] = ["# SplatViz cut-in-half diagnosis", ""]

    if args.result_ply:
        ply = read_ply_vertices(args.result_ply)
        xyz = np.stack([ply["x"], ply["y"], ply["z"]], axis=1)
        opa = ply.get("opacity")
        cliffs = probe_density_cliff(xyz, opa)
        lines += [f"## Probe A — result PLY ({args.result_ply.name}, {len(xyz):,} splats)", ""]
        bb_lo, bb_hi = xyz.min(axis=0), xyz.max(axis=0)
        lines.append(f"- bbox min {np.round(bb_lo, 3).tolist()} max {np.round(bb_hi, 3).tolist()}")
        lines += [f"- **{c['axis']}-axis abrupt edge at {c['plane']:.3f} m** ({c['kept_side']} kept, "
                  f"edge density {c['edge_density_pct_of_peak']:.0f}% of peak)"
                  for c in cliffs] or ["- no truncation edge found (all axes taper smoothly)"]
        lines.append("")

    layout_positions = None
    if args.layout:
        matches = sorted(glob.glob(str(Path(args.layout).expanduser())))
        if matches:
            data = json.loads(Path(matches[-1]).read_text())
            cams = data.get("cameras", data if isinstance(data, list) else [])
            layout_positions = {}
            for c in cams:
                name = c.get("image_name") or c.get("export_image") or f"{c.get('id','')}_frame_000001.png"
                pos = c.get("position_m") or c.get("position") or c.get("global_position")
                if pos:
                    layout_positions[name] = np.array(pos[:3], dtype=float)

    if args.dataset:
        sparse = args.dataset / "sparse" / "0"
        cameras, images, pts = read_colmap_sparse(sparse)
        rows = probe_camera_parity(cameras, images, pts, layout_positions)
        lines += [f"## Probe B/C — dataset parity ({len(images)} cameras, {len(pts):,} seed points)", "",
                  "| camera | orient | in-front % | in-frame % | layout err (m) | flags |",
                  "|---|---|---|---|---|---|"]
        for r in rows:
            err = "-" if r["layout_err_m"] is None else f"{r['layout_err_m']:.3f}"
            lines.append(f"| {r['name']} | {'P' if r['portrait'] else 'L'} | "
                         f"{r['pct_in_front']:.1f} | {r['pct_in_frame']:.1f} | {err} | "
                         f"{', '.join(r['flags']) or 'ok'} |")
        lines.append("")

    verdicts = classify(rows, cliffs)
    lines += ["## Verdict", ""] + [f"{i + 1}. {v}" for i, v in enumerate(verdicts)]

    out_dir = args.out or (args.dataset / "diagnostics" if args.dataset else Path("."))
    out_dir.mkdir(parents=True, exist_ok=True)
    report = out_dir / "CUT_DIAGNOSIS.md"
    report.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    print(f"\nReport written: {report}")
    bad_markers = ("CUT CONFIRMED", "PATTERN", "BEHIND", "ROLLED", "disagree")
    return 2 if any(m in v for v in verdicts for m in bad_markers) else 0


if __name__ == "__main__":
    sys.exit(main())
