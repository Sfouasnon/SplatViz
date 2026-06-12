namespace SplatViz.Core.Analysis;

public sealed record CameraContribution(
    string CameraId,
    int PrimaryBins,
    int TotalBinsSeen,
    double ContributionScore,
    string ContributionBand,
    bool LeanRemovalCandidate,
    string SuggestedAction,
    string Rationale);
