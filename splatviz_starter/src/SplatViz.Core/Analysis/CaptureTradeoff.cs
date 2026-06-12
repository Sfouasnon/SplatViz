namespace SplatViz.Core.Analysis;

public sealed record CaptureTradeoff(
    string Tier,
    string LayoutName,
    string ProfileName,
    int CameraCount,
    int WidthPx,
    int HeightPx,
    double FramesPerSecond,
    string Compression,
    double EstimatedPerCameraMBps,
    double EstimatedArrayTbHr,
    string DecisionBand,
    string Rationale);
