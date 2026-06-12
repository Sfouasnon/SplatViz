using System.Text.Json;

namespace SplatViz.Core.Export;

public static class LayoutComparisonExporter
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    public static string ToJson(IEnumerable<object> layouts, string recommendedLayout, string summary)
    {
        var payload = new
        {
            splatviz_version = "0.5.0-m0.5",
            comparison_type = "layout_tier_comparison",
            recommended_layout = recommendedLayout,
            executive_summary = summary,
            overlap_policy = new
            {
                missing = "0 cameras = missing coverage",
                weak = "1 camera = weak coverage",
                useful = "2-4 cameras = useful overlap for 4DGS",
                redundant = "5+ cameras only when near-identical azimuth/elevation views add little parallax"
            },
            layouts = layouts
        };
        return JsonSerializer.Serialize(payload, Options);
    }
}
