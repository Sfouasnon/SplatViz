namespace SplatViz.Core.Analysis;

public sealed record MountabilityReport(
    string Tier,
    string LayoutName,
    int TotalCameras,
    int MountedCameras,
    int UnassignedCameras,
    IReadOnlyList<MountabilityIssue> Issues,
    IReadOnlyList<string> Summary)
{
    public string State => Issues.Any(i => i.Severity == "error")
        ? "blocked"
        : Issues.Any(i => i.Severity == "warning")
            ? "needs_mounting_work"
            : "mountable";
}
