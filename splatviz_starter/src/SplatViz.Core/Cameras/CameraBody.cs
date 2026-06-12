namespace SplatViz.Core.Cameras;

public sealed record CameraBody(string Name, int SensorWidthPx, int SensorHeightPx, double SensorWidthMm, double SensorHeightMm)
{
    public static CameraBody RedKomodoX() => new("RED Komodo-X", 6144, 3240, 27.03, 14.26);
}
