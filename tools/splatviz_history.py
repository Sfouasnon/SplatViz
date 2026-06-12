#!/usr/bin/env python3
import argparse, json, re
from pathlib import Path
from datetime import datetime
from typing import Any, Dict, List, Optional

SCHEMA = "splatviz.project_history.v1"
PROFILE_SCHEMA = "splatviz.run_profiles.v1"

def now() -> str:
    return datetime.now().isoformat(timespec="seconds")

def default_profiles() -> Dict[str, Any]:
    return {
        "schema": PROFILE_SCHEMA,
        "created_at": now(),
        "default_focus": "1080p_quality",
        "frame_policy": "scale-only; preserve original camera frame; no crop; no squeeze",
        "capacity_handles": {
            "min_free_disk_gib_warning": 20,
            "min_free_disk_gib_hard_stop": 8,
            "stall_log_heartbeat_seconds": 900,
            "intersection_multiplier_warn": 100,
            "intersection_multiplier_stop": 160,
            "note": "These are handles, not machine-specific constants. Tune per workstation."
        },
        "profiles": [
            {"name": "1080p_laptop_safe", "resolution": [1920, 1080], "num_iters": 10000, "densify_grad_thresh": 0.001, "purpose": "Conservative 1080p iteration."},
            {"name": "1080p_quality", "resolution": [1920, 1080], "num_iters": 10000, "densify_grad_thresh": 0.0005, "target_reference": "M64", "purpose": "Primary near-term quality lane."},
            {"name": "4k_smoke", "resolution": [3840, 2160], "num_iters": 1500, "densify_grad_thresh": 0.0005, "purpose": "Dataset validation only."},
            {"name": "4k_controlled", "resolution": [3840, 2160], "num_iters": 3000, "densify_grad_thresh": 0.002, "purpose": "Small 4K experiments only."},
            {"name": "custom", "resolution": "user_defined", "num_iters": "user_defined", "densify_grad_thresh": "user_defined", "purpose": "Expose tuning handles without hard-coding for one machine."}
        ]
    }

def default_history(project_root: Path, exports_root: Path) -> Dict[str, Any]:
    return {
        "schema": SCHEMA,
        "project": "SplatViz",
        "created_at": now(),
        "project_root": str(project_root),
        "exports_root": str(exports_root),
        "storage_policy": {"large_artifacts": "Keep only current winners/candidates in SplatViz_Exports.", "metadata_ledger": "Preserve run facts and decisions in this small JSON file inside the project folder.", "do_not_require_full_dataset_archive": True},
        "frame_policy": "1080p downscale must preserve full camera frame; no crop; no squeeze.",
        "roadmap": {"active_focus": ["1080p professional-quality 3DGS", "1:1 Camera POV vs rendered still parity", "Export Camera Layout CSV/JSON", "True anisotropic 3DGS Splat View renderer"], "defer": ["4K full training until storage/capacity is available", "More COLMAP experiments unless camera/render parity fails"]},
        "runs": [],
        "decisions": [{"timestamp": now(), "decision": "Recenter to 1080p first; treat 4K as smoke/source tests only for now.", "reason": "4K dataset path works, but quality/capacity/storage are not productive yet."}]
    }

def load_json(path: Path, fallback: Dict[str, Any]) -> Dict[str, Any]:
    if path.exists():
        try:
            return json.loads(path.read_text())
        except Exception:
            pass
    return fallback

