using System.Text.Json;
using SplatViz.Core.Analysis;
using SplatViz.Core.Cameras;
using SplatViz.Core.Mounts;
using SplatViz.Core.Scene;

namespace SplatViz.Core.Export;

public static class LayoutSummaryExporter
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    public static string ToJson(string layoutName, string tier, Room room, CaptureVolume volume, PerformerEnvelope performer, IEnumerable<CameraInstance> cameras, IEnumerable<BoxTruss> trusses, IEnumerable<Stand> stands, CoverageReport report)
    {
        var cameraList = cameras.ToList();
        var camList = cameraList.Select(c => new
        {
            id = c.Id,
            position_m = new[] { c.PositionM.X, c.PositionM.Y, c.PositionM.Z },
            aim_target_m = new[] { c.AimTargetM.X, c.AimTargetM.Y, c.AimTargetM.Z },
            portrait_roll = c.PortraitRoll,
            h_fov_deg = System.Math.Round(c.HorizontalFovDegrees, 3),
            v_fov_deg = System.Math.Round(c.VerticalFovDegrees, 3),
            distance_to_aim_m = System.Math.Round(c.DistanceToAimM, 3),
            px_per_cm = System.Math.Round(c.ApproxPixelsPerCmAtAim, 3)
        }).ToList();

        var first = cameraList.FirstOrDefault();
        var dataRateTbHr = first is null ? 0.0 : cameraList.Count * first.RecordingMode.EstimatedDataRateMBps * 3600.0 / 1_000_000.0;

        var payload = new
        {
            splatviz_version = "0.5.0-m0.5",
            layout_name = layoutName,
            layout_tier = tier,
            coordinate_system = new { handedness = "right_handed", up_axis = "Z", internal_units = "meters_double_precision", cad_export_units = "millimeters" },
            room = new { size_m = new[] { room.SizeM.X, room.SizeM.Y, room.SizeM.Z } },
            capture_volume = new { center_m = new[] { volume.CenterM.X, volume.CenterM.Y, volume.CenterM.Z }, radius_m = volume.RadiusM, height_m = volume.HeightM },
            performer_envelope = new { height_m = performer.HeightM, radius_m = performer.RadiusM },
            camera_package = first is null ? null : new
            {
                body = first.Body.Name,
                lens = first.Lens.Name,
                recording = first.RecordingMode.Name,
                fps = first.RecordingMode.FramesPerSecond,
                compression = first.RecordingMode.Compression,
                estimated_per_camera_mb_s = first.RecordingMode.EstimatedDataRateMBps,
                estimated_array_tb_hr = System.Math.Round(dataRateTbHr, 3),
                data_rate_basis = first.RecordingMode.DataRateBasis
            },
            counts = new { cameras = camList.Count, trusses = trusses.Count(), stands = stands.Count() },
            coverage = new
            {
                score = report.Score,
                covered_fraction = report.CoveredFraction,
                max_gap_degrees = report.MaxGapDegrees,
                average_useful_overlap = report.AverageCappedRedundancy,
                average_pixels_per_cm = report.AveragePixelsPerCm,
                missing_sectors = report.MissingSectors,
                weak_sectors = report.WeakSectors,
                useful_overlap_sectors = report.UsefulOverlapSectors,
                true_redundant_sectors = report.RedundantSectors
            },
            sensor_roll_analysis = report.PortraitRollNotes,
            camera_contributions = report.Contributions,
            move_suggestions = report.MoveSuggestions,
            recommendations = report.Recommendations,
            cameras = camList
        };
        return JsonSerializer.Serialize(payload, Options);
    }
}
