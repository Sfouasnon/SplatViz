using System.Globalization;
using SplatViz.Core.Cameras;

namespace SplatViz.Core.Export;

public static class ColmapKnownPoseExporter
{
    public static string CamerasTxt(CameraBody body, Lens lens, RecordingMode mode)
    {
        var fx = mode.WidthPx * lens.FocalLengthMm / body.SensorWidthMm;
        var fy = mode.HeightPx * lens.FocalLengthMm / body.SensorHeightMm;
        var cx = (mode.WidthPx / 2.0).ToString("0.###", CultureInfo.InvariantCulture);
        var cy = (mode.HeightPx / 2.0).ToString("0.###", CultureInfo.InvariantCulture);
        var fxText = fx.ToString("0.########", CultureInfo.InvariantCulture);
        var fyText = fy.ToString("0.########", CultureInfo.InvariantCulture);

        return "# CAMERA_ID, MODEL, WIDTH, HEIGHT, PARAMS[]\n"
            + $"1 PINHOLE {mode.WidthPx} {mode.HeightPx} {fxText} {fyText} {cx} {cy}\n";
    }
}
