using System.Globalization;
using System.Text;
using System.Text.Json;
using SplatViz.Core.Analysis;
using SplatViz.Core.Scene;

namespace SplatViz.Core.Export;

public static class SplatabilityExporter
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    public static string ToJson(IEnumerable<SplatabilityCandidate> candidates)
    {
        return JsonSerializer.Serialize(new
        {
            splatviz_version = "1.5.0-m1.5",
            assessment_type = "splat_viability_focus_box_resolution_distance_assessment",
            lens_profile = LensProfilePayload(),
            exposure_assumption = new { t_stop = 5.6, shutter_angle_degrees = 90, iso = 800, focal_length_mm = 24 },
            focus_model = FocusModelPayload(),
            candidates
        }, Options);
    }

    public static string ToCsv(IEnumerable<SplatabilityCandidate> candidates)
    {
        var sb = new StringBuilder();
        sb.AppendLine("tier,layout,resolution,width_px,height_px,distance_m,px_per_cm,body_frame_height_pct,body_margin_score,neighbor_parallax_score,dof_near_m,dof_far_m,acceptable_focus_pass,critical_near_m,critical_far_m,critical_sharpness_score,focus_box_confidence_score,eye_plane_confidence_score,rig_lighting_interference_score,splatability_score,production_feasibility_score,verdict,notes");
        foreach (var c in candidates)
        {
            sb.AppendLine(string.Join(',', new[]
            {
                Esc(c.Tier), Esc(c.LayoutName), Esc(c.ResolutionName), c.WidthPx.ToString(CultureInfo.InvariantCulture), c.HeightPx.ToString(CultureInfo.InvariantCulture),
                F(c.CameraDistanceM), F(c.PixelsPerCm), F(c.BodyFrameHeightPercent), F(c.BodyMarginScore), F(c.NeighborParallaxScore), F(c.DepthOfFieldNearM), F(c.DepthOfFieldFarM), c.AcceptableFocusPass.ToString().ToLowerInvariant(), F(c.CriticalSharpnessNearM), F(c.CriticalSharpnessFarM), F(c.CriticalSharpnessScore), F(c.FocusBoxConfidenceScore), F(c.EyePlaneConfidenceScore), F(c.RigLightingInterferenceScore), F(c.SplatabilityScore), F(c.ProductionFeasibilityScore), Esc(c.Verdict), Esc(string.Join("; ", c.Notes))
            }));
        }
        return sb.ToString();
    }

    public static string GsplatManifestJson(LayoutPlan plan, SplatabilityCandidate recommended, IReadOnlyDictionary<string, SplatabilityCandidate?> solveCandidates)
    {
        return JsonSerializer.Serialize(new
        {
            splatviz_version = "1.5.0-m1.5",
            manifest_type = "gsplat_aligned_synthetic_verification_manifest",
            layout = plan.Name,
            tier = plan.Tier.ToString(),
            preferred_color_pipeline = "LinAP1",
            validation_policy = new
            {
                prediction_status = "SplatViz predictions are hypotheses until verified with gsplat.",
                msplat_role = "optional local smoke test only",
                gsplat_role = "source-of-truth validation path for production conclusions",
                recommended_metrics = new[] { "held_out_view_psnr", "held_out_view_ssim", "visual_error_map", "weak_zone_inspection" }
            },
            render_targets = new[]
            {
                new { id = "quick_1080p", width_px = 1920, height_px = 1080, purpose = "fast export/smoke test" },
                new { id = "validation_2k", width_px = 2048, height_px = 1152, purpose = "first meaningful gsplat validation set" }
            },
            train_holdout_policy = new
            {
                split = "hold out every sixth camera for validation unless user overrides",
                rationale = "held-out cameras test whether camera angle coverage generalizes rather than memorizes training views"
            },
            angle_sufficiency_hypotheses = AngleSufficiencyPayload(plan.Cameras.Count),
            lens_profile = LensProfilePayload(),
            focus_model = FocusModelPayload(),
            recommended_candidate = recommended,
            solve_test_candidates = solveCandidates,
            naming = new
            {
                image_root = "synthetic_stills/images",
                camera_folder_pattern = "C##",
                still_pattern = "frame_000001.exr",
                contact_sheet = "synthetic_stills/contact_sheet.html",
                metadata = "synthetic_stills/splatviz_cameras.json",
                manifest = "synthetic_stills/splatviz_manifest.json"
            },
            cameras = plan.Cameras.OrderBy(c => c.Id).Select((c, idx) => new
            {
                camera_id = c.Id,
                order = idx + 1,
                image_path = $"synthetic_stills/images/{c.Id}/frame_000001.exr",
                focus_target = "performer_eyes",
                focus_distance_m = System.Math.Round(c.DistanceToAimM, 3),
                portrait_roll = c.PortraitRoll,
                split = idx % 6 == 5 ? "holdout" : "train"
            })
        }, Options);
    }

    public static string SyntheticCamerasJson(LayoutPlan plan, SplatabilityCandidate recommended)
    {
        return JsonSerializer.Serialize(new
        {
            splatviz_version = "1.5.0-m1.5",
            metadata_type = "gsplat_synthetic_camera_metadata",
            layout = plan.Name,
            recommended_candidate = recommended,
            coordinate_system = new { handedness = "right_handed", up_axis = "Z", units = "meters" },
            color_pipeline = "LinAP1",
            lens_profile = LensProfilePayload(),
            focus_model = FocusModelPayload(),
            cameras = plan.Cameras.OrderBy(c => c.Id).Select(c => new
            {
                id = c.Id,
                image_path = $"images/{c.Id}/frame_000001.exr",
                position_m = new[] { c.PositionM.X, c.PositionM.Y, c.PositionM.Z },
                aim_target_m = new[] { c.AimTargetM.X, c.AimTargetM.Y, c.AimTargetM.Z },
                focus_target = "performer_eyes",
                focus_distance_m = System.Math.Round(c.DistanceToAimM, 3),
                portrait_roll = c.PortraitRoll,
                mount = c.Mount.Type,
                mount_id = c.Mount.Id
            })
        }, Options);
    }

    public static string ContactSheetHtml(LayoutPlan plan, SplatabilityCandidate recommended)
    {
        var sb = new StringBuilder();
        sb.AppendLine("<!doctype html>");
        sb.AppendLine("<html><head><meta charset=\"utf-8\"><title>SplatViz Synthetic Still Contact Sheet</title>");
        sb.AppendLine("<style>body{margin:0;background:#071014;color:#eef4f1;font-family:Inter,Arial,sans-serif;padding:30px}h1{margin:0 0 8px}.meta{color:#98ada5;margin-bottom:24px}.grid{display:grid;grid-template-columns:repeat(6,minmax(150px,1fr));gap:14px}.card{background:#0d171b;border:1px solid #253a42;border-radius:16px;overflow:hidden}.render{height:120px;position:relative;background:linear-gradient(135deg,#102027,#071014)}.body{position:absolute;left:50%;top:18px;width:44px;height:78px;transform:translateX(-50%);border-radius:24px 24px 18px 18px;background:#75b98f66;border:1px solid #93d3aa}.axis{position:absolute;left:12px;right:12px;bottom:14px;height:1px;background:#2a464f}.cid{position:absolute;right:12px;top:10px;color:#9fb3aa}h2{font-size:16px;margin:10px 10px 4px}p{font-size:12px;color:#a9bcb4;margin:4px 10px 10px}</style></head>");
        sb.AppendLine("<body>");
        sb.AppendLine("<h1>SplatViz Synthetic Still Contact Sheet</h1>");
        sb.AppendLine($"<div class=\"meta\">{plan.Name} · recommended verification candidate: {recommended.ResolutionName} at {recommended.CameraDistanceM}m · placeholders only; renderer will replace with LinAP1 EXR stills.</div>");
        sb.AppendLine("<div class=\"grid\">");
        foreach (var c in plan.Cameras.OrderBy(c => c.Id))
        {
            var azimuth = System.Math.Round((System.Math.Atan2(c.PositionM.Y, c.PositionM.X) * 180.0 / System.Math.PI + 360.0) % 360.0, 1);
            var roll = c.PortraitRoll ? "portrait roll" : "landscape";
            sb.AppendLine("<article class=\"card\">");
            sb.AppendLine($"<div class=\"render\"><div class=\"body\"></div><div class=\"axis\"></div><span class=\"cid\">{c.Id}</span></div>");
            sb.AppendLine($"<h2>{c.Id}</h2>");
            sb.AppendLine($"<p>{azimuth}° azimuth · {roll}</p>");
            sb.AppendLine($"<p>{System.Math.Round(c.DistanceToAimM, 2)}m focus distance · {System.Math.Round(c.ApproxPixelsPerCmAtAim, 2)} px/cm baseline</p>");
            sb.AppendLine("</article>");
        }
        sb.AppendLine("</div></body></html>");
        return sb.ToString();
    }

    public static string PlaceholderExrText(string cameraId, SplatabilityCandidate recommended)
    {
        return $"SPLATVIZ PLACEHOLDER EXR\nCamera: {cameraId}\nColor pipeline: LinAP1\nResolution: {recommended.ResolutionName}\nDistance candidate: {recommended.CameraDistanceM}m\nThis placeholder reserves the gsplat-aligned synthetic verification path. Msplat may smoke-test this structure, but gsplat is the validation target.\n";
    }


    private static object AngleSufficiencyPayload(int cameraCount)
    {
        var maxGapDegrees = 360.0 / System.Math.Max(cameraCount, 1);
        var state = cameraCount < 20 || maxGapDegrees > 17.0
            ? "weak_for_full_body_performer_hypothesis"
            : cameraCount < 30 || maxGapDegrees > 15.0
                ? "baseline_requires_gsplat_holdout_validation"
                : "stronger_angle_density_hypothesis";

        return new
        {
            asset_type = "full_body_performer",
            camera_count = cameraCount,
            max_nominal_gap_degrees = System.Math.Round(maxGapDegrees, 2),
            target_max_gap_degrees = 15.0,
            minimum_useful_views_hypothesis = 24,
            state,
            conclusion_policy = "Do not convert this hypothesis into a production conclusion until a gsplat solve confirms held-out views and weak-zone predictions."
        };
    }

    private static object LensProfilePayload() => new
    {
        manufacturer = "Rokinon / Samyang",
        model = "DSX24-RF",
        mount = "Canon RF",
        upc = "0-84438-76699-8",
        focal_length_mm = 24,
        max_aperture_t = 1.5,
        working_stop_t = 5.6,
        aperture_range = "T1.5-T22",
        minimum_focus_distance_m = 0.25,
        minimum_focus_distance_in = 9.84,
        optical_construction = "13 elements in 12 groups",
        diaphragm_blades = 9,
        coating = "Ultra Multi-Coating (UMC)",
        filter_size_mm = 77,
        max_diameter_mm = 84,
        length_mm = 121.1,
        weight_g = 663
    };

    private static object FocusModelPayload() => new
    {
        focus_practice = "locked focus per camera on performer eyes",
        focus_target = "performer_eyes",
        focus_box_half_depth_m = 0.75,
        production_method = "tape box around performer where focus still resolves well",
        reconstruction_note = "critical sharpness zone is intentionally narrower than acceptable DOF/hyperfocal zone"
    };

    private static string F(double v) => v.ToString("0.###", CultureInfo.InvariantCulture);
    private static string Esc(string s) => s.Contains(',') || s.Contains('"') || s.Contains(';') ? $"\"{s.Replace("\"", "\"\"")}\"" : s;
}
