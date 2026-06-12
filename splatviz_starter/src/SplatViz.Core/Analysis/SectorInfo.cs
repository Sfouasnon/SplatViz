namespace SplatViz.Core.Analysis;

public sealed record SectorInfo(
    int Bin,
    string Label,
    double StartDegrees,
    double EndDegrees,
    int CoverageCount,
    string Band,
    string Diagnosis);
