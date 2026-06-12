#!/usr/bin/env python3
import argparse, json
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

def main():
    ap = argparse.ArgumentParser(description="Compare two SplatViz frames for camera/render parity.")
    ap.add_argument("a"); ap.add_argument("b"); ap.add_argument("--json", dest="json_out")
    args = ap.parse_args(); a = Path(args.a).expanduser(); b = Path(args.b).expanduser()
    ia = Image.open(a).convert("RGB"); ib = Image.open(b).convert("RGB")
    result = {"a": str(a), "b": str(b), "a_size": list(ia.size), "b_size": list(ib.size), "same_dimensions": ia.size == ib.size, "frame_policy": "same dimensions and same camera frame; scale-only, no crop, no squeeze"}
    if ia.size == ib.size:
        diff = ImageChops.difference(ia, ib); stat = ImageStat.Stat(diff); result.update({"mean_abs_rgb_diff": sum(stat.mean)/3.0, "max_channel_diff": max(x[1] for x in diff.getextrema())})
    if args.json_out: Path(args.json_out).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
if __name__ == "__main__": main()
