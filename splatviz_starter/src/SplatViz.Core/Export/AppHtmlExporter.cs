using System.Text.Json;
using SplatViz.Core.Analysis;
using SplatViz.Core.Scene;

namespace SplatViz.Core.Export;

public static class AppHtmlExporter
{
    public static string ToHtml(
        IReadOnlyList<LayoutPlan> plans,
        IReadOnlyDictionary<string, CoverageReport> reports,
        IReadOnlyDictionary<string, MountabilityReport> mountability,
        IReadOnlyDictionary<string, IReadOnlyList<SplatabilityCandidate>> splatability)
    {
        var data = new
        {
            version = "1.5.0-m1.5-gsplat-angle-sufficiency",
            stage = new
            {
                name = "NOZ Stage #1",
                width_ft = 59.0,
                length_ft = 57.0,
                grid_height_ft = 18.0,
                width_m = 17.9832,
                length_m = 17.3736,
                grid_height_m = 5.4864,
                origin = "center stage",
                orientation = "X = 59 ft left/right, Y = 57 ft upstage/downstage",
                source = "NOZ 2024 tech specs; field verify before rigging"
            },
            performer = new
            {
                type = "SplatViz robot/mannequin placeholder",
                height_m = 1.8,
                height_ft = 5.906,
                eye_height_m = 1.6,
                placement = "center stage",
                focus_practice = "locked focus per camera on performer eyes",
                focus_box_half_depth_m = 0.75
            },
            camera_package = new
            {
                body = new
                {
                    name = "RED KOMODO-X proxy",
                    width_mm = 129.37,
                    height_mm = 101.26,
                    depth_mm = 95.26,
                    sensor_width_mm = 27.03,
                    sensor_height_mm = 14.26,
                    focus_origin = "film plane marker"
                },
                main = new
                {
                    count = 36,
                    lens = "Rokinon DSX24-RF 24mm T1.5",
                    default_distance_ft = "12–13 ft",
                    default_distance_m = "3.66–3.96 m"
                },
                facial_detail = new
                {
                    count = 5,
                    lens = "Rokinon DSX50-RF 50mm T1.5",
                    role = "optional face/detail cameras inside the larger body-volume design"
                },
                mount_head = "Superclamp + 3-axis pan/tilt head proxy"
            },
            asset_library = new[]
            {
                new { id = "box_truss_10", name = "10 ft box truss", type = "box_truss", length_ft = 10.0, width_ft = 1.0, default_height_ft = 12.0, min_height_ft = 7.0, max_height_ft = 18.0, mountable_faces = new [] { "front", "bottom", "rear", "top" }, spacing_min_ft = 1.5, note = "Proxy. Replace with measured truss profile later." },
                new { id = "box_truss_20", name = "20 ft box truss", type = "box_truss", length_ft = 20.0, width_ft = 1.0, default_height_ft = 12.0, min_height_ft = 7.0, max_height_ft = 18.0, mountable_faces = new [] { "front", "bottom", "rear", "top" }, spacing_min_ft = 1.5, note = "Proxy long truss span." },
                new { id = "tower_10_proxy", name = "10-tower array proxy", type = "tower_array", length_ft = 39.0, width_ft = 28.0, default_height_ft = 8.5, min_height_ft = 4.0, max_height_ft = 14.0, mountable_faces = new [] { "vertical rails", "crossbars" }, spacing_min_ft = 2.0, note = "Uploaded OBJ is registered in millimeters; M1.5 uses a lightweight proxy for app speed." },
                new { id = "single_stand", name = "single camera stand", type = "stand", length_ft = 2.5, width_ft = 2.5, default_height_ft = 7.0, min_height_ft = 3.0, max_height_ft = 12.0, mountable_faces = new [] { "head" }, spacing_min_ft = 3.0, note = "Rough stand footprint until measured." },
                new { id = "speed_rail_8", name = "8 ft speed rail / crossbar", type = "rail", length_ft = 8.0, width_ft = 0.25, default_height_ft = 6.5, min_height_ft = 3.0, max_height_ft = 12.0, mountable_faces = new [] { "front", "top" }, spacing_min_ft = 1.5, note = "Represents horizontal rails shown in reference photos." }
            },
            rig_assets = new[]
            {
                new { id = "rig_truss_upstage", library_id = "box_truss_20", name = "upstage 20 ft truss", x_ft = 0.0, y_ft = 10.5, z_ft = 12.0, rotation_deg = 0.0, locked_asset = false },
                new { id = "rig_truss_camera", library_id = "box_truss_20", name = "front camera truss", x_ft = 0.0, y_ft = -10.5, z_ft = 8.0, rotation_deg = 0.0, locked_asset = false },
                new { id = "rig_tower_left", library_id = "single_stand", name = "left stand proxy", x_ft = -13.0, y_ft = -4.5, z_ft = 7.0, rotation_deg = 0.0, locked_asset = false },
                new { id = "rig_tower_right", library_id = "single_stand", name = "right stand proxy", x_ft = 13.0, y_ft = -4.5, z_ft = 7.0, rotation_deg = 0.0, locked_asset = false }
            },
            modes = new[] { "Scene Setup", "Camera Layout", "Focus", "Splat Viability", "Rig / Lighting", "Verification" },
            layouts = plans.Select(plan =>
            {
                var key = plan.Tier.ToString();
                var report = reports[key];
                var mount = mountability[key];
                var assessment = splatability[key];
                var best = assessment.OrderByDescending(x => x.SplatabilityScore + x.ProductionFeasibilityScore * 0.25).First();
                return new
                {
                    tier = key,
                    name = plan.Name,
                    is_default = key == "Premium",
                    intent = plan.PlainEnglishIntent,
                    room = new { x = plan.Room.SizeM.X, y = plan.Room.SizeM.Y, z = plan.Room.SizeM.Z },
                    capture_volume = new { x = plan.CaptureVolume.CenterM.X, y = plan.CaptureVolume.CenterM.Y, z = plan.CaptureVolume.CenterM.Z, radius = plan.CaptureVolume.RadiusM, height = plan.CaptureVolume.HeightM },
                    performer = new { height = plan.PerformerEnvelope.HeightM, radius = plan.PerformerEnvelope.RadiusM, eye_height = 1.6 },
                    report = new { score = report.Score, coverage = report.CoveredFraction, max_gap = report.MaxGapDegrees, pxcm = report.AveragePixelsPerCm },
                    mountability = new { state = mount.State, unassigned = mount.UnassignedCameras, issues = mount.Issues.Take(12).Select(i => new { camera = i.CameraId, mount = i.MountId, severity = i.Severity, message = i.Message }) },
                    best_assessment = new { resolution = best.ResolutionName, distance_m = best.CameraDistanceM, verdict = best.Verdict, splat = best.SplatabilityScore, feasibility = best.ProductionFeasibilityScore, critical = best.CriticalSharpnessScore, focus_box = best.FocusBoxConfidenceScore, eye = best.EyePlaneConfidenceScore, rig_light = best.RigLightingInterferenceScore },
                    cameras = plan.Cameras.Select((c, index) => new
                    {
                        id = c.Id,
                        order = index + 1,
                        x = c.PositionM.X,
                        y = c.PositionM.Y,
                        z = c.PositionM.Z,
                        ax = c.AimTargetM.X,
                        ay = c.AimTargetM.Y,
                        az = c.AimTargetM.Z,
                        lens = c.Lens.Name,
                        focal = c.Lens.FocalLengthMm,
                        recording = c.RecordingMode.Name,
                        width_px = c.RecordingMode.WidthPx,
                        height_px = c.RecordingMode.HeightPx,
                        roll = c.PortraitRoll,
                        mount = c.Mount.Type,
                        mount_id = c.Mount.Id,
                        h_fov = System.Math.Round(c.HorizontalFovDegrees, 2),
                        v_fov = System.Math.Round(c.VerticalFovDegrees, 2),
                        pxcm = System.Math.Round(c.ApproxPixelsPerCmAtAim, 2),
                        focus_target = "performer_eyes",
                        focus_distance = System.Math.Round(c.DistanceToAimM, 3)
                    })
                };
            })
        };

        var json = JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = false });
        return Template().Replace("__SPLATVIZ_APP_DATA__", json);
    }

    private static string Template() => """
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SplatViz App M1.5</title>
<style>
:root{--bg:#050c0f;--panel:#081315;--panel2:#0b181b;--line:#1d343a;--line2:#2d5058;--text:#f0faf5;--muted:#a9beb8;--green:#72d19a;--green2:#123825;--gold:#e6b34b;--red:#e76f6f;--blue:#6bbcff;--cyan:#82e8ff;--orange:#ffb55c;--purple:#b985ff}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 70% 20%,#0a2227,#050c0f 62%);color:var(--text);font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;overflow:hidden}button,select,input{font:inherit}.app{display:grid;grid-template-columns:390px 1fr 380px;height:100vh}.side,.inspector{background:rgba(6,17,19,.96);border-right:1px solid var(--line);padding:18px;overflow:auto}.inspector{border-right:0;border-left:1px solid var(--line)}.brand{color:var(--green);font-size:12px;font-weight:900;text-transform:uppercase;letter-spacing:.18em}.title{font-size:29px;line-height:1.05;margin:12px 0 20px}.label,.field label{display:block;color:var(--green);font-size:12px;font-weight:900;letter-spacing:.14em;text-transform:uppercase;margin-bottom:7px}.field{margin:12px 0}select,input[type=range],input[type=number]{width:100%}select,input[type=number]{background:#0a171a;color:var(--text);border:1px solid #294850;border-radius:7px;padding:6px}.tabs,.modes,.viewButtons{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:12px 0}.viewButtons{grid-template-columns:1fr 1fr 1fr}.tabs button,.modes button,.viewButtons button,.assetBtn,.action{background:#0b1a1e;color:var(--text);border:1px solid #294850;border-radius:10px;padding:10px 12px;text-align:left;cursor:pointer}.tabs button.active,.modes button.active,.assetBtn.active,.viewButtons button.active,.action.primary{border-color:#7bd8a1;background:#123825}.section{border:1px solid var(--line);border-radius:14px;background:rgba(9,24,27,.72);padding:14px;margin:12px 0}.section h3{margin:0 0 10px}.small,.muted{color:var(--muted);font-size:13px;line-height:1.4}.viewport{position:relative;overflow:hidden}.canvas{position:absolute;inset:0;width:100%;height:100%;cursor:grab}.canvas.dragging{cursor:grabbing}.stageLabel{position:absolute;top:24px;left:28px;background:rgba(6,17,19,.82);border:1px solid #284850;border-radius:12px;padding:13px 16px;max-width:660px}.stageLabel h2{margin:0 0 6px}.stageLabel p{margin:3px 0;color:#c7d8d3}.hud{position:absolute;left:24px;bottom:24px;background:rgba(6,17,19,.82);border:1px solid #284850;border-radius:12px;padding:10px 14px;color:#c7d8d3}.footerNote{position:absolute;right:24px;bottom:24px;background:rgba(6,17,19,.82);border:1px solid #284850;border-radius:12px;padding:10px 14px;max-width:620px;color:#c7d8d3}.kbd{display:inline-block;border:1px solid #45666e;border-radius:4px;padding:1px 5px;background:#0e1d20;color:#dffdf0}.assetList{display:grid;gap:8px}.assetBtn small{display:block;color:#a7bbb5;margin-top:4px}.row,.rangeRow{display:grid;grid-template-columns:115px 1fr;gap:8px;align-items:center;margin:8px 0}.pill{display:inline-block;border:1px solid #315a64;border-radius:999px;padding:4px 9px;margin:4px 4px 0 0;color:#d8eee7;font-size:12px}.metric{height:9px;background:#153239;border-radius:999px;overflow:hidden}.metric>div{height:100%;background:#79d99f}.metric.warn>div{background:#e6b34b}.warn{color:#e6b34b;margin:6px 0}.danger{color:#e76f6f}.sheet{display:none;position:absolute;inset:0;overflow:auto;padding:42px;background:#071113}.sheet.active{display:block}.sheet h1{font-size:32px;margin:0 0 8px}.cardGrid{display:grid;grid-template-columns:repeat(6,minmax(160px,1fr));gap:12px;margin-top:22px}.stillCard{border:1px solid var(--line2);border-radius:12px;background:#0b181b;overflow:hidden;cursor:pointer}.stillCard.active{border-color:#7bd8a1;box-shadow:0 0 0 1px #7bd8a1}.stillCard.neighbor{border-color:#e6b34b}.thumb{height:116px;position:relative;background:linear-gradient(145deg,#0a2026,#0b171a)}.bodyIcon{position:absolute;top:22px;left:50%;transform:translateX(-50%);width:48px;height:78px;border:1px solid #8fd8aa;background:#355f4a;border-radius:22px}.hline{position:absolute;left:14px;right:14px;top:76%;height:1px;background:#31515a}.stillMeta{padding:10px}.stillMeta b{display:block;margin-bottom:4px}.badges{position:absolute;top:8px;left:8px;display:flex;gap:6px}.badge{font-size:10px;border:1px solid #315a64;border-radius:999px;padding:2px 6px;background:#0b181b;color:#cde4dc}.badge.roll{border-color:#e6b34b;color:#ffd889}.badge.mount{border-color:#72d19a;color:#b9f2cc}.noteBox{border:1px dashed #41616a;border-radius:12px;padding:12px;color:#bfd4ce;background:rgba(12,31,35,.55)}.legendRow{display:flex;gap:8px;align-items:center;margin:5px 0}.sw{width:18px;height:12px;border-radius:3px;border:1px solid rgba(255,255,255,.35)}
</style>
</head>
<body>
<div class="app">
  <aside class="side">
    <div class="brand">SplatViz M1.5 App Scaffold</div>
    <div class="title">gsplat Verification + Angle Sufficiency</div>
    <div class="field"><label>Stage</label><select id="stageSelect"><option>NOZ Stage #1</option></select></div>
    <div class="field"><label>Layout</label><select id="layoutSelect"></select></div>
    <div class="tabs"><button id="tabScene" class="active">3D Scene</button><button id="tabStill">Still Sheet</button></div>
    <div class="modes" id="modeButtons"></div>
    <div class="section">
      <h3>Focus Envelope</h3>
      <div class="small">Blue box = taped performer movement box. Toggle solid to see where the performer can move inside the focus layer.</div>
      <div class="row"><span>Display</span><select id="focusEnvMode"><option value="wire">Wireframe</option><option value="solid">Solid translucent</option><option value="hidden">Hidden</option></select></div>
      <div class="row"><span>Opacity</span><input id="focusEnvOpacity" type="range" min="10" max="85" value="35"></div>
      <div class="row"><span>Width ft</span><input id="envW" type="number" step="0.25" value="5"></div>
      <div class="row"><span>Depth ft</span><input id="envD" type="number" step="0.25" value="5"></div>
      <div class="row"><span>Height ft</span><input id="envH" type="number" step="0.25" value="6"></div>
    </div>
    <div class="section">
      <h3>Rig Asset Library</h3>
      <div class="small">Default scene is auto-rigged with assumed mounts. Drag truss/stands when refining the physical build.</div>
      <div id="assetList" class="assetList" style="margin-top:10px"></div>
      <button class="action primary" id="addAsset" style="width:100%;margin-top:10px">Add selected asset</button>
    </div>
    <div class="section">
      <h3>Selected Asset</h3>
      <div id="assetInspector" class="small">Select or add a rig asset.</div>
      <div id="assetControls" style="display:none">
        <div class="row"><span>x ft</span><input id="assetX" type="number" step="0.25"></div>
        <div class="row"><span>y ft</span><input id="assetY" type="number" step="0.25"></div>
        <div class="row"><span>height ft</span><input id="assetZ" type="number" step="0.25"></div>
        <div class="row"><span>rot deg</span><input id="assetRot" type="number" step="5"></div>
        <button class="action" id="duplicateAsset" style="width:100%;margin-top:8px">Duplicate asset</button>
      </div>
    </div>
    <div class="section">
      <h3>Project</h3>
      <button class="action" id="exportProject" style="width:100%">Export SplatViz project JSON</button>
      <div class="small" style="margin-top:8px">M1.5 exports the auto-rigged scene state and gsplat-aligned verification manifests. Full project reopen comes in the packaged app pass.</div>
    </div>
  </aside>
  <main class="viewport">
    <svg id="svg" class="canvas" viewBox="0 0 1200 800"></svg>
    <section id="stillSheet" class="sheet"><h1>Ordered Still Sheet</h1><p class="muted">Camera-order sheet. Real rendered stills replace placeholders later.</p><div id="stillGrid" class="cardGrid"></div></section>
    <div class="stageLabel"><h2 id="stageTitle"></h2><p id="stageMeta"></p><p id="modeNote"></p></div>
    <div class="hud"><span class="kbd">drag</span> orbit · <span class="kbd">Shift+drag</span> pan · <span class="kbd">wheel</span> dolly · <span class="kbd">← ↑ → ↓</span> pan</div>
    <div class="footerNote" id="footerNote"></div>
  </main>
  <aside class="inspector">
    <div class="brand">Inspector</div>
    <div class="section"><h3 id="selectedTitle">No selection</h3><div id="selectedDetails" class="small">Select a camera or rig asset.</div></div>
    <div class="section"><h3>Splat Viability Assessment</h3><div id="assessment"></div></div>
    <div class="section"><h3>Angle Sufficiency</h3><div id="angleSufficiency" class="small"></div></div>
    <div class="section"><h3>Diagnostic Legend</h3><div id="legend" class="small"></div></div>
    <div class="section"><h3>Mount Confidence</h3><div id="mountWarnings" class="small"></div></div>
    <div class="section"><h3>Viewport Controls</h3><div class="viewButtons"><button id="viewPersp">Perspective</button><button id="viewTop">Top</button><button id="viewFront">Front</button><button id="viewEye">Eye Line</button><button id="viewTruss">Truss</button><button id="viewReset">Reset</button></div><div class="rangeRow"><span>zoom</span><span id="zoomVal"></span></div><input id="zoomRange" type="range" min="30" max="150" value="86"><div class="rangeRow"><span>pitch</span><span id="pitchVal"></span></div><input id="pitchRange" type="range" min="0" max="55" value="28"><div class="rangeRow"><span>yaw</span><span id="yawVal"></span></div><input id="yawRange" type="range" min="-180" max="180" value="-28"><div class="small" style="margin-top:10px">M1.5 still uses SVG for speed. The .app pass can swap this to WebGL/Three.js.</div></div>
  </aside>
</div>
<script>
const DATA = __SPLATVIZ_APP_DATA__;
const FT_TO_M = 0.3048, M_TO_FT = 3.280839895;
let layout = DATA.layouts.find(l=>l.tier==='Premium') || DATA.layouts[0];
let selectedCamera = layout.cameras[0];
let selectedAssetId = null, activeTab = 'scene', mode = 'Focus';
let zoom = 86, pitch = 28, yaw = -28, pan = {x:0,y:0};
let drag = null, selectedLib = DATA.asset_library[0].id;
let rigAssets = DATA.rig_assets.map((a,i)=>({...a, uid:a.id || ('asset_'+i)}));
const svg = document.getElementById('svg'), stillSheet = document.getElementById('stillSheet');
function byId(id){return document.getElementById(id)}
function ft(v){return Number(v).toFixed(Math.abs(v%1)>0.01?1:0)+' ft'}
function mft(v){return (v*FT_TO_M).toFixed(2)+' m'}
function rad(d){return d*Math.PI/180} function deg(r){return r*180/Math.PI}
function lib(id){return DATA.asset_library.find(a=>a.id===id) || DATA.asset_library[0]}
function activeAsset(){return rigAssets.find(a=>a.uid===selectedAssetId)}
function modeNotes(){return {
 'Scene Setup':'Auto-rigged default scene: add and position physical truss/stands before final camera layout.',
 'Camera Layout':'Camera bodies are KOMODO-X proxies. Rectangular frustums originate at the film-plane marker.',
 'Focus':'Focus view shows orange/yellow/green frustum zones plus the blue performer focus envelope.',
 'Splat Viability':'Contribution overlay colors the performer-side coverage; cross-hatching marks weak/dead contribution zones.',
 'Rig / Lighting':'Rig / Lighting mode shows assumed mount confidence and close-camera interference risk.',
 'Verification':'Verification mode prepares gsplat-aligned train/holdout manifests. Msplat is optional smoke test only; gsplat is the conclusion path.'
}}
function init(){
  const layoutSelect=byId('layoutSelect'); layoutSelect.innerHTML=DATA.layouts.map((l,i)=>`<option value="${i}" ${l===layout?'selected':''}>${l.name}</option>`).join('');
  layoutSelect.onchange=()=>{layout=DATA.layouts[+layoutSelect.value]; selectedCamera=layout.cameras[0]; renderAll()};
  const modeButtons=byId('modeButtons'); modeButtons.innerHTML=DATA.modes.map(x=>`<button data-mode="${x}" class="${x===mode?'active':''}">${x}</button>`).join('');
  modeButtons.querySelectorAll('button').forEach(b=>b.onclick=()=>{mode=b.dataset.mode; activeTab='scene'; renderAll()});
  byId('assetList').innerHTML=DATA.asset_library.map(a=>`<button class="assetBtn ${a.id===selectedLib?'active':''}" data-id="${a.id}">${a.name}<small>${a.type} · ${a.length_ft}×${a.width_ft} ft · ${a.min_height_ft}–${a.max_height_ft} ft</small></button>`).join('');
  byId('assetList').querySelectorAll('button').forEach(b=>b.onclick=()=>{selectedLib=b.dataset.id; renderAssetLibrary()});
  byId('addAsset').onclick=addRigAsset; byId('duplicateAsset').onclick=duplicateAsset; byId('exportProject').onclick=exportProject;
  ['assetX','assetY','assetZ','assetRot'].forEach(id=>byId(id).addEventListener('input',updateAssetFromInputs));
  ['focusEnvMode','focusEnvOpacity','envW','envD','envH'].forEach(id=>byId(id).addEventListener('input',renderAll));
  byId('tabScene').onclick=()=>{activeTab='scene';renderAll()}; byId('tabStill').onclick=()=>{activeTab='still';renderAll()};
  byId('zoomRange').oninput=e=>{zoom=+e.target.value;renderAll()}; byId('pitchRange').oninput=e=>{pitch=+e.target.value;renderAll()}; byId('yawRange').oninput=e=>{yaw=+e.target.value;renderAll()};
  byId('viewPersp').onclick=()=>setView('persp'); byId('viewTop').onclick=()=>setView('top'); byId('viewFront').onclick=()=>setView('front'); byId('viewEye').onclick=()=>setView('eye'); byId('viewTruss').onclick=()=>setView('truss'); byId('viewReset').onclick=()=>setView('reset');
  svg.addEventListener('mousedown',onDown); window.addEventListener('mousemove',onMove); window.addEventListener('mouseup',onUp);
  svg.addEventListener('wheel',e=>{e.preventDefault(); zoom=Math.max(30,Math.min(150,zoom-(e.deltaY*.045))); byId('zoomRange').value=zoom; renderAll()},{passive:false});
  window.addEventListener('keydown',e=>{const step=22; if(e.key==='ArrowLeft')pan.x+=step; if(e.key==='ArrowRight')pan.x-=step; if(e.key==='ArrowUp')pan.y+=step; if(e.key==='ArrowDown')pan.y-=step; renderAll()});
  renderAll();
}
function setView(kind){ if(kind==='top'){yaw=0;pitch=0;zoom=88;pan={x:0,y:0}} if(kind==='front'){yaw=0;pitch=45;zoom=78;pan={x:0,y:80}} if(kind==='eye'){yaw=-28;pitch=20;zoom=104;pan={x:0,y:10}} if(kind==='truss'){yaw=-35;pitch=42;zoom=70;pan={x:0,y:105}} if(kind==='persp'||kind==='reset'){yaw=-28;pitch=28;zoom=86;pan={x:0,y:0}} byId('zoomRange').value=zoom;byId('pitchRange').value=pitch;byId('yawRange').value=yaw;renderAll()}
function renderAssetLibrary(){byId('assetList').querySelectorAll('button').forEach(b=>b.classList.toggle('active',b.dataset.id===selectedLib))}
function addRigAsset(){const a=lib(selectedLib), n=rigAssets.filter(x=>x.library_id===a.id).length+1; const newA={uid:'asset_'+Date.now(),id:'asset_'+Date.now(),library_id:a.id,name:a.name+' '+n,x_ft:0,y_ft:0,z_ft:a.default_height_ft,rotation_deg:0,locked_asset:false}; rigAssets.push(newA); selectedAssetId=newA.uid; selectedCamera=null; renderAll()}
function duplicateAsset(){const a=activeAsset(); if(!a)return; const b={...a,uid:'asset_'+Date.now(),id:'asset_'+Date.now(),name:a.name+' copy',x_ft:a.x_ft+2,y_ft:a.y_ft+2}; rigAssets.push(b); selectedAssetId=b.uid; renderAll()}
function updateAssetFromInputs(){const a=activeAsset(); if(!a)return; a.x_ft=+byId('assetX').value; a.y_ft=+byId('assetY').value; a.z_ft=+byId('assetZ').value; a.rotation_deg=+byId('assetRot').value; renderScene(); updateInspector()}
function exportProject(){const payload={splatviz_version:DATA.version,stage:DATA.stage,performer:DATA.performer,camera_package:DATA.camera_package,rig_assets:rigAssets,layout:layout.name,selected_camera:selectedCamera?.id,focus_envelope:{mode:byId('focusEnvMode').value,opacity:+byId('focusEnvOpacity').value,width_ft:+byId('envW').value,depth_ft:+byId('envD').value,height_ft:+byId('envH').value},view:{zoom,pitch,yaw,pan}}; const blob=new Blob([JSON.stringify(payload,null,2)],{type:'application/json'}); const url=URL.createObjectURL(blob); const a=document.createElement('a'); a.href=url; a.download='splatviz_project_m15.json'; a.click(); setTimeout(()=>URL.revokeObjectURL(url),1000)}
function project(x,y,z=0){const ya=rad(yaw), ca=Math.cos(ya), sa=Math.sin(ya); const xr=x*ca-y*sa, yr=x*sa+y*ca; const s=zoom*1.12, cx=600+pan.x, cy=420+pan.y; return {x:cx+xr*s,y:cy+yr*s*.72-z*s*(pitch/55)}}
function ftProject(xft,yft,zft=0){return project(xft*FT_TO_M,yft*FT_TO_M,zft*FT_TO_M)}
function node(tag,attrs={}){const el=document.createElementNS('http://www.w3.org/2000/svg',tag); for(const[k,v]of Object.entries(attrs))el.setAttribute(k,v); svg.appendChild(el); return el}
function svgEl(tag,attrs={}){const el=document.createElementNS('http://www.w3.org/2000/svg',tag); for(const[k,v]of Object.entries(attrs))el.setAttribute(k,v); return el}
function addText(p,text,color='#c7d8d3',size=12){const t=node('text',{x:p.x,y:p.y,fill:color,'font-size':size}); t.textContent=text; return t}
function forward(c){const dx=c.ax-c.x,dy=c.ay-c.y,len=Math.hypot(dx,dy)||1; return {x:dx/len,y:dy/len}}
function rightOf(f){return{x:-f.y,y:f.x}}
function sensorAspect(c){return c.roll ? c.height_px/c.width_px : c.width_px/c.height_px}
function hFovRad(c){return rad(c.h_fov||33.09)}
function vFovRad(c){return rad(c.v_fov||18.9)}
function filmPoint(c){const f=forward(c); return {x:c.x+f.x*0.055,y:c.y+f.y*0.055,z:c.z}}
function pointAt(c,d){const fp=filmPoint(c), f=forward(c), aimLen=Math.hypot(c.ax-c.x,c.ay-c.y)||1; const slope=(c.az-c.z)/aimLen; return {x:fp.x+f.x*d,y:fp.y+f.y*d,z:fp.z+slope*d}}
function gateCorners(c,d){const center=pointAt(c,d), f=forward(c), r=rightOf(f); const hw=Math.tan(hFovRad(c)/2)*d, hh=Math.tan(vFovRad(c)/2)*d; return {tl:project(center.x+r.x*hw,center.y+r.y*hw,center.z+hh),tr:project(center.x-r.x*hw,center.y-r.y*hw,center.z+hh),br:project(center.x-r.x*hw,center.y-r.y*hw,center.z-hh),bl:project(center.x+r.x*hw,center.y+r.y*hw,center.z-hh)}}
function poly(points,attrs){return node('polygon',{points:points.map(p=>`${p.x},${p.y}`).join(' '),...attrs})}
function frustumSegment(c,d1,d2,fill,stroke,op=.9){const a=gateCorners(c,d1), b=gateCorners(c,d2); [[a.tl,a.tr,b.tr,b.tl],[a.tr,a.br,b.br,b.tr],[a.br,a.bl,b.bl,b.br],[a.bl,a.tl,b.tl,b.bl]].forEach(pts=>poly(pts,{fill,stroke,'stroke-width':1,'stroke-opacity':op})); poly([b.tl,b.tr,b.br,b.bl],{fill:'none',stroke,'stroke-width':1.5,'stroke-opacity':op});}
function drawStage(){const w=DATA.stage.width_ft,h=DATA.stage.length_ft; const pts=[[-w/2,-h/2,0],[w/2,-h/2,0],[w/2,h/2,0],[-w/2,h/2,0]].map(p=>ftProject(...p)); poly(pts,{fill:'rgba(9,32,36,.42)',stroke:'#284b54','stroke-width':1.3}); const topA=ftProject(-w/2,h/2,DATA.stage.grid_height_ft),topB=ftProject(w/2,h/2,DATA.stage.grid_height_ft); node('line',{x1:topA.x,y1:topA.y,x2:topB.x,y2:topB.y,stroke:'#35646d','stroke-width':1,'stroke-dasharray':'8 8'}); addText(ftProject(-w/2+1,h/2-1,0),`${w} ft / ${DATA.stage.width_m.toFixed(2)} m`); addText(ftProject(w/2-13,-h/2+1,0),`${h} ft / ${DATA.stage.length_m.toFixed(2)} m`)}
function drawGrid(){for(let x=-25;x<=25;x+=5){const a=ftProject(x,-28,0),b=ftProject(x,28,0);node('line',{x1:a.x,y1:a.y,x2:b.x,y2:b.y,stroke:'#183139','stroke-width':.7})} for(let y=-25;y<=25;y+=5){const a=ftProject(-29,y,0),b=ftProject(29,y,0);node('line',{x1:a.x,y1:a.y,x2:b.x,y2:b.y,stroke:'#183139','stroke-width':.7})}}
function drawRigAssets(){rigAssets.forEach(a=>{const l=lib(a.library_id), p=ftProject(a.x_ft,a.y_ft,a.z_ft), g=svgEl('g',{'data-asset':a.uid}); g.style.cursor='move'; svg.appendChild(g); const selected=a.uid===selectedAssetId; if(l.type==='stand'){const base=ftProject(a.x_ft,a.y_ft,0),top=ftProject(a.x_ft,a.y_ft,a.z_ft); g.appendChild(svgEl('circle',{cx:base.x,cy:base.y,r:selected?12:9,fill:'rgba(230,179,75,.06)',stroke:selected?'#72d19a':'#e6b34b','stroke-width':selected?3:2})); g.appendChild(svgEl('line',{x1:base.x,y1:base.y,x2:top.x,y2:top.y,stroke:selected?'#72d19a':'#e6b34b','stroke-width':4}));} else {const len=l.length_ft*FT_TO_M*zoom*1.12,wid=Math.max(5,l.width_ft*FT_TO_M*zoom*.82); const rect=svgEl('rect',{x:p.x-len/2,y:p.y-wid/2,width:len,height:wid,rx:3,fill:l.type==='tower_array'?'rgba(114,209,154,.10)':'rgba(230,179,75,.12)',stroke:selected?'#72d19a':'#e6b34b','stroke-width':selected?3:2,transform:`rotate(${a.rotation_deg+yaw*.15} ${p.x} ${p.y})`}); g.appendChild(rect); for(let i=1;i<4;i++){const lx=p.x-len/2+len*i/4; g.appendChild(svgEl('line',{x1:lx,y1:p.y-wid/2,x2:lx,y2:p.y+wid/2,stroke:'#e6b34b','stroke-opacity':.45,transform:`rotate(${a.rotation_deg+yaw*.15} ${p.x} ${p.y})`}))}} const label=svgEl('text',{x:p.x+8,y:p.y-8,fill:'#e6d28f','font-size':11}); label.textContent=`${a.name} · ${ft(a.z_ft)} / ${mft(a.z_ft)}`; g.appendChild(label); g.addEventListener('mousedown',e=>{selectedAssetId=a.uid; selectedCamera=null; e.stopPropagation(); renderAll()})})}
function drawPerformer(){const c=project(0,0,0), eye=project(0,0,DATA.performer.eye_height_m), h=DATA.performer.height_m*zoom*(pitch/55), r=DATA.performer.height_m*.18*zoom; if(mode==='Splat Viability')drawContributionOverlay(); node('ellipse',{cx:c.x,cy:c.y,rx:r,ry:r*.55,fill:'rgba(114,209,154,.18)',stroke:'#72d19a','stroke-width':1.4,'stroke-dasharray':'6 5'}); node('line',{x1:eye.x,y1:eye.y,x2:project(0,0,0).x,y2:project(0,0,0).y,stroke:'#b9f2cc','stroke-width':4}); node('circle',{cx:eye.x,cy:eye.y,r:7,fill:'#82e8ff',stroke:'#dffdf0','stroke-width':2}); addText({x:eye.x+10,y:eye.y-6},'eyes / focus target','#dffdf0',11); drawFocusEnvelope();}
function cubeCorners(wft,dft,hft){const w=wft*FT_TO_M/2,d=dft*FT_TO_M/2,h=hft*FT_TO_M; return [[-w,-d,0],[w,-d,0],[w,d,0],[-w,d,0],[-w,-d,h],[w,-d,h],[w,d,h],[-w,d,h]].map(p=>project(p[0],p[1],p[2]))}
function drawFocusEnvelope(){const display=byId('focusEnvMode').value; if(display==='hidden')return; const op=(+byId('focusEnvOpacity').value)/100; const pts=cubeCorners(+byId('envW').value,+byId('envD').value,+byId('envH').value); const faces=[[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]; if(display==='solid')faces.forEach(face=>poly(face.map(i=>pts[i]),{fill:`rgba(107,188,255,${op})`,stroke:'rgba(130,232,255,.9)','stroke-width':1.2})); const edges=[[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]; edges.forEach(e=>node('line',{x1:pts[e[0]].x,y1:pts[e[0]].y,x2:pts[e[1]].x,y2:pts[e[1]].y,stroke:'#6bbcff','stroke-width':display==='solid'?1.4:2.2,'stroke-opacity':display==='solid'?.95:1}));}
function drawContributionOverlay(){const sel=selectedCamera||layout.cameras[0]; const ids=layout.cameras.map(c=>c.id); const idx=ids.indexOf(sel.id); const prev=layout.cameras[(idx-1+ids.length)%ids.length], next=layout.cameras[(idx+1)%ids.length]; drawAggregateCoverage(); drawContributionPatch(sel,'rgba(255,79,216,.42)','#ff4fd8',1.0); drawContributionPatch(prev,'rgba(0,215,255,.24)','#00d7ff',.72); drawContributionPatch(next,'rgba(255,176,0,.24)','#ffb000',.72); drawWeakZones(); drawRedundantHints();}

function drawAggregateCoverage(){const rings=angleGaps(); const target=rad(15.5); rings.forEach(g=>{const fill=g.gap>target?'rgba(255,255,255,.018)':'rgba(0,230,118,.045)'; const mid=g.mid%(Math.PI*2), span=Math.min(g.gap*.84,rad(18)); const r1=layout.capture_volume.radius*.18,r2=layout.capture_volume.radius*.82; const pts=[]; for(let i=-3;i<=3;i++){const a=mid+i*span/6; pts.push(project(Math.cos(a)*r2,Math.sin(a)*r2,DATA.performer.eye_height_m*.58))} for(let i=3;i>=-3;i--){const a=mid+i*span/6; pts.push(project(Math.cos(a)*r1,Math.sin(a)*r1,DATA.performer.eye_height_m*.2))} poly(pts,{fill,stroke:'rgba(0,230,118,.18)','stroke-width':.5})})}
function angleGaps(){const angles=layout.cameras.map(c=>(Math.atan2(c.y,c.x)+Math.PI*2)%(Math.PI*2)).sort((a,b)=>a-b); const gaps=[]; for(let i=0;i<angles.length;i++){let a=angles[i], b=angles[(i+1)%angles.length]+(i===angles.length-1?Math.PI*2:0); gaps.push({mid:(a+b)/2,gap:b-a})} return gaps}

function drawContributionPatch(c,fill,stroke,scale){const ang=Math.atan2(c.y,c.x); const r1=layout.capture_volume.radius*0.22, r2=layout.capture_volume.radius*0.97, span=rad(20*scale); const pts=[]; for(let i=-4;i<=4;i++){const a=ang+i*span/4; pts.push(project(Math.cos(a)*r2,Math.sin(a)*r2,DATA.performer.eye_height_m*.55));} for(let i=4;i>=-4;i--){const a=ang+i*span/4; pts.push(project(Math.cos(a)*r1,Math.sin(a)*r1,DATA.performer.eye_height_m*.18));} poly(pts,{fill,stroke,'stroke-width':1.5,'stroke-opacity':.9});}
function drawWeakZones(){const weak=angleGaps().filter(g=>g.gap>rad(17)).sort((a,b)=>b.gap-a.gap).slice(0,10); weak.forEach(g=>{const mid=g.mid%(Math.PI*2), span=Math.min(g.gap*.82,rad(25)); const r1=layout.capture_volume.radius*.2,r2=layout.capture_volume.radius*1.05; const pts=[]; for(let i=-4;i<=4;i++){const a=mid+i*span/8; pts.push(project(Math.cos(a)*r2,Math.sin(a)*r2,DATA.performer.eye_height_m*.75))} for(let i=4;i>=-4;i--){const a=mid+i*span/8; pts.push(project(Math.cos(a)*r1,Math.sin(a)*r1,DATA.performer.eye_height_m*.25))} poly(pts,{fill:'url(#deadHatch)',stroke:'#ffffff','stroke-width':1.1,'stroke-dasharray':'4 4','stroke-opacity':.86}); const lp=project(Math.cos(mid)*r2*1.08,Math.sin(mid)*r2*1.08,DATA.performer.eye_height_m*.8); addText(lp,`add view ${(deg(g.gap)).toFixed(0)}° gap`,'#ffffff',10)})}
function drawRedundantHints(){const cams=layout.cameras; if(cams.length<30)return; const step=2*Math.PI/cams.length; cams.forEach((c,i)=>{const prev=cams[(i-1+cams.length)%cams.length], next=cams[(i+1)%cams.length]; const da=Math.abs(Math.atan2(Math.sin(Math.atan2(c.y,c.x)-Math.atan2(prev.y,prev.x)),Math.cos(Math.atan2(c.y,c.x)-Math.atan2(prev.y,prev.x)))); if(da<rad(9)){drawContributionPatch(c,'url(#redundantHatch)','#ff8a00',.42)}})}
function drawCameras(){if(mode==='Focus'&&selectedCamera){drawFocusFrustum(selectedCamera)} else if(mode==='Splat Viability'&&selectedCamera){drawBasicFrustum(selectedCamera,true)} layout.cameras.forEach(c=>{if(!(mode==='Focus'&&selectedCamera&&c.id===selectedCamera.id)&&!(mode==='Splat Viability'&&selectedCamera&&c.id===selectedCamera.id)) drawBasicFrustum(c,false); if(mode==='Rig / Lighting')drawMountConnector(c)}); layout.cameras.forEach(drawCameraProxy)}
function drawBasicFrustum(c,strong){const d=Math.min(c.focus_distance,5.8); frustumSegment(c,.15,d,strong?'rgba(255,79,216,.08)':'rgba(114,209,154,.012)',strong?'#ff4fd8':'rgba(114,209,154,.18)',strong?1:.22)}
function drawFocusFrustum(c){const focus=c.focus_distance; const near=focus*.589, far=focus*3.35; const critNear=Math.max(.3,focus-0.75), critFar=focus+0.75; const visualFar=Math.min(far,focus*2.25); frustumSegment(c,.18,Math.min(near,critNear-.05),'rgba(255,181,92,.18)','#ffb55c',.9); frustumSegment(c,near,critNear,'rgba(242,209,92,.17)','#e6b34b',.9); frustumSegment(c,critNear,critFar,'rgba(114,209,154,.24)','#72d19a',1); frustumSegment(c,critFar,visualFar,'rgba(242,209,92,.14)','#e6b34b',.82); const focusGate=gateCorners(c,focus); poly([focusGate.tl,focusGate.tr,focusGate.br,focusGate.bl],{fill:'rgba(130,232,255,.10)',stroke:'#82e8ff','stroke-width':2.4}); const center=pointAt(c,focus), cp=project(center.x,center.y,center.z); node('circle',{cx:cp.x,cy:cp.y,r:5,fill:'#82e8ff'}); addText({x:cp.x+8,y:cp.y-8},`focus plane ${focus.toFixed(2)}m / ${(focus*M_TO_FT).toFixed(1)}ft`,'#dffdf0',11); addFocusBoundaryLabel(c,near,'near DOF'); addFocusBoundaryLabel(c,visualFar,far>visualFar?'far DOF continues':'far DOF');}
function addFocusBoundaryLabel(c,d,label){const center=pointAt(c,d), p=project(center.x,center.y,center.z); addText({x:p.x+6,y:p.y+6},`${label}: ${d.toFixed(2)}m / ${(d*M_TO_FT).toFixed(1)}ft`,'#ffd889',10)}
function assumedMountForCamera(c){if(c.y>2.0)return{name:'upstage truss',confidence:'high',score:92}; if(c.y<-2.0)return{name:'front truss / speed rail',confidence:'high',score:90}; if(c.x<-2.3)return{name:'left tower/stand zone',confidence:'medium',score:74}; if(c.x>2.3)return{name:'right tower/stand zone',confidence:'medium',score:74}; return{name:'inner stand proxy',confidence:'low',score:55}}
function drawMountConnector(c){const m=assumedMountForCamera(c), cp=project(c.x,c.y,c.z); let asset=rigAssets[0]; if(m.name.includes('front'))asset=rigAssets.find(a=>a.name.includes('front'))||asset; else if(m.name.includes('upstage'))asset=rigAssets.find(a=>a.name.includes('upstage'))||asset; else if(m.name.includes('left'))asset=rigAssets.find(a=>a.name.includes('left'))||asset; else if(m.name.includes('right'))asset=rigAssets.find(a=>a.name.includes('right'))||asset; const ap=ftProject(asset.x_ft,asset.y_ft,asset.z_ft); node('line',{x1:cp.x,y1:cp.y,x2:ap.x,y2:ap.y,stroke:m.confidence==='high'?'#72d19a':m.confidence==='medium'?'#e6b34b':'#e76f6f','stroke-width':1.2,'stroke-opacity':.5,'stroke-dasharray':m.confidence==='high'?'':'5 5'})}
function drawCameraProxy(c){const p=project(c.x,c.y,c.z), ang=deg(Math.atan2(c.ay-c.y,c.ax-c.x))+yaw*.08, active=selectedCamera&&selectedCamera.id===c.id, m=assumedMountForCamera(c); const g=svgEl('g',{'data-camera':c.id}); g.style.cursor='pointer'; svg.appendChild(g); g.appendChild(svgEl('rect',{x:p.x-13,y:p.y-9,width:26,height:18,rx:3,fill:active?'#72d19a':m.confidence==='low'?'#e6b34b':'#dfe8e4',stroke:active?'#dffdf0':'#082226','stroke-width':active?3:1,transform:`rotate(${ang} ${p.x} ${p.y})`})); g.appendChild(svgEl('rect',{x:p.x+9,y:p.y-4,width:16,height:8,rx:3,fill:'#101719',stroke:'#6bbcff',transform:`rotate(${ang} ${p.x} ${p.y})`})); g.appendChild(svgEl('line',{x1:p.x-7,y1:p.y-10,x2:p.x-7,y2:p.y+10,stroke:'#ffdf8a','stroke-width':2,transform:`rotate(${ang} ${p.x} ${p.y})`})); const label=svgEl('text',{x:p.x+15,y:p.y-11,fill:'#edf7f2','font-size':12,'font-weight':700}); label.textContent=c.id; g.appendChild(label); g.addEventListener('mousedown',e=>{selectedCamera=c;selectedAssetId=null;e.stopPropagation();renderAll()})}
function renderAll(){byId('tabScene').classList.toggle('active',activeTab==='scene'); byId('tabStill').classList.toggle('active',activeTab==='still'); byId('modeButtons').querySelectorAll('button').forEach(b=>b.classList.toggle('active',b.dataset.mode===mode)); stillSheet.classList.toggle('active',activeTab==='still'); svg.style.display=activeTab==='scene'?'block':'none'; byId('stageTitle').textContent=DATA.stage.name; byId('stageMeta').textContent=`${DATA.stage.width_ft} ft × ${DATA.stage.length_ft} ft · ${DATA.stage.width_m.toFixed(2)} m × ${DATA.stage.length_m.toFixed(2)} m · grid ${DATA.stage.grid_height_ft} ft / ${DATA.stage.grid_height_m.toFixed(2)} m`; byId('modeNote').textContent=modeNotes()[mode]||''; byId('zoomVal').textContent=Math.round(zoom); byId('pitchVal').textContent=pitch+'°'; byId('yawVal').textContent=yaw+'°'; renderScene(); renderStillSheet(); updateInspector()}
function renderScene(){if(activeTab!=='scene')return; svg.innerHTML=''; const defs=svgEl('defs'); defs.innerHTML='<pattern id="deadHatch" width="10" height="10" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="10" height="10" fill="rgba(0,0,0,.18)"/><line x1="0" y1="0" x2="0" y2="10" stroke="#fff" stroke-width="2" stroke-opacity="0.72"/></pattern><pattern id="redundantHatch" width="8" height="8" patternUnits="userSpaceOnUse"><circle cx="2" cy="2" r="1.3" fill="#ff8a00" opacity=".58"/><circle cx="6" cy="6" r="1.3" fill="#ff8a00" opacity=".58"/></pattern>'; svg.appendChild(defs); drawStage(); drawGrid(); drawRigAssets(); drawCameras(); drawPerformer()}
function renderStillSheet(){const grid=byId('stillGrid'), ids=layout.cameras.map(c=>c.id), idx=selectedCamera?ids.indexOf(selectedCamera.id):-1; grid.innerHTML=layout.cameras.map((c,i)=>{const neigh=Math.abs(i-idx)===1||(idx===0&&i===ids.length-1)||(idx===ids.length-1&&i===0), m=assumedMountForCamera(c); return `<div class="stillCard ${selectedCamera&&selectedCamera.id===c.id?'active':''} ${neigh?'neighbor':''}" data-id="${c.id}"><div class="thumb"><div class="badges"><span class="badge mount">${m.confidence}</span>${c.roll?'<span class="badge roll">roll</span>':''}</div><div class="bodyIcon"></div><div class="hline"></div></div><div class="stillMeta"><b>${c.id}</b><div>${Math.round(Math.atan2(c.y,c.x)*180/Math.PI+360)%360}° physical azimuth · ${c.roll?'portrait roll':'landscape'}</div><div>${c.focus_distance}m film-plane-to-eye · ${c.pxcm} px/cm</div><div class="muted">${m.name}</div></div></div>`}).join(''); grid.querySelectorAll('.stillCard').forEach(card=>card.onclick=()=>{selectedCamera=layout.cameras.find(c=>c.id===card.dataset.id); selectedAssetId=null; activeTab='scene'; renderAll()})}

function angleSufficiency(){const count=layout.cameras.length, gap=layout.report.max_gap||360/count; const targetGap=15, minUseful=24; let state='strong'; let msg='Meets current full-body performer angle-density hypothesis; gsplat validation still required.'; if(count<20||gap>17){state='weak'; msg='Coverage may look complete, but useful angular density is below the current full-body performer hypothesis.'} else if(count<30||gap>targetGap){state='baseline'; msg='Viable baseline hypothesis. Use gsplat holdout solve to confirm face/hands/wardrobe regions.'} return {state,msg,count,gap,targetGap,minUseful}}

function updateInspector(){if(selectedAssetId){const a=activeAsset(), l=lib(a.library_id); byId('selectedTitle').textContent=a.name; byId('selectedDetails').innerHTML=`<span class="pill">${l.type}</span><span class="pill">${ft(a.z_ft)} / ${mft(a.z_ft)} high</span><span class="pill">${ft(a.x_ft)}, ${ft(a.y_ft)}</span><p>${l.note}</p><p>Mountable: ${Array.isArray(l.mountable_faces)?l.mountable_faces.join(', '):l.mountable_faces}</p>`; byId('assetControls').style.display='block'; byId('assetInspector').textContent='Editing rig asset.'; byId('assetX').value=a.x_ft; byId('assetY').value=a.y_ft; byId('assetZ').value=a.z_ft; byId('assetRot').value=a.rotation_deg} else {byId('assetControls').style.display='none'; byId('assetInspector').textContent='Select or add a rig asset.'; if(selectedCamera){const c=selectedCamera,m=assumedMountForCamera(c); byId('selectedTitle').textContent=c.id; byId('selectedDetails').innerHTML=`<b>${c.lens}</b><br>${c.recording}<br>${c.roll?'portrait roll':'landscape'} · ${m.name}<br><span class="pill">mount confidence: ${m.confidence}</span><span class="pill">film-plane origin</span><span class="pill">${c.focus_distance}m focus distance</span><span class="pill">${c.pxcm} px/cm</span><span class="pill">${c.h_fov}° hFOV</span>`}}
  const a=layout.best_assessment; byId('assessment').innerHTML=`<div>${a.resolution} at ${a.distance_m}m · ${a.verdict}</div><p>Splat viability ${a.splat.toFixed(1)}</p><div class="metric"><div style="width:${a.splat}%"></div></div><p>Critical sharpness ${a.critical.toFixed(1)}</p><div class="metric"><div style="width:${a.critical}%"></div></div><p>Rig / lighting ${a.rig_light.toFixed(1)}</p><div class="metric ${a.rig_light<70?'warn':''}"><div style="width:${a.rig_light}%"></div></div>`;
  const suff=angleSufficiency(); byId('angleSufficiency').innerHTML=`<b class="${suff.state==='weak'?'warnText':''}">${suff.state.toUpperCase()} for full-body performer hypothesis</b><p>${suff.count} cameras · max gap ${suff.gap.toFixed(1)}°. Target gap ≤ ${suff.targetGap}° and ≥ ${suff.minUseful} useful views before calling a layout production-safe.</p><p>${suff.msg}</p><p><b>Conclusion status:</b> prediction only — gsplat validation required.</p>`;
  const legendByMode={Focus:`<div class="legendRow"><span class="sw" style="background:rgba(255,181,92,.55)"></span>too near / poor focus confidence</div><div class="legendRow"><span class="sw" style="background:rgba(242,209,92,.55)"></span>acceptable but not ideal</div><div class="legendRow"><span class="sw" style="background:rgba(114,209,154,.65)"></span>critical sharpness zone</div><div class="legendRow"><span class="sw" style="background:rgba(107,188,255,.45)"></span>performer focus envelope / taped box</div>`, 'Splat Viability':`<div class="legendRow"><span class="sw" style="background:rgba(255,79,216,.70)"></span>selected camera contribution</div><div class="legendRow"><span class="sw" style="background:rgba(0,215,255,.55)"></span>previous neighbor contribution</div><div class="legendRow"><span class="sw" style="background:rgba(255,176,0,.55)"></span>next neighbor contribution</div><div class="legendRow"><span class="sw" style="background:repeating-linear-gradient(45deg,#fff,#fff 2px,#000 2px,#000 7px)"></span>weak/dead contribution zone</div><div class="legendRow"><span class="sw" style="background:radial-gradient(circle,#ff8a00 20%,transparent 22%)"></span>redundant same-neighborhood overlap</div>`, 'Camera Layout':`Rectangular frustums originate at the film plane. Camera bodies are physical proxies, not points.`, 'Rig / Lighting':`Green/amber/red mount lines indicate assumed mount confidence.`, 'Scene Setup':`Drag truss/stand proxies. Cameras should later attach to declared mount points.`, 'Verification':`Synthetic stills and msplat smoke-test / gsplat runs validate this prediction layer.`}; byId('legend').innerHTML=legendByMode[mode]||legendByMode['Camera Layout'];
  const mounts=layout.cameras.map(assumedMountForCamera), high=mounts.filter(x=>x.confidence==='high').length, med=mounts.filter(x=>x.confidence==='medium').length, low=mounts.filter(x=>x.confidence==='low').length; byId('mountWarnings').innerHTML=`<b>Auto-rigged assumed mounts</b><p>${high} high confidence · ${med} medium · ${low} low. M1.5 treats these as planning assumptions, not final rigging.</p><p>Next app pass should attach cameras directly to declared truss/stand snap points.</p>`;
  byId('footerNote').textContent=mode==='Focus'?'True focus frustum: orange/yellow/green zones project from the film plane. Blue envelope toggles between wireframe and solid movement volume.':mode==='Splat Viability'?'Selected camera contribution is drawn onto the performer volume; cross-hatching marks weak contribution sectors.':'M1.5 adds gsplat-aligned angle sufficiency and contribution diagnostics: physical camera bodies, true sensor frustums, focus envelope, and contribution overlay.'}
function onDown(e){const asset=e.target.closest&&e.target.closest('[data-asset]'); if(asset&&mode==='Scene Setup'){selectedAssetId=asset.getAttribute('data-asset'); selectedCamera=null; const a=activeAsset(); drag={type:'asset',startX:e.clientX,startY:e.clientY,origX:a.x_ft,origY:a.y_ft}; svg.classList.add('dragging'); updateInspector(); return} drag={type:e.shiftKey?'pan':'orbit',startX:e.clientX,startY:e.clientY,origX:pan.x,origY:pan.y,origYaw:yaw,origPitch:pitch}; svg.classList.add('dragging')}
function onMove(e){if(!drag)return; if(drag.type==='asset'){const a=activeAsset(), scale=zoom*1.12*FT_TO_M; a.x_ft=drag.origX+(e.clientX-drag.startX)/scale; a.y_ft=drag.origY+(e.clientY-drag.startY)/(scale*.72); renderScene(); updateInspector()} else if(drag.type==='pan'){pan.x=drag.origX+(e.clientX-drag.startX); pan.y=drag.origY+(e.clientY-drag.startY); renderScene()} else {yaw=Math.max(-180,Math.min(180,drag.origYaw+(e.clientX-drag.startX)*.35)); pitch=Math.max(0,Math.min(55,drag.origPitch-(e.clientY-drag.startY)*.18)); byId('yawRange').value=yaw; byId('pitchRange').value=pitch; renderAll()}}
function onUp(){drag=null; svg.classList.remove('dragging')}
init();
</script>
</body>
</html>
""";
}
