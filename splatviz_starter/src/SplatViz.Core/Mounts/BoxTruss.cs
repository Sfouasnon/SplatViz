using SplatViz.Core.Math;

namespace SplatViz.Core.Mounts;

public sealed record BoxTruss(string Id, Vec3d StartM, Vec3d EndM, double CrossSectionMm, double SlotSpacingMm, IReadOnlyList<string> MountableFaces)
{
    public double LengthM => Vec3d.Distance(StartM, EndM);
}
