using System.Text;
using SplatViz.Core.Analysis;

namespace SplatViz.Core.Export;

public static class CoverageSummaryExporter
{
    public static string ToText(string layoutName, CoverageReport report)
    {
        var sb = new StringBuilder();
        sb.AppendLine($"Layout: {layoutName}");
        sb.AppendLine($"Score: {report.Score:0.0}");
        sb.AppendLine($"Covered Fraction: {report.CoveredFraction:0.00}");
        sb.AppendLine($"Max Gap Degrees: {report.MaxGapDegrees:0.0}");
        sb.AppendLine($"Avg px/cm: {report.AveragePixelsPerCm:0.0}");
        sb.AppendLine($"Missing sectors: {(report.MissingSectors.Count == 0 ? "none" : string.Join("; ", report.MissingSectors.Select(x => $"{x.Label} ({x.StartDegrees:0}-{x.EndDegrees:0} deg)")))}");
        sb.AppendLine($"Weak sectors: {(report.WeakSectors.Count == 0 ? "none" : string.Join("; ", report.WeakSectors.Select(x => $"{x.Label} ({x.CoverageCount} cam)")))}");
        sb.AppendLine($"Useful overlap sectors: {report.UsefulOverlapSectors.Count}");
        sb.AppendLine($"True redundant sectors: {(report.RedundantSectors.Count == 0 ? "none" : string.Join("; ", report.RedundantSectors.Select(x => $"{x.Label} ({x.CoverageCount} cams)")))}");
        sb.AppendLine("Portrait roll notes:");
        foreach (var line in report.PortraitRollNotes) sb.AppendLine($"- {line}");
        sb.AppendLine("Move suggestions:");
        foreach (var line in report.MoveSuggestions) sb.AppendLine($"- {line}");
        sb.AppendLine("Recommendations:");
        foreach (var line in report.Recommendations) sb.AppendLine($"- {line}");
        return sb.ToString();
    }
}
