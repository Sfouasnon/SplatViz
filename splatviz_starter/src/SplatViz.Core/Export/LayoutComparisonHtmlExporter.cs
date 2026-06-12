using System.Globalization;
using System.Text;

namespace SplatViz.Core.Export;

public static class LayoutComparisonHtmlExporter
{
    public static string ToHtml(IEnumerable<LayoutComparisonRow> rows, string recommendedLayout, string executiveSummary)
    {
        var list = rows.ToList();
        var sb = new StringBuilder();
        sb.AppendLine("<!doctype html><html><head><meta charset='utf-8'><title>SplatViz Layout Comparison</title>");
        sb.AppendLine("<style>");
        sb.AppendLine("body{margin:0;background:#071014;color:#eef4f1;font-family:Inter,Arial,sans-serif}main{padding:52px 64px}h1{font-size:48px;margin:0 0 10px}p{color:#aec0b8;font-size:18px;line-height:1.45}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:22px;margin-top:28px}.card{background:#10191d;border:1px solid #24343b;border-radius:22px;padding:24px}.card.recommended{border-color:#73b98f;box-shadow:0 0 0 1px #73b98f44}.label{color:#73b98f;font-size:13px;text-transform:uppercase;letter-spacing:.12em}.score{font-size:42px;font-weight:800;margin:10px 0}.meta{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin:18px 0}.meta div{background:#0b1316;border:1px solid #1e3036;border-radius:12px;padding:12px}.meta b{display:block;font-size:22px}.meta span{color:#95a9a0;font-size:13px}table{width:100%;border-collapse:collapse;margin-top:28px;background:#10191d;border-radius:18px;overflow:hidden}th,td{padding:14px 16px;border-bottom:1px solid #24343b;text-align:left}th{color:#9ab7a8;background:#0b1316}.ok{color:#73b98f}.warn{color:#d5a240}.bad{color:#d66363}.note{margin-top:26px;background:#0b1316;border:1px solid #24343b;border-radius:18px;padding:20px}</style>");
        sb.AppendLine("</head><body><main>");
        sb.AppendLine("<div class='label'>SplatViz M1.1 decision report</div>");
        sb.AppendLine("<h1>Layout Comparison</h1>");
        sb.AppendLine($"<p>{Escape(executiveSummary)}</p>");
        sb.AppendLine("<div class='grid'>");
        foreach (var row in list)
        {
            var cls = row.Name == recommendedLayout ? "card recommended" : "card";
            sb.AppendLine($"<section class='{cls}'>");
            sb.AppendLine($"<div class='label'>{Escape(row.Tier)} {(row.Name == recommendedLayout ? "• recommended" : string.Empty)}</div>");
            sb.AppendLine($"<h2>{Escape(row.Name)}</h2>");
            sb.AppendLine($"<div class='score'>{row.Score:0.0}</div>");
            sb.AppendLine("<div class='meta'>");
            sb.AppendLine($"<div><b>{row.Cameras}</b><span>cameras</span></div>");
            sb.AppendLine($"<div><b>{row.EstimatedArrayTbHr:0.0}</b><span>TB/hr est.</span></div>");
            sb.AppendLine($"<div><b>{row.CoveredFraction:0.00}</b><span>coverage</span></div>");
            sb.AppendLine($"<div><b>{row.AveragePixelsPerCm:0.0}</b><span>px/cm</span></div>");
            sb.AppendLine("</div>");
            sb.AppendLine($"<p>{Escape(row.IntendedUse)}</p>");
            sb.AppendLine("</section>");
        }
        sb.AppendLine("</div>");

        sb.AppendLine("<table><thead><tr><th>Tier</th><th>Coverage state</th><th>Redundancy state</th><th>Move suggestion</th><th>Roll guidance</th></tr></thead><tbody>");
        foreach (var row in list)
        {
            var coverageClass = row.MissingSectors.Length > 0 ? "bad" : row.WeakSectors.Length > 0 ? "warn" : "ok";
            var redundancyClass = row.TrueRedundantSectors.Length > 0 ? "warn" : "ok";
            sb.AppendLine("<tr>");
            sb.AppendLine($"<td>{Escape(row.Tier)}</td>");
            sb.AppendLine($"<td class='{coverageClass}'>{Escape(row.CoverageState)}</td>");
            sb.AppendLine($"<td class='{redundancyClass}'>{Escape(row.RedundancyState)}</td>");
            sb.AppendLine($"<td>{Escape(row.MoveSuggestions.FirstOrDefault() ?? "No move required")}</td>");
            sb.AppendLine($"<td>{Escape(row.SensorRollNotes.FirstOrDefault() ?? "Roll guidance unavailable")}</td>");
            sb.AppendLine("</tr>");
        }
        sb.AppendLine("</tbody></table>");
        sb.AppendLine("<div class='note'><b>Overlap policy:</b> 0 cameras = missing, 1 camera = weak, 2–4 cameras = useful overlap for 4DGS, and only near-identical 5+ camera clusters are considered true redundant.</div>");
        sb.AppendLine("</main></body></html>");
        return sb.ToString();
    }

    private static string Escape(string value) => System.Security.SecurityElement.Escape(value) ?? string.Empty;
}

public sealed record LayoutComparisonRow(
    string Tier,
    string Name,
    int Cameras,
    double Score,
    double CoveredFraction,
    double AveragePixelsPerCm,
    double EstimatedArrayTbHr,
    string[] MissingSectors,
    string[] WeakSectors,
    string[] TrueRedundantSectors,
    string CoverageState,
    string RedundancyState,
    string[] MoveSuggestions,
    string[] SensorRollNotes,
    string IntendedUse,
    string ExportFolder);
