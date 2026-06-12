#!/usr/bin/env python3
import argparse
import json
import math
import struct
from pathlib import Path

PLY_TYPES = {
    "char": "b", "uchar": "B", "int8": "b", "uint8": "B",
    "short": "h", "ushort": "H", "int16": "h", "uint16": "H",
    "int": "i", "uint": "I", "int32": "i", "uint32": "I",
    "float": "f", "float32": "f", "double": "d", "float64": "d",
}

CAMERA_MODELS = {
    0: ("SIMPLE_PINHOLE", 3),
    1: ("PINHOLE", 4),
    2: ("SIMPLE_RADIAL", 4),
    3: ("RADIAL", 5),
    4: ("OPENCV", 8),
    5: ("OPENCV_FISHEYE", 8),
    6: ("FULL_OPENCV", 12),
    7: ("FOV", 5),
    8: ("SIMPLE_RADIAL_FISHEYE", 4),
    9: ("RADIAL_FISHEYE", 5),
    10: ("THIN_PRISM_FISHEYE", 12),
}


def read_cstring(data, offset):
    end = data.index(b"\x00", offset)
    return data[offset:end].decode("utf-8", errors="replace"), end + 1


def parse_colmap_images_bin(path):
    path = Path(path)
    if not path.exists():
        return []

    data = path.read_bytes()
    off = 0
    n_images = struct.unpack_from("<Q", data, off)[0]
    off += 8
    images = []

    for _ in range(n_images):
        image_id = struct.unpack_from("<i", data, off)[0]
        off += 4

        qvec = struct.unpack_from("<dddd", data, off)
        off += 32

        tvec = struct.unpack_from("<ddd", data, off)
        off += 24

        camera_id = struct.unpack_from("<i", data, off)[0]
        off += 4

        name, off = read_cstring(data, off)

        n_points2d = struct.unpack_from("<Q", data, off)[0]
        off += 8

        # x, y, point3D_id per observation
        off += n_points2d * (8 + 8 + 8)

        images.append({
            "image_id": image_id,
            "camera_id": camera_id,
            "name": name,
            "qvec": qvec,
            "tvec": tvec,
            "points2d": n_points2d,
        })

    return images


def parse_colmap_cameras_bin(path):
    path = Path(path)
    if not path.exists():
        return []

    data = path.read_bytes()
    off = 0
    n_cameras = struct.unpack_from("<Q", data, off)[0]
    off += 8
    cameras = []

    for _ in range(n_cameras):
        camera_id = struct.unpack_from("<i", data, off)[0]
        off += 4

        model_id = struct.unpack_from("<i", data, off)[0]
        off += 4

        width = struct.unpack_from("<Q", data, off)[0]
        off += 8

        height = struct.unpack_from("<Q", data, off)[0]
        off += 8

        model_name, n_params = CAMERA_MODELS.get(model_id, (f"UNKNOWN_{model_id}", 0))
        params = struct.unpack_from("<" + "d" * n_params, data, off) if n_params else ()
        off += 8 * n_params

        cameras.append({
            "camera_id": camera_id,
            "model": model_name,
            "width": width,
            "height": height,
            "params": params,
        })

    return cameras


def parse_colmap_points3d_bin(path):
    path = Path(path)
    if not path.exists():
        return {"count": 0, "finite_xyz": 0, "track_observations": 0, "bounds": None}

    data = path.read_bytes()
    off = 0
    n_points = struct.unpack_from("<Q", data, off)[0]
    off += 8

    finite_xyz = 0
    track_obs = 0
    mins = [float("inf"), float("inf"), float("inf")]
    maxs = [float("-inf"), float("-inf"), float("-inf")]

    for _ in range(n_points):
        _pid = struct.unpack_from("<Q", data, off)[0]
        off += 8

        xyz = struct.unpack_from("<ddd", data, off)
        off += 24

        off += 3  # rgb
        off += 8  # error

        track_len = struct.unpack_from("<Q", data, off)[0]
        off += 8

        track_obs += track_len
        off += track_len * (4 + 4)

        if all(math.isfinite(v) for v in xyz):
            finite_xyz += 1
            for i, v in enumerate(xyz):
                mins[i] = min(mins[i], v)
                maxs[i] = max(maxs[i], v)

    bounds = None
    if finite_xyz:
        bounds = [(mins[i], maxs[i], maxs[i] - mins[i]) for i in range(3)]

    return {
        "count": n_points,
        "finite_xyz": finite_xyz,
        "track_observations": track_obs,
        "bounds": bounds,
    }


