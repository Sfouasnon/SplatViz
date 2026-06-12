#!/usr/bin/env python3
"""Build a print-friendly SplatViz camera layout HTML report from M67C layout JSON."""
from __future__ import annotations

import html
import json
import math
import sys
from pathlib import Path

PAGE_CSS = """
:root {
  --ink:#1c2430; --muted:#647083; --line:#9aa7b4; --grid:#d8e2ea; --accent:#1463ff;
  --soft:#f5f8fb; --panel:#ffffff; --teal:#1d7f8c; --warn:#b36b00;
}
* { box-sizing:border-box; }
body { margin:0; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif; color:var(--ink); background:#f2f4f7; }
.report { max-width:1280px; margin:0 auto; padding:28px; }
.sheet { background:var(--panel); border:1px solid #cfd8e3; border-radius:14px; padding:26px; margin:0 0 24px; box-shadow:0 6px 28px rgba(31,43,58,.08); page-break-after:always; }
.sheet:last-child { page-break-after:auto; }
h1 { font-size:32px; margin:0 0 8px; letter-spacing:.01em; }
h2 { font-size:22px; margin:0 0 18px; }
h3 { font-size:17px; margin:18px 0 8px; color:#26374a; }
.meta { color:var(--muted); line-height:1.45; font-size:14px; }
.kpis { display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:12px; margin:18px 0; }
.kpi { background:var(--soft); border:1px solid #d9e2ec; border-radius:10px; padding:12px; }
.kpi b { display:block; font-size:20px; margin-bottom:4px; }
.diagram { width:100%; border:1px solid #cdd6df; border-radius:12px; background:#fbfcfe; padding:8px; }
.grid2 { display:grid; grid-template-columns:1fr 1fr; gap:18px; }
table { width:100%; border-collapse:collapse; font-size:12px; }
th, td { border-bottom:1px solid #e2e8f0; padding:7px 6px; text-align:left; vertical-align:top; }
th { background:#eef3f8; color:#203044; font-weight:700; position:sticky; top:0; }
.cards { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:14px; }
.card { border:1px solid #d1dbe6; border-radius:12px; background:#fff; overflow:hidden; }
.card svg { display:block; width:100%; height:150px; background:#f8fbfd; border-bottom:1px solid #e1e8f0; }
.card .body { padding:10px; font-size:12px; line-height:1.38; }
.card .title { font-size:16px; font-weight:800; margin-bottom:4px; }
.badge { display:inline-block; padding:2px 7px; border-radius:999px; background:#e7f2ff; color:#1459bf; font-weight:700; font-size:11px; margin-left:6px; }
.note { background:#fff8e8; border:1px solid #f0d69b; border-radius:10px; padding:12px; color:#674600; }
.footer { margin-top:18px; color:#7a8594; font-size:11px; }
@media print {
  body { background:#fff; }
  .report { max-width:none; padding:0; }
  .sheet { border:0; box-shadow:none; border-radius:0; min-height:10in; margin:0; }
  .cards { grid-template-columns:repeat(3,1fr); }
}
"""


def ft_in(m: float) -> str:
    total_inches = int(round(m * 39.3700787402))
    feet, inches = divmod(total_inches, 12)
    return f"{feet}'-{inches}\""


def fmt(v: float, n: int = 2) -> str:
    try:
        return f"{float(v):.{n}f}"
    except Exception:
        return "0.00"


def esc(v) -> str:
    return html.escape(str(v), quote=True)


def stage_bounds(meta):
    return float(meta.get("stage_width_m", 17.98)), float(meta.get("stage_depth_m", 17.37))


