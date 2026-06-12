using SplatViz.Core.Math;

namespace SplatViz.Core.Scene;

public sealed record Room(Vec3d SizeM)
{
    public static Room Default8x8x4() => new(new Vec3d(8, 8, 4));

    public static Room NozStage1() => new(new Vec3d(17.9832, 17.3736, 5.4864));
}
