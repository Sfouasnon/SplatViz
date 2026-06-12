namespace SplatViz.Core.Analysis;

public sealed record MountabilityIssue(
    string Severity,
    string CameraId,
    string MountId,
    string Message);
