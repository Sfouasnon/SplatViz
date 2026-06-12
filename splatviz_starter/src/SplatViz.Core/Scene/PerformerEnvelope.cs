namespace SplatViz.Core.Scene;

public sealed record PerformerEnvelope(double HeightM, double RadiusM)
{
    public static PerformerEnvelope SingleHumanDefault() => new(1.8, 0.35);
}
