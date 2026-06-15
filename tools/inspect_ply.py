#!/usr/bin/env python3
"""Dump a PLY's header + per-property min/max/first values.

Tells us whether 'all-zero positions' is real or a parser/naming artifact:
if some OTHER property holds the spatial range, positions live under a
different name; if every property is trivial, the writer is broken.

Usage:
  python3 tools/inspect_ply.py <file.ply>
"""
import sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from splatviz_cut_diagnosis import read_ply_vertices


def main() -> int:
    path = Path(sys.argv[1])

    # raw header
    print("== RAW HEADER ==")
    with open(path, "rb") as f:
        for _ in range(80):
            line = f.readline()
            try:
                txt = line.decode("ascii", "replace").rstrip("\n")
            except Exception:
                txt = repr(line)
            print("  " + txt)
            if line.strip() == b"end_header":
                break

    # parsed properties
    print("\n== PER-PROPERTY min / max / first5 ==")
    data = read_ply_vertices(path)
    for name, arr in data.items():
        arr = np.asarray(arr, dtype=np.float64)
        first5 = ", ".join(f"{v:+.4f}" for v in arr[:5])
        flag = "  <-- has spatial range" if (arr.max() - arr.min()) > 1e-6 and name not in ("x", "y", "z") else ""
        print(f"  {name:14s} min={arr.min():+.4f}  max={arr.max():+.4f}  first5=[{first5}]{flag}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
