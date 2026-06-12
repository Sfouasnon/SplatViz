using System.Text.Json;
using SplatViz.Core.Analysis;

namespace SplatViz.Core.Export;

public static class MountabilityExporter
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    public static string ToJson(MountabilityReport report)
    {
        return JsonSerializer.Serialize(report, Options);
    }

    public static string CombinedToJson(IEnumerable<MountabilityReport> reports)
    {
        var payload = new
        {
            splatviz_version = "0.5.0-m0.5",
            report_type = "mountability_summary",
            reports
        };
        return JsonSerializer.Serialize(payload, Options);
    }
}