def parse_ply(path):
    path = Path(path)
    if not path.exists():
        return {"exists": False}

    data = path.read_bytes()
    marker = b"end_header\n"
    header_end = data.find(marker)
    if header_end < 0:
        marker = b"end_header\r\n"
        header_end = data.find(marker)
    if header_end < 0:
        return {"exists": True, "error": "No PLY end_header marker"}

    header_bytes = data[:header_end + len(marker)]
    body = data[header_end + len(marker):]
    header = header_bytes.decode("utf-8", errors="replace").splitlines()

    fmt = None
    vertex_count = 0
    vertex_props = []
    in_vertex = False

    for line in header:
        parts = line.strip().split()
        if not parts:
            continue
        if parts[0] == "format":
            fmt = parts[1]
        elif parts[0] == "element":
            in_vertex = parts[1] == "vertex"
            if in_vertex:
                vertex_count = int(parts[2])
        elif parts[0] == "property" and in_vertex:
            if parts[1] == "list":
                continue
            vertex_props.append((parts[2], parts[1]))

    names = [p[0] for p in vertex_props]
    prop_types = [p[1] for p in vertex_props]

    if fmt == "ascii":
        rows = []
        for line in body.decode("utf-8", errors="replace").splitlines()[:vertex_count]:
            vals = line.split()
            if len(vals) >= len(names):
                rows.append([float(v) for v in vals[:len(names)]])
        return audit_ply_rows(path, header, names, rows)

    if fmt != "binary_little_endian":
        return {"exists": True, "error": f"Unsupported PLY format: {fmt}", "header": header}

    row_fmt = "<" + "".join(PLY_TYPES[t] for t in prop_types)
    row_size = struct.calcsize(row_fmt)
    rows = []

    for i in range(vertex_count):
        start = i * row_size
        end = start + row_size
        if end > len(body):
            break
        rows.append(struct.unpack(row_fmt, body[start:end]))

    return audit_ply_rows(path, header, names, rows)


def finite_count_for(names, rows, wanted):
    idx = [names.index(n) for n in wanted if n in names]
    if not idx:
        return None
    return sum(1 for row in rows if all(math.isfinite(row[i]) for i in idx))


def audit_ply_rows(path, header, names, rows):
    n = len(rows)
    xyz_names = ["x", "y", "z"]
    xyz_idx = [names.index(nm) for nm in xyz_names if nm in names]

    finite_xyz = 0
    mins = [float("inf"), float("inf"), float("inf")]
    maxs = [float("-inf"), float("-inf"), float("-inf")]

    for row in rows:
        if len(xyz_idx) == 3 and all(math.isfinite(row[i]) for i in xyz_idx):
            finite_xyz += 1
            for j, i in enumerate(xyz_idx):
                v = row[i]
                mins[j] = min(mins[j], v)
                maxs[j] = max(maxs[j], v)

    bounds = None
    if finite_xyz:
        bounds = [(mins[i], maxs[i], maxs[i] - mins[i]) for i in range(3)]

    scale_fields = [n for n in names if n.startswith("scale")]
    rot_fields = [n for n in names if n.startswith("rot")]
    opacity_fields = [n for n in names if n == "opacity" or n.startswith("opacity")]
    sh_fields = [n for n in names if n.startswith("f_dc") or n.startswith("f_rest")]

    return {
        "exists": True,
        "path": str(path),
        "header_first_lines": header[:20],
        "declared_or_read_vertices": n,
        "properties": names,
        "finite_xyz": finite_xyz,
        "bad_xyz": n - finite_xyz,
        "finite_scale_rows": finite_count_for(names, rows, scale_fields),
        "finite_rotation_rows": finite_count_for(names, rows, rot_fields),
        "finite_opacity_rows": finite_count_for(names, rows, opacity_fields),
        "finite_sh_rows": finite_count_for(names, rows, sh_fields),
        "bounds": bounds,
    }


