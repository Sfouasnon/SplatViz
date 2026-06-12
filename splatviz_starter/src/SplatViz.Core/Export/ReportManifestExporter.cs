using System.Text.Json;

namespace SplatViz.Core.Export;

public static class ReportManifestExporter
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    public static string ToJson(string layoutName, IEnumerable<string> figureFiles)
    {
        var payload = new
        {
            report_type = "splatviz_decision_report_manifest",
            report_version = "0.5.0",
            layout_name = layoutName,
            figures = figureFiles.Select(path => new { path, status = "generated" }).ToList()
        };
        return JsonSerializer.Serialize(payload, Options);
    }
}
