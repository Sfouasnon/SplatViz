namespace SplatViz.Core.Analysis;

public sealed record CoverageReport(
    double Score,
    double CoveredFraction,
    double MaxGapDegrees,
    double AverageCappedRedundancy,
    double AveragePixelsPerCm,
    IReadOnlyList<int> WeakBins,
    IReadOnlyList<int> RedundantBins,
    IReadOnlyDictionary<int, int> BinCounts,
    IReadOnlyList<SectorInfo> MissingSectors,
    IReadOnlyList<SectorInfo> WeakSectors,
    IReadOnlyList<SectorInfo> UsefulOverlapSectors,
    IReadOnlyList<SectorInfo> RedundantSectors,
    IReadOnlyList<CameraContribution> Contributions,
    IReadOnlyList<string> Recommendations,
    IReadOnlyList<string> PortraitRollNotes,
    IReadOnlyList<string> MoveSuggestions);