def save_json(path: Path, data: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n")

def parse_train_log(log_path: Path) -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    if not log_path.exists():
        return out
    txt = log_path.read_text(errors="replace")
    out["train_log"] = str(log_path)
    out["train_log_bytes"] = log_path.stat().st_size
    for key, pat in [("psnr", r"PSNR:\s*([0-9.]+)"), ("ssim", r"SSIM:\s*([0-9.]+)"), ("l1", r"L1:\s*([0-9.]+)")]:
        m = re.search(pat, txt)
        if m: out[key] = float(m.group(1))
    m = re.search(r"Gaussians:\s*([0-9,]+)", txt)
    if m: out["gaussians_eval"] = int(m.group(1).replace(",", ""))
    steps = re.findall(r"step=\s*([0-9]+)\s+splats=\s*([0-9,]+)\s+ms=\s*([0-9.]+)", txt)
    if steps:
        st, sp, ms = steps[-1]
        out["last_step"] = int(st); out["last_splats"] = int(sp.replace(",", "")); out["last_ms"] = float(ms)
    overs = re.findall(r"intersection overflow \(actual=([0-9]+) > capacity=([0-9]+)\).*?multiplier to ([0-9]+)x", txt)
    if overs:
        out["intersection_overflow_last"] = {"actual": int(overs[-1][0]), "capacity": int(overs[-1][1]), "multiplier": int(overs[-1][2])}
        out["intersection_overflow_count"] = len(overs)
    if "Saved " in txt: out["saved_ply_logged"] = True
    return out

def detect_resolution(result_dir: Path, dataset_dir: Optional[Path]) -> Optional[List[int]]:
    roots = []
    if dataset_dir:
        roots += [dataset_dir / "images", dataset_dir / "sparse" / "0"]
    roots.append(result_dir)
    try:
        from PIL import Image
        for root in roots:
            if root and root.exists():
                for p in sorted(root.glob("*.png")):
                    with Image.open(p) as im:
                        return [int(im.size[0]), int(im.size[1])]
    except Exception:
        return None
    return None

def record_result(history: Dict[str, Any], result_dir: Path, dataset_dir: Optional[Path], label: Optional[str]) -> Dict[str, Any]:
    rec: Dict[str, Any] = {"timestamp": now(), "label": label or result_dir.name, "result_dir": str(result_dir), "dataset_dir": str(dataset_dir) if dataset_dir else None, "splat_ply_present": (result_dir / "splat.ply").exists(), "splat_ply_bytes": (result_dir / "splat.ply").stat().st_size if (result_dir / "splat.ply").exists() else 0}
    rec.update(parse_train_log(result_dir / "train.log"))
    res = detect_resolution(result_dir, dataset_dir)
    if res: rec["resolution"] = res
    runs = [r for r in history.get("runs", []) if r.get("result_dir") != str(result_dir)]
    runs.append(rec); history["runs"] = runs; history["latest"] = rec
    return rec

def scan_exports(project_root: Path, exports_root: Path, max_results: int) -> Dict[str, Any]:
    hist_path = project_root / "splatviz_project_history.json"
    hist = load_json(hist_path, default_history(project_root, exports_root))
    if not exports_root.exists():
        save_json(hist_path, hist); return {"added_or_updated": 0, "history": str(hist_path)}
    candidates = sorted([p for p in exports_root.iterdir() if p.is_dir() and "splatviz_msplat_result" in p.name], key=lambda p: p.stat().st_mtime, reverse=True)[:max_results]
    datasets = [p for p in exports_root.iterdir() if p.is_dir() and "splatviz_msplat_dataset" in p.name]
    added = 0
    for result in reversed(candidates):
        dataset = None
        tokens = re.findall(r"20[0-9]{6}_[0-9]{6}|KEEP_[0-9_]+|m6[0-9][a-z]?", result.name, re.I)
        for d in datasets:
            if any(tok in d.name for tok in tokens):
                dataset = d; break
        record_result(hist, result, dataset, None); added += 1
    hist["scanned_at"] = now(); save_json(hist_path, hist)
    return {"added_or_updated": added, "history": str(hist_path)}

def cmd_init(args):
    project_root = Path(args.project_root).expanduser(); exports_root = Path(args.exports_root).expanduser()
    hist_path = project_root / "splatviz_project_history.json"; prof_path = project_root / "splatviz_run_profiles.json"
    hist = load_json(hist_path, default_history(project_root, exports_root)); hist["project_root"] = str(project_root); hist["exports_root"] = str(exports_root); hist["updated_at"] = now(); save_json(hist_path, hist)
    if not prof_path.exists(): save_json(prof_path, default_profiles())
    print(json.dumps({"history": str(hist_path), "profiles": str(prof_path)}, indent=2))

def cmd_record(args):
    project_root = Path(args.project_root).expanduser(); exports_root = Path(args.exports_root).expanduser(); hist_path = project_root / "splatviz_project_history.json"
    hist = load_json(hist_path, default_history(project_root, exports_root)); rec = record_result(hist, Path(args.result_dir).expanduser(), Path(args.dataset_dir).expanduser() if args.dataset_dir else None, args.label); save_json(hist_path, hist); print(json.dumps(rec, indent=2))

def cmd_scan(args): print(json.dumps(scan_exports(Path(args.project_root).expanduser(), Path(args.exports_root).expanduser(), args.max_results), indent=2))

def cmd_summary(args):
    project_root = Path(args.project_root).expanduser(); hist_path = project_root / "splatviz_project_history.json"; hist = load_json(hist_path, default_history(project_root, Path.home()/"Desktop"/"SplatViz_Exports")); runs = hist.get("runs", [])
    print(f"history={hist_path}"); print(f"runs={len(runs)}")
    for r in sorted(runs, key=lambda r: (r.get("psnr") if isinstance(r.get("psnr"), (int, float)) else -999), reverse=True)[:8]:
        print(f"  psnr={r.get('psnr')} ssim={r.get('ssim')} gaussians={r.get('gaussians_eval') or r.get('last_splats')} label={r.get('label')}")

def main():
    ap = argparse.ArgumentParser(description="SplatViz project-level metadata history ledger")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("init"); p.add_argument("--project-root", required=True); p.add_argument("--exports-root", default=str(Path.home()/"Desktop"/"SplatViz_Exports")); p.set_defaults(func=cmd_init)
    p = sub.add_parser("record"); p.add_argument("--project-root", required=True); p.add_argument("--exports-root", default=str(Path.home()/"Desktop"/"SplatViz_Exports")); p.add_argument("--result-dir", required=True); p.add_argument("--dataset-dir"); p.add_argument("--label"); p.set_defaults(func=cmd_record)
    p = sub.add_parser("scan"); p.add_argument("--project-root", required=True); p.add_argument("--exports-root", default=str(Path.home()/"Desktop"/"SplatViz_Exports")); p.add_argument("--max-results", type=int, default=80); p.set_defaults(func=cmd_scan)
    p = sub.add_parser("summary"); p.add_argument("--project-root", required=True); p.set_defaults(func=cmd_summary)
    args = ap.parse_args(); args.func(args)
if __name__ == "__main__": main()