def top_svg(rows, meta, *, w=1160, h=760) -> str:
    sw, sd = stage_bounds(meta)
    margin = 70
    scale = min((w - margin*2) / sw, (h - margin*2) / sd)
    cx, cy = w/2, h/2
    def xy(x,z):
        return cx + float(x)*scale, cy + float(z)*scale
    out = [f'<svg viewBox="0 0 {w} {h}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Top down camera layout">']
    out.append('<rect x="0" y="0" width="100%" height="100%" fill="#fbfcfe"/>')
    # grid
    grid_m = 1.0
    for gx in [i*grid_m - sw/2 for i in range(int(sw/grid_m)+2)]:
        x1,y1=xy(gx,-sd/2); x2,y2=xy(gx,sd/2)
        out.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="#dce6ef" stroke-width="1"/>')
    for gz in [i*grid_m - sd/2 for i in range(int(sd/grid_m)+2)]:
        x1,y1=xy(-sw/2,gz); x2,y2=xy(sw/2,gz)
        out.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="#dce6ef" stroke-width="1"/>')
    x0,y0=xy(-sw/2,-sd/2); x1,y1=xy(sw/2,sd/2)
    out.append(f'<rect x="{x0:.1f}" y="{y0:.1f}" width="{(x1-x0):.1f}" height="{(y1-y0):.1f}" fill="none" stroke="#1e293b" stroke-width="2"/>')
    # target/subject pad
    px,py=xy(0,0)
    out.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="8" fill="#111827"/><text x="{px+12:.1f}" y="{py-12:.1f}" font-size="15" font-weight="700">Subject / stage center</text>')
    # cardinal labels
    out.append(f'<text x="{cx:.1f}" y="{y0-22:.1f}" text-anchor="middle" font-size="18" font-weight="800">N / 0°</text>')
    out.append(f'<text x="{x1+22:.1f}" y="{cy:.1f}" font-size="18" font-weight="800">E / 90°</text>')
    out.append(f'<text x="{cx:.1f}" y="{y1+36:.1f}" text-anchor="middle" font-size="18" font-weight="800">S / 180°</text>')
    out.append(f'<text x="{x0-22:.1f}" y="{cy:.1f}" text-anchor="end" font-size="18" font-weight="800">W / 270°</text>')
    colors = {"low":"#2563eb", "mid":"#059669", "high":"#b45309"}
    for r in rows:
        x,z=float(r["x_m"]),float(r["z_m"])
        ax,ay=xy(x,z)
        tx,ty=xy(0,0)
        col=colors.get(str(r.get("tier","mid")),"#475569")
        out.append(f'<line x1="{ax:.1f}" y1="{ay:.1f}" x2="{tx:.1f}" y2="{ty:.1f}" stroke="{col}" stroke-opacity=".35" stroke-width="1.3"/>')
        out.append(f'<circle cx="{ax:.1f}" cy="{ay:.1f}" r="10" fill="{col}" stroke="#fff" stroke-width="2"/>')
        out.append(f'<text x="{ax+13:.1f}" y="{ay+5:.1f}" font-size="13" font-weight="800">{esc(r["camera_id"])}</text>')
    out.append(f'<text x="{margin}" y="{h-24}" font-size="14" fill="#475569">Stage boundary {fmt(sw)} m ({ft_in(sw)}) × {fmt(sd)} m ({ft_in(sd)}) · grid 1 m</text>')
    out.append('</svg>')
    return "\n".join(out)


def elevation_svg(rows, meta, axis="front", *, w=1160, h=520) -> str:
    sw, sd = stage_bounds(meta)
    span = sw if axis == "front" else sd
    max_h = max([float(r.get("height_m",0)) for r in rows] + [3.0]) + 0.6
    margin_l, margin_r, margin_t, margin_b = 72, 42, 42, 74
    sx = (w-margin_l-margin_r)/span
    sy = (h-margin_t-margin_b)/max_h
    def xcoord(v): return margin_l + (float(v) + span/2) * sx
    def ycoord(y): return h - margin_b - float(y) * sy
    title = "FRONT ELEVATION — X / height" if axis == "front" else "SIDE ELEVATION — Z / height"
    out=[f'<svg viewBox="0 0 {w} {h}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="{title}">']
    out.append('<rect width="100%" height="100%" fill="#fbfcfe"/>')
    out.append(f'<text x="{margin_l}" y="28" font-size="19" font-weight="800">{title}</text>')
    # axes / floor
    out.append(f'<line x1="{margin_l}" y1="{ycoord(0):.1f}" x2="{w-margin_r}" y2="{ycoord(0):.1f}" stroke="#1e293b" stroke-width="2"/>')
    for m in [0,0.72,1.55,2.45,3.0]:
        yy=ycoord(m)
        out.append(f'<line x1="{margin_l}" y1="{yy:.1f}" x2="{w-margin_r}" y2="{yy:.1f}" stroke="#dce6ef" stroke-width="1"/>')
        out.append(f'<text x="18" y="{yy+4:.1f}" font-size="13">{fmt(m,2)} m</text>')
    colors = {"low":"#2563eb", "mid":"#059669", "high":"#b45309"}
    for r in rows:
        coord = float(r["x_m"] if axis == "front" else r["z_m"])
        xx=xcoord(coord); yy=ycoord(float(r["height_m"]))
        col=colors.get(str(r.get("tier","mid")),"#475569")
        out.append(f'<line x1="{xx:.1f}" y1="{yy:.1f}" x2="{xcoord(0):.1f}" y2="{ycoord(float(meta.get("target_height_m",1.62))):.1f}" stroke="{col}" stroke-opacity=".3" stroke-width="1"/>')
        out.append(f'<rect x="{xx-8:.1f}" y="{yy-8:.1f}" width="16" height="16" rx="3" fill="{col}" stroke="#fff" stroke-width="2"/>')
        out.append(f'<text x="{xx+11:.1f}" y="{yy+4:.1f}" font-size="12" font-weight="700">{esc(r["camera_id"])}</text>')
    out.append(f'<text x="{margin_l}" y="{h-24}" font-size="13" fill="#475569">AFF = above finished floor. Sight lines point to target height {fmt(float(meta.get("target_height_m",1.62)),2)} m.</text>')
    out.append('</svg>')
    return "\n".join(out)


