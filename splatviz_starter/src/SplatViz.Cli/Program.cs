using System.Text.Json;
using SplatViz.Core.Analysis;
using SplatViz.Core.Export;
using SplatViz.Core.Reporting;
using SplatViz.Core.Scene;

var repoRoot = FindRepoRoot(AppContext.BaseDirectory);
var outputRoot = Path.Combine(repoRoot, "splatviz_sample_export");
if (Directory.Exists(outputRoot)) Directory.Delete(outputRoot, recursive: true);
Directory.CreateDirectory(outputRoot);
Directory.CreateDirectory(Path.Combine(outputRoot, "layouts"));

var plans = SampleLayoutFactory.BuildDefaultThreeTierPlans();
var scorer = new CoverageScorer();
var comparisonRows = new List<LayoutComparisonRow>();
var reportMap = new Dictionary<string, CoverageReport>();
var mountabilityMap = new Dictionary<string, MountabilityReport>();
var allTradeoffs = new List<CaptureTradeoff>();
var allSplatability = new List<SplatabilityCandidate>();
var splatabilityMap = new Dictionary<string, IReadOnlyList<SplatabilityCandidate>>();
var decisionRows = new List<object>();

foreach (var plan in plans)
{
    var report = scorer.Score(plan.Cameras, plan.CaptureVolume, plan.PerformerEnvelope);
    var mountability = MountabilityAnalyzer.Analyze(plan);
    var tradeoffs = CaptureTradeoffPlanner.Plan(plan, report);
    var selectedProfile = CaptureTradeoffPlanner.RecommendedProfile(plan, report);
    var splatability = SplatabilityPlanner.Plan(plan, report);
    var selectedSplatability = SplatabilityPlanner.Recommended(splatability);
    var solveTestCandidates = SplatabilityPlanner.SolveTestCandidates(splatability);
    allTradeoffs.AddRange(tradeoffs);
    allSplatability.AddRange(splatability);
    splatabilityMap[plan.Tier.ToString()] = splatability;
    reportMap[plan.Tier.ToString()] = report;
    mountabilityMap[plan.Tier.ToString()] = mountability;

    var slug = plan.Tier.ToString().ToLowerInvariant();
    var layoutFolder = Path.Combine(outputRoot, "layouts", slug);
    var figuresFolder = Path.Combine(layoutFolder, "figures");
    Directory.CreateDirectory(layoutFolder);
    Directory.CreateDirectory(figuresFolder);

    File.WriteAllText(Path.Combine(layoutFolder, "camera_schedule.csv"), CameraScheduleExporter.ToCsv(plan.Cameras, report.Contributions));
    File.WriteAllText(Path.Combine(layoutFolder, "mount_schedule.csv"), MountScheduleExporter.ToCsv(plan.Trusses, plan.Stands));
    File.WriteAllText(Path.Combine(layoutFolder, "cameras_colmap.txt"), ColmapKnownPoseExporter.CamerasTxt(plan.Cameras[0].Body, plan.Cameras[0].Lens, plan.Cameras[0].RecordingMode));
    File.WriteAllText(Path.Combine(layoutFolder, "coverage_summary.txt"), CoverageSummaryExporter.ToText(plan.Name, report));
    File.WriteAllText(Path.Combine(layoutFolder, "layout_summary.json"), LayoutSummaryExporter.ToJson(plan.Name, plan.Tier.ToString(), plan.Room, plan.CaptureVolume, plan.PerformerEnvelope, plan.Cameras, plan.Trusses, plan.Stands, report));
    File.WriteAllText(Path.Combine(layoutFolder, "layout.dxf"), DxfLayoutExporter.Export(plan.Room, plan.CaptureVolume, plan.Cameras, plan.Trusses, plan.Stands, report));
    File.WriteAllText(Path.Combine(layoutFolder, "mountability_warnings.json"), MountabilityExporter.ToJson(mountability));
    File.WriteAllText(Path.Combine(layoutFolder, "capture_tradeoffs.csv"), CaptureTradeoffExporter.ToCsv(tradeoffs));
    File.WriteAllText(Path.Combine(layoutFolder, "splat_viability_assessment.json"), SplatabilityExporter.ToJson(splatability));
    File.WriteAllText(Path.Combine(layoutFolder, "splat_viability_assessment.csv"), SplatabilityExporter.ToCsv(splatability));
    File.WriteAllText(Path.Combine(layoutFolder, "gsplat_synthetic_manifest.json"), SplatabilityExporter.GsplatManifestJson(plan, selectedSplatability, solveTestCandidates));
    File.WriteAllText(Path.Combine(layoutFolder, "gsplat_verification_plan.json"), SplatabilityExporter.GsplatManifestJson(plan, selectedSplatability, solveTestCandidates));
    WriteSyntheticStillPlaceholders(layoutFolder, plan, selectedSplatability, solveTestCandidates);

    var figureFiles = new List<string>();
    WriteFigure("overview_perspective.svg", SvgReportFigureGenerator.Overview(plan.Name, plan.Cameras, plan.CaptureVolume, report));
    WriteFigure("weak_zones.svg", SvgReportFigureGenerator.WeakZones($"{plan.Name} Weak Zones", plan.Cameras, plan.CaptureVolume, report));
    WriteFigure("redundant_angles.svg", SvgReportFigureGenerator.RedundantAngles($"{plan.Name} Redundant Angles", plan.Cameras, plan.CaptureVolume, report));
    WriteFigure("frustum_projection.svg", SvgReportFigureGenerator.FrustumProjection($"{plan.Name} Frustum Projection", plan.Cameras, report));

    void WriteFigure(string name, string content)
    {
        var rel = Path.Combine("layouts", slug, "figures", name).Replace('\\', '/');
        File.WriteAllText(Path.Combine(figuresFolder, name), content);
        figureFiles.Add(rel);
    }

    File.WriteAllText(Path.Combine(layoutFolder, "report_manifest.json"), ReportManifestExporter.ToJson(plan.Name, figureFiles));

    var dataRateTbHr = selectedProfile.EstimatedArrayTbHr;
    var coverageState = report.MissingSectors.Count > 0
        ? $"Missing: {string.Join(", ", report.MissingSectors.Take(2).Select(x => x.Label))}"
        : report.WeakSectors.Count > 0
            ? $"Weak: {string.Join(", ", report.WeakSectors.Take(2).Select(x => x.Label))}"
            : "No weak sectors";
    var redundancyState = report.RedundantSectors.Count > 0
        ? $"True redundant: {string.Join(", ", report.RedundantSectors.Take(2).Select(x => x.Label))}"
        : "No true redundant sectors";

    comparisonRows.Add(new LayoutComparisonRow(
        plan.Tier.ToString(),
        plan.Name,
        plan.Cameras.Count,
        report.Score,
        report.CoveredFraction,
        report.AveragePixelsPerCm,
        System.Math.Round(dataRateTbHr, 3),
        report.MissingSectors.Select(x => x.Label).ToArray(),
        report.WeakSectors.Select(x => x.Label).ToArray(),
        report.RedundantSectors.Select(x => x.Label).ToArray(),
        coverageState,
        redundancyState,
        report.MoveSuggestions.ToArray(),
        report.PortraitRollNotes.ToArray(),
        plan.PlainEnglishIntent,
        $"layouts/{slug}"));

    decisionRows.Add(new
    {
        tier = plan.Tier.ToString(),
        layout = plan.Name,
        selected_capture_profile = selectedProfile,
        selected_splatability_candidate = selectedSplatability,
        mountability_state = mountability.State,
        unassigned_mounts = mountability.UnassignedCameras,
        best_use = plan.Tier switch
        {
            LayoutTier.Lean => "Lowest-data viable layout for laptop preflight and fast synthetic tests.",
            LayoutTier.Recommended => "Best balanced starting point for one performer in a controlled volume.",
            _ => "Highest-resilience layout when occlusion, props, cloth, or fast motion justify the data rate."
        }
    });
}

