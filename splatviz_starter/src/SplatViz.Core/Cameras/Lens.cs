namespace SplatViz.Core.Cameras;

public sealed record Lens(string Name, double FocalLengthMm)
{
    public static Lens Rokinon24mm() => new("Rokinon DSX24-RF 24mm T1.5", 24.0);
    public static Lens Rokinon50mm() => new("Rokinon DSX50-RF 50mm T1.5", 50.0);
}