def frustum_card_svg(r, *, w=420, h=150):
    az=float(r.get("azimuth_deg",0))
    # Rotate mini top-down thumbnail so camera vector is readable.
    a=math.radians(az)
    cx,cy=w/2,h/2+10
    camx = cx + math.cos(a)*80
    camy = cy + math.sin(a)*45
    col = {"low":"#2563eb","mid":"#059669","high":"#b45309"}.get(str(r.get("tier","mid")),"#475569")
    return f'''<svg viewBox="0 0 {w} {h}" xmlns="http://www.w3.org/2000/svg">
<rect width="100%" height="100%" fill="#f8fbfd"/>
<line x1="{camx:.1f}" y1="{camy:.1f}" x2="{cx:.1f}" y2="{cy:.1f}" stroke="{col}" stroke-width="3" opacity=".55"/>
<path d="M {camx:.1f} {camy:.1f} L {cx-35:.1f} {cy+18:.1f} L {cx+35:.1f} {cy+18:.1f} Z" fill="{col}" opacity=".12" stroke="{col}" stroke-width="1.5"/>
<circle cx="{cx:.1f}" cy="{cy:.1f}" r="9" fill="#111827"/>
<rect x="{camx-12:.1f}" y="{camy-8:.1f}" width="24" height="16" rx="3" fill="{col}" stroke="#fff" stroke-width="2"/>
<text x="18" y="28" font-size="17" font-weight="800" fill="#1e293b">{esc(r.get('camera_id',''))}</text>
<text x="18" y="50" font-size="12" fill="#475569">Az {fmt(az,1)}° · Tilt {fmt(float(r.get('tilt_deg',0)),1)}°</text>
</svg>'''


def camera_cards(rows):
    blocks=[]
    for r in rows:
        body = f'''
<div class="card">
{frustum_card_svg(r)}
<div class="body">
  <div class="title">{esc(r.get('camera_id',''))}<span class="badge">{esc(r.get('tier',''))}</span></div>
  <b>Lens:</b> {esc(r.get('lens_name','Rokinon 24mm T5.6'))}<br/>
  <b>FOV:</b> HFOV {fmt(float(r.get('hfov_deg',0)),1)}° / VFOV {fmt(float(r.get('vfov_deg',0)),1)}° · fx {fmt(float(r.get('fx_px',0)),1)} px<br/>
  <b>Height:</b> {fmt(float(r.get('height_m',0)),2)} m / {esc(r.get('height_ft_in',''))} AFF<br/>
  <b>Distance:</b> floor {fmt(float(r.get('floor_dist_m',0)),2)} m / {esc(r.get('floor_dist_ft_in',''))}; 3D {fmt(float(r.get('distance_3d_m',0)),2)} m<br/>
  <b>Aim:</b> azimuth {fmt(float(r.get('azimuth_deg',0)),1)}° · tilt {fmt(float(r.get('tilt_deg',0)),1)}° · mount {esc(r.get('mount_zone',''))}<br/>
  <b>Position:</b> X {fmt(float(r.get('x_m',0)),2)} m · Y {fmt(float(r.get('y_m',0)),2)} m · Z {fmt(float(r.get('z_m',0)),2)} m
</div>
</div>'''
        blocks.append(body)
    return "\n".join(blocks)