var recommended = ChooseRecommended(comparisonRows);
var comparisonSummary = "Recommended is selected as the balanced capture build: full coverage, controlled data rate, useful 4DGS overlap, and fewer mountability gaps than Premium. Lean is the laptop preflight baseline; Premium is reserved for occlusion-heavy action.";
File.WriteAllText(Path.Combine(outputRoot, "layout_comparison.json"), LayoutComparisonExporter.ToJson(comparisonRows, recommended.Name, comparisonSummary));
File.WriteAllText(Path.Combine(outputRoot, "layout_comparison.html"), LayoutComparisonHtmlExporter.ToHtml(comparisonRows, recommended.Name, comparisonSummary));
File.WriteAllText(Path.Combine(outputRoot, "capture_tradeoffs.json"), CaptureTradeoffExporter.ToJson(allTradeoffs));
File.WriteAllText(Path.Combine(outputRoot, "capture_tradeoffs.csv"), CaptureTradeoffExporter.ToCsv(allTradeoffs));
File.WriteAllText(Path.Combine(outputRoot, "splat_viability_assessment.json"), SplatabilityExporter.ToJson(allSplatability));
File.WriteAllText(Path.Combine(outputRoot, "splat_viability_assessment.csv"), SplatabilityExporter.ToCsv(allSplatability));
File.WriteAllText(Path.Combine(outputRoot, "mountability_summary.json"), MountabilityExporter.CombinedToJson(mountabilityMap.Values));
File.WriteAllText(Path.Combine(outputRoot, "decision_summary.json"), JsonSerializer.Serialize(new
{
    splatviz_version = "1.5.0-m1.5",
    selected_layout = recommended.Name,
    selection_logic = new
    {
        technical_best = comparisonRows.OrderByDescending(r => r.Score).First().Name,
        balanced_recommendation = recommended.Name,
        lowest_data_viable = comparisonRows.OrderBy(r => r.EstimatedArrayTbHr).First(r => r.CoveredFraction >= 0.98).Name,
        highest_resilience = comparisonRows.OrderByDescending(r => r.Cameras).First().Name
    },
    splat_viability_policy = "Choose camera count, angle distribution, distance, aspect ratio, and resolution from projected subject detail, useful-angle sufficiency, frame margin, parallax continuity, focus-box confidence, and rig/lighting interference. Msplat may smoke-test exports, but production conclusions must track in gsplat.",
    layouts = decisionRows
}, new JsonSerializerOptions { WriteIndented = true }));

