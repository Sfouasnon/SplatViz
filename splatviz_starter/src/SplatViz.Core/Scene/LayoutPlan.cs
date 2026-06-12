using SplatViz.Core.Cameras;
using SplatViz.Core.Mounts;

namespace SplatViz.Core.Scene;

public sealed record LayoutPlan(
    string Name,
    LayoutTier Tier,
    Room Room,
    CaptureVolume CaptureVolume,
    PerformerEnvelope PerformerEnvelope,
    IReadOnlyList<CameraInstance> Cameras,
    IReadOnlyList<BoxTruss> Trusses,
    IReadOnlyList<Stand> Stands,
    string PlainEnglishIntent);
