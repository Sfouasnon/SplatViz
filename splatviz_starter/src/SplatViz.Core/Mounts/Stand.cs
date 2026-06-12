using SplatViz.Core.Math;

namespace SplatViz.Core.Mounts;

public sealed record Stand(string Id, Vec3d BasePositionM, double MinHeightMm, double MaxHeightMm, double HeightStepMm = 100);
