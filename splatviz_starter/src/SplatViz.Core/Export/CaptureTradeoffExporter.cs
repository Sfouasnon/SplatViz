using System.Globalization;
using System.Text;
using System.Text.Json;
using SplatViz.Core.Analysis;

namespace SplatViz.Core.Export;

public static class CaptureTradeoffExporter
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    public static string ToJson(IEnumerable<CaptureTradeoff> rows)
    {
        var payload = new
        {
            splatviz_version = "0.5.0-m0.5",
            report_type = "capture_parameter_tradeoffs",
            policy = new
            {
                layout_first = "Fix placement and coverage before spending data on FPS or HQ compression.",
                fps = "Use 24 fps for static/slow tests, 48 fps for motion-safe 4DGS preflight, and 60 fps only for fast action or high-frequency cloth.",
                compression = "LQ/MQ/HQ are treated as planning levers; verify final R3D data rates from camera tests."
            },
            profiles = rows
        };
        return JsonSerializer.Serialize(payload, Options);
    }

    public static string ToCsv(IEnumerable<CaptureTradeoff> rows)
    {
        var sb = new StringBuilder();
        sb.AppendLine("tier,layout,profile,cameras,width_px,height_px,fps,compression,per_camera_mb_s,array_tb_hr,decision_band,rationale");
        foreach (var r in rows)
        {
            sb.AppendLine(string.Join(',', new[]
            {
                Escape(r.Tier), Escape(r.LayoutName), Escape(r.ProfileName), r.CameraCount.ToString(CultureInfo.InvariantCulture),
                r.WidthPx.ToString(CultureInfo.InvariantCulture), r.HeightPx.ToString(CultureInfo.InvariantCulture), F(r.FramesPerSecond), Escape(r.Compression),
                F(r.EstimatedPerCameraMBps), F(r.EstimatedArrayTbHr), Escape(r.DecisionBand), Escape(r.Rationale)
            }));
        }
        return sb.ToString();
    }

    private static string F(double value) => value.ToString("0.###", CultureInfo.InvariantCulture);
    private static string Escape(string value) => value.Contains(',') || value.Contains('"') ? $"\"{value.Replace("\"", "\"\"")}\"" : value;
}