def schedule_table(rows):
    head = "<tr><th>Cam</th><th>Tier</th><th>Az</th><th>Height AFF</th><th>Floor dist</th><th>3D dist</th><th>Tilt</th><th>Position XYZ m</th><th>Mount zone</th></tr>"
    trs=[]
    for r in rows:
        trs.append(
            f"<tr><td><b>{esc(r['camera_id'])}</b></td><td>{esc(r.get('tier',''))}</td><td>{fmt(float(r.get('azimuth_deg',0)),1)}°</td>"
            f"<td>{fmt(float(r.get('height_m',0)),2)} m / {esc(r.get('height_ft_in',''))}</td>"
            f"<td>{fmt(float(r.get('floor_dist_m',0)),2)} m / {esc(r.get('floor_dist_ft_in',''))}</td>"
            f"<td>{fmt(float(r.get('distance_3d_m',0)),2)} m / {esc(r.get('distance_3d_ft_in',''))}</td>"
            f"<td>{fmt(float(r.get('tilt_deg',0)),1)}°</td>"
            f"<td>{fmt(float(r.get('x_m',0)),2)}, {fmt(float(r.get('y_m',0)),2)}, {fmt(float(r.get('z_m',0)),2)}</td>"
            f"<td>{esc(r.get('mount_zone',''))}</td></tr>"
        )
    return f"<table>{head}{''.join(trs)}</table>"


def write_report(payload, out_dir: Path) -> Path:
    meta = payload.get("meta", {})
    rows = payload.get("cameras", [])
    if not rows:
        raise SystemExit("No cameras in layout JSON")
    token = meta.get("timestamp", "layout")
    stem = f"splatviz_m67c_layout_report_{token}"
    top = top_svg(rows, meta)
    front = elevation_svg(rows, meta, "front")
    side = elevation_svg(rows, meta, "side")
    (out_dir / f"{stem}_top_view.svg").write_text(top, encoding="utf-8")
    (out_dir / f"{stem}_front_elevation.svg").write_text(front, encoding="utf-8")
    (out_dir / f"{stem}_side_elevation.svg").write_text(side, encoding="utf-8")

    sw, sd = stage_bounds(meta)
    max_radius = max(float(r.get("floor_dist_m", 0)) for r in rows)
    html_text = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>SplatViz M67C Layout Report</title><style>{PAGE_CSS}</style></head>
<body><main class="report">
<section class="sheet">
  <h1>SplatViz M67C Camera Layout Report</h1>
  <div class="meta">Layout: <b>{esc(meta.get('layout_name',''))}</b> · Stage: <b>{fmt(sw,2)} m × {fmt(sd,2)} m</b> ({ft_in(sw)} × {ft_in(sd)}) · Generated: {esc(meta.get('timestamp',''))}</div>
  <div class="kpis">
    <div class="kpi"><b>{len(rows)}</b>Cameras</div>
    <div class="kpi"><b>{fmt(max_radius,2)} m</b>Max ring radius</div>
    <div class="kpi"><b>{esc(meta.get('lens_name','Rokinon 24mm T5.6'))}</b>Lens baseline</div>
    <div class="kpi"><b>1080p / 4K</b>Supported render sizes</div>
  </div>
  <div class="note"><b>Build handoff note:</b> dimensions are to the camera film-plane proxy in SplatViz coordinates. Verify clamp/mount hardware offsets on the physical rig before final build.</div>
  <h2>Floor Plan — Top View</h2>
  <div class="diagram">{top}</div>
  <div class="footer">Azimuth increases clockwise when viewed from above. X/Z are floor-plane axes; Y is height above finished floor.</div>
</section>
<section class="sheet">
  <h2>Section Elevations</h2>
  <div class="grid2"><div class="diagram">{front}</div><div class="diagram">{side}</div></div>
  <h3>Tier key</h3>
  <p class="meta"><b>Low</b> ≈ 0.72 m AFF · <b>Mid</b> ≈ 1.55 m AFF · <b>High</b> ≈ 2.45 m AFF. Sight lines target the subject center/eyeline from SplatViz.</p>
</section>
<section class="sheet">
  <h2>Camera Mounting Schedule</h2>
  {schedule_table(rows)}
</section>
<section class="sheet">
  <h2>Camera Frustum Contact Sheet</h2>
  <p class="meta">Each card shows a simplified frustum thumbnail plus the camera name, lens, FOV, height, distance, azimuth, tilt, XYZ position, and mount zone.</p>
  <div class="cards">{camera_cards(rows)}</div>
</section>
</main></body></html>'''
    html_path = out_dir / f"{stem}.html"
    html_path.write_text(html_text, encoding="utf-8")
    return html_path


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: splatviz_m67c_layout_report.py layout.json output_dir", file=sys.stderr)
        return 2
    json_path = Path(argv[1]).expanduser().resolve()
    out_dir = Path(argv[2]).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    payload = json.loads(json_path.read_text(encoding="utf-8"))
    html_path = write_report(payload, out_dir)
    print(str(html_path))
    return 0

if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
