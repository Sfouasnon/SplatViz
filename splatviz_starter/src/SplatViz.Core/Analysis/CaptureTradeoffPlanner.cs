using SplatViz.Core.Cameras;
using SplatViz.Core.Scene;

namespace SplatViz.Core.Analysis;

public static class CaptureTradeoffPlanner
{
    public static IReadOnlyList<CaptureTradeoff> Plan(LayoutPlan plan, CoverageReport report)
    {
        return RecordingMode.PlanningProfiles()
            .Select(mode => Build(plan, report, mode))
            .ToList();
    }

    public static CaptureTradeoff RecommendedProfile(LayoutPlan plan, CoverageReport report)
    {
        var options = Plan(plan, report);
        if (plan.Tier == LayoutTier.Lean)
            return options.First(x => x.ProfileName.Contains("24fps LQ", StringComparison.OrdinalIgnoreCase) && x.ProfileName.Contains("6K", StringComparison.OrdinalIgnoreCase));
        if (plan.Tier == LayoutTier.Premium)
            return options.First(x => x.ProfileName.Contains("48fps MQ", StringComparison.OrdinalIgnoreCase));
        return options.First(x => x.ProfileName.Contains("24fps MQ", StringComparison.OrdinalIgnoreCase) && x.ProfileName.Contains("6K", StringComparison.OrdinalIgnoreCase));
    }

    private static CaptureTradeoff Build(LayoutPlan plan, CoverageReport report, RecordingMode mode)
    {
        var tbHr = plan.Cameras.Count * mode.EstimatedDataRateMBps * 3600.0 / 1_000_000.0;
        var band = DecisionBand(plan, report, mode, tbHr);
        return new CaptureTradeoff(
            plan.Tier.ToString(),
            plan.Name,
            mode.Name,
            plan.Cameras.Count,
            mode.WidthPx,
            mode.HeightPx,
            mode.FramesPerSecond,
            mode.Compression,
            mode.EstimatedDataRateMBps,
            System.Math.Round(tbHr, 3),
            band,
            Rationale(plan, report, mode, tbHr, band));
    }

    private static string DecisionBand(LayoutPlan plan, CoverageReport report, RecordingMode mode, double tbHr)
    {
        if (report.CoveredFraction < 0.98) return "not_viable_until_layout_fixed";
        if (mode.WidthPx < 5120 && report.AveragePixelsPerCm < 12) return "resolution_risk";
        if (tbHr <= 10 && mode.FramesPerSecond <= 24) return "lowest_data_viable";
        if (tbHr <= 30 && mode.FramesPerSecond <= 48) return "balanced_recommended";
        if (mode.FramesPerSecond >= 48 && plan.Tier == LayoutTier.Premium) return "motion_resilience";
        return "expensive_special_case";
    }

    private static string Rationale(LayoutPlan plan, CoverageReport report, RecordingMode mode, double tbHr, string band)
    {
        if (band == "not_viable_until_layout_fixed") return "Do not solve missing coverage with resolution or frame rate; fix camera placement first.";
        if (band == "resolution_risk") return "This lower-resolution option may be acceptable for quick viewer checks, but is risky for final capture preflight.";
        if (band == "lowest_data_viable") return "Lowest-data profile that still keeps the full 6K sensor area for layout validation.";
        if (band == "balanced_recommended") return "Best balance of data rate, full-sensor spatial detail, and motion sampling for one performer.";
        if (band == "motion_resilience") return "Use when fast action, cloth, props, or occlusion risk justify the higher data rate.";
        return $"High data-rate profile ({tbHr:0.0} TB/hr est.); reserve for shots where motion or occlusion risk justifies it.";
    }
}