File.WriteAllText(Path.Combine(outputRoot, "angle_sufficiency_hypotheses.json"), JsonSerializer.Serialize(new
{
    splatviz_version = "1.5.0-m1.5",
    status = "hypotheses_pending_gsplat_validation",
    policy = "Use camera-count and angular-density scores only as prediction guidance until gsplat held-out-view tests confirm them.",
    layouts = plans.Select(plan => new
    {
        tier = plan.Tier.ToString(),
        layout = plan.Name,
        camera_count = plan.Cameras.Count,
        nominal_gap_degrees = System.Math.Round(360.0 / plan.Cameras.Count, 2),
        full_body_performer_hypothesis = plan.Cameras.Count < 20 ? "weak" : plan.Cameras.Count < 30 ? "baseline_requires_validation" : "stronger_angle_density",
        gsplat_required = true
    })
}, new JsonSerializerOptions { WriteIndented = true }));
File.WriteAllText(Path.Combine(outputRoot, "viewer.html"), ViewerHtmlExporter.ToHtml(plans, reportMap, mountabilityMap, splatabilityMap));
var appFolder = Path.Combine(outputRoot, "app");
Directory.CreateDirectory(appFolder);
File.WriteAllText(Path.Combine(appFolder, "index.html"), AppHtmlExporter.ToHtml(plans, reportMap, mountabilityMap, splatabilityMap));
File.WriteAllText(Path.Combine(outputRoot, "README.txt"), "Open app/index.html first for the Auto-Rigged 3D Scene scaffold. viewer.html remains the prior generated viewer. Then inspect splat_viability_assessment.json and layouts/recommended/gsplat_synthetic_manifest.json.");

Console.WriteLine($"Wrote SplatViz M1.5 sample export to: {outputRoot}");
Console.WriteLine($"Generated layout tiers: {string.Join(", ", plans.Select(p => p.Tier))}");
Console.WriteLine($"Recommended layout: {recommended.Name}");
Console.WriteLine("Export files: viewer.html, splat_viability_assessment.json/csv, gsplat_synthetic_manifest.json, synthetic_stills placeholders, layout_comparison.html, per-layout schedules, DXF, and SVG figures");


static void WriteSyntheticStillPlaceholders(string layoutFolder, LayoutPlan plan, SplatabilityCandidate selectedSplatability, IReadOnlyDictionary<string, SplatabilityCandidate?> solveTestCandidates)
{
    var syntheticRoot = Path.Combine(layoutFolder, "synthetic_stills");
    var imagesRoot = Path.Combine(syntheticRoot, "images");
    Directory.CreateDirectory(imagesRoot);

    foreach (var camera in plan.Cameras.OrderBy(c => c.Id))
    {
        var cameraFolder = Path.Combine(imagesRoot, camera.Id);
        Directory.CreateDirectory(cameraFolder);
        File.WriteAllText(Path.Combine(cameraFolder, "frame_000001.exr"), SplatabilityExporter.PlaceholderExrText(camera.Id, selectedSplatability));
    }

    File.WriteAllText(Path.Combine(syntheticRoot, "contact_sheet.html"), SplatabilityExporter.ContactSheetHtml(plan, selectedSplatability));
    File.WriteAllText(Path.Combine(syntheticRoot, "splatviz_cameras.json"), SplatabilityExporter.SyntheticCamerasJson(plan, selectedSplatability));
    File.WriteAllText(Path.Combine(syntheticRoot, "splatviz_manifest.json"), SplatabilityExporter.GsplatManifestJson(plan, selectedSplatability, solveTestCandidates));
    File.WriteAllText(Path.Combine(syntheticRoot, "gsplat_verification_plan.json"), SplatabilityExporter.GsplatManifestJson(plan, selectedSplatability, solveTestCandidates));
}

static LayoutComparisonRow ChooseRecommended(IReadOnlyList<LayoutComparisonRow> rows)
{
    var recommended = rows.FirstOrDefault(r => r.Tier == "Recommended");
    if (recommended is not null && recommended.CoveredFraction >= 0.98 && recommended.Score >= 88.0) return recommended;
    return rows
        .Where(r => r.CoveredFraction >= 0.98)
        .OrderByDescending(r => r.Score - (r.EstimatedArrayTbHr * 0.04))
        .First();
}

static string FindRepoRoot(string baseDirectory)
{
    var dir = new DirectoryInfo(baseDirectory);
    while (dir is not null)
    {
        if (File.Exists(Path.Combine(dir.FullName, "SplatViz.sln"))) return dir.FullName;
        dir = dir.Parent;
    }
    throw new DirectoryNotFoundException("Could not find SplatViz.sln from CLI base directory.");
}