def print_bounds(label, bounds):
    if not bounds:
        print(f"{label}: none")
        return
    print(f"{label}:")
    for axis, b in zip(["x", "y", "z"], bounds):
        print(f"  {axis}: min={b[0]: .6f}, max={b[1]: .6f}, span={b[2]: .6f}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True)
    parser.add_argument("--splat", required=False)
    args = parser.parse_args()

    dataset = Path(args.dataset)
    sparse = dataset / "sparse" / "0"
    transforms_path = dataset / "transforms.json"

    print("=== SplatViz dataset audit ===")
    print(f"dataset: {dataset}")
    print(f"exists: {dataset.exists()}")
    print(f"images dir: {(dataset / 'images').exists()}")
    print(f"sparse/0: {sparse.exists()}")
    print()

    print("=== transforms.json ===")
    if transforms_path.exists():
        tr = json.loads(transforms_path.read_text())
        frames = tr.get("frames", [])
        top_intr = [k for k in ["fl_x", "fl_y", "cx", "cy", "w", "h"] if k in tr]
        print(f"present: yes")
        print(f"top-level intrinsics: {top_intr if top_intr else 'absent'}")
        print(f"frame count: {len(frames)}")
        sample_fl = []
        sample_files = []
        for f in frames[:8]:
            sample_fl.append(str(f.get("fl_x", "missing")))
            sample_files.append(str(f.get("file_path", "missing")))
        print(f"sample fl_x: {', '.join(sample_fl)}")
        print("sample frame paths:")
        for p in sample_files:
            print(f"  {p}")
    else:
        print("present: no")
    print()

    print("=== COLMAP sparse files ===")
    cameras_bin = sparse / "cameras.bin"
    images_bin = sparse / "images.bin"
    points_bin = sparse / "points3D.bin"
    print(f"cameras.bin: {cameras_bin.exists()}")
    print(f"images.bin: {images_bin.exists()}")
    print(f"points3D.bin: {points_bin.exists()}")
    print()

    cams = parse_colmap_cameras_bin(cameras_bin)
    imgs = parse_colmap_images_bin(images_bin)
    pts = parse_colmap_points3d_bin(points_bin)

    print("=== COLMAP cameras ===")
    print(f"camera count: {len(cams)}")
    for c in cams[:8]:
        params = ", ".join(f"{p:.3f}" for p in c["params"])
        print(f"  id={c['camera_id']} model={c['model']} size={c['width']}x{c['height']} params=[{params}]")
    print()

    print("=== COLMAP images/name resolution ===")
    print(f"image records: {len(imgs)}")
    missing_sparse = []
    missing_dataset_images = []
    for im in imgs:
        name = im["name"]
        if not (sparse / name).exists():
            missing_sparse.append(name)
        if not (dataset / "images" / name).exists():
            missing_dataset_images.append(name)

    print(f"resolved beside sparse/0: {len(imgs) - len(missing_sparse)} / {len(imgs)}")
    print(f"resolved in dataset/images: {len(imgs) - len(missing_dataset_images)} / {len(imgs)}")
    if missing_sparse:
        print("first sparse/0 missing names:")
        for m in missing_sparse[:10]:
            print(f"  {m}")
    if missing_dataset_images:
        print("first dataset/images missing names:")
        for m in missing_dataset_images[:10]:
            print(f"  {m}")
    print("sample image records:")
    for im in imgs[:8]:
        print(f"  id={im['image_id']} cam={im['camera_id']} name={im['name']} q={tuple(round(v, 6) for v in im['qvec'])} points2D={im['points2d']}")
    print()

    print("=== COLMAP points3D ===")
    print(f"point count: {pts['count']}")
    print(f"finite xyz: {pts['finite_xyz']}")
    print(f"track observations: {pts['track_observations']}")
    if pts["count"]:
        print(f"avg observations per point: {pts['track_observations'] / pts['count']:.3f}")
    print_bounds("points3D bounds", pts["bounds"])
    print()

    if args.splat:
        print("=== Msplat PLY audit ===")
        ply = parse_ply(args.splat)
        if not ply.get("exists"):
            print(f"PLY missing: {args.splat}")
        elif ply.get("error"):
            print(f"PLY error: {ply['error']}")
        else:
            print(f"path: {ply['path']}")
            print(f"vertices/read rows: {ply['declared_or_read_vertices']}")
            print(f"properties: {', '.join(ply['properties'][:20])}{' ...' if len(ply['properties']) > 20 else ''}")
            print(f"finite XYZ: {ply['finite_xyz']}")
            print(f"bad XYZ: {ply['bad_xyz']}")
            print(f"finite scale rows: {ply['finite_scale_rows']}")
            print(f"finite rotation rows: {ply['finite_rotation_rows']}")
            print(f"finite opacity rows: {ply['finite_opacity_rows']}")
            print(f"finite SH/color rows: {ply['finite_sh_rows']}")
            print_bounds("finite XYZ bounds", ply["bounds"])
            if ply["declared_or_read_vertices"]:
                bad_pct = 100.0 * ply["bad_xyz"] / ply["declared_or_read_vertices"]
                print(f"bad XYZ percent: {bad_pct:.2f}%")
    print()

    print("=== Interpretation hints ===")
    print("- missing sparse/0 images means Msplat will fail or resolve the wrong files.")
    print("- zero or tiny COLMAP tracks means the sparse bridge is weak.")
    print("- many finite XYZ but bad scale/rotation/opacity means the Gaussian PLY is broken even if points draw.")
    print("- tiny finite XYZ bounds may be okay only if SplatViz is auto-fitting; compare against seed/robot scale.")


if __name__ == "__main__":
    main()
